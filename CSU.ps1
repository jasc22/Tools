<#
.SYNOPSIS
    Upload files to Azure, AWS S3, and GCP public cloud storage.

.DESCRIPTION
    Uploads 5MB, 10MB, and 1GB files using Invoke-WebRequest (curl, iwr, wget) 
    and Invoke-RestMethod (irm) to public cloud storage endpoints.

.EXAMPLE
    .\CloudStorageUploader.ps1 -AzureContainer "https://account.blob.core.windows.net/container"
#>

param(
    [string]$AzureContainer = "https://mystorageaccount.blob.core.windows.net/container?sv=2021-06-08&ss=b&srt=o&sp=rwdlacx&se=...",
    [string]$AwsBucket = "https://my-public-bucket.s3.us-east-1.amazonaws.com",
    [string]$GcpBucket = "https://storage.googleapis.com/my-public-bucket",
    [string]$FileDirectory = "C:\TestFiles",
    [int]$TimeoutSeconds = 1800
)

# File paths
$Files = @{
    "5MB"  = Join-Path $FileDirectory "test_5mb.txt"
    "10MB" = Join-Path $FileDirectory "test_10mb.txt"
    "1GB"  = Join-Path $FileDirectory "test_1gb.txt"
}

function Get-Timestamp {
    return (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Timestamp
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "START"   { "Yellow" }
        "END"     { "Green" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    Write-Host "[$ts] [$Level] $Message" -ForegroundColor $color
}

function Invoke-Upload {
    param(
        [string]$Provider,
        [string]$Method,
        [string]$FilePath,
        [string]$FileSize,
        [string]$Uri,
        [hashtable]$Headers,
        [string]$HttpMethod = "PUT",
        [int]$Timeout = $script:TimeoutSeconds
    )

    $fileName = Split-Path $FilePath -Leaf
    $fileSizeBytes = (Get-Item $FilePath).Length

    Write-Log "=== $Provider Upload: $FileSize using $Method ===" -Level "START"
    Write-Log "File: $fileName ($fileSizeBytes bytes)"
    Write-Log "Target URI: $Uri"
    Write-Log "Headers: $($Headers | ConvertTo-Json -Compress)"
    Write-Log "Timeout: $Timeout seconds"

    $startTime = Get-Date
    Write-Log "Upload started"

    try {
        switch ($Method) {
            "Invoke-WebRequest" {
                $response = Invoke-WebRequest -Method $HttpMethod -Headers $Headers -InFile $FilePath -Uri $Uri -UseBasicParsing -TimeoutSec $Timeout
                $statusCode = $response.StatusCode
            }
            "curl" {
                # Native curl.exe syntax
                $headerArgs = @()
                foreach ($key in $Headers.Keys) {
                    $headerArgs += "-H"
                    $headerArgs += "${key}: $($Headers[$key])"
                }
                $result = & curl.exe -X $HttpMethod --data-binary "@$FilePath" @headerArgs "$Uri" -w "%{http_code}" -s -o NUL --max-time $Timeout
                $statusCode = [int]$result
            }
            "iwr" {
                $response = iwr -Method $HttpMethod -Headers $Headers -InFile $FilePath -Uri $Uri -UseBasicParsing -TimeoutSec $Timeout
                $statusCode = $response.StatusCode
            }
            "wget" {
                # Native wget.exe syntax
                $headerArgs = @()
                foreach ($key in $Headers.Keys) {
                    $headerArgs += "--header=${key}: $($Headers[$key])"
                }
                & wget.exe --method=$HttpMethod --body-file="$FilePath" @headerArgs "$Uri" -q -O NUL --timeout=$Timeout 2>$null
                $statusCode = if ($LASTEXITCODE -eq 0) { 200 } else { $LASTEXITCODE }
            }
            "Invoke-RestMethod" {
                Invoke-RestMethod -Method $HttpMethod -Headers $Headers -InFile $FilePath -Uri $Uri -TimeoutSec $Timeout
                $statusCode = 200
            }
            "irm" {
                irm -Method $HttpMethod -Headers $Headers -InFile $FilePath -Uri $Uri -TimeoutSec $Timeout
                $statusCode = 200
            }
        }

        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        $throughput = [math]::Round(($fileSizeBytes / 1MB) / $duration, 2)

        Write-Log "Upload completed - Status: $statusCode"
        Write-Log "Duration: $([math]::Round($duration, 3)) seconds | Throughput: $throughput MB/s" -Level "END"

        return [PSCustomObject]@{
            Provider   = $Provider
            Method     = $Method
            FileSize   = $FileSize
            Status     = $statusCode
            Duration   = [math]::Round($duration, 3)
            Throughput = $throughput
            StartTime  = $startTime.ToString("HH:mm:ss.fff")
            EndTime    = $endTime.ToString("HH:mm:ss.fff")
        }
    }
    catch {
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        Write-Log "Upload FAILED: $_" -Level "ERROR"

        return [PSCustomObject]@{
            Provider   = $Provider
            Method     = $Method
            FileSize   = $FileSize
            Status     = "FAILED"
            Duration   = [math]::Round($duration, 3)
            Throughput = 0
            StartTime  = $startTime.ToString("HH:mm:ss.fff")
            EndTime    = $endTime.ToString("HH:mm:ss.fff")
        }
    }
}

#region Azure Blob Storage Uploads

function Send-ToAzure {
    param([string]$FilePath, [string]$FileSize, [string]$Method)

    $blobName = "${Method}_${FileSize}.txt" -replace '[^a-zA-Z0-9_.]', '_'
    
    # Handle SAS URL (contains ?) vs plain container URL
    if ($AzureContainer -match '\?') {
        # SAS URL: insert blob name before the query string
        $uri = $AzureContainer -replace '\?', "/$blobName?"
    } else {
        # Plain URL: append blob name
        $uri = "$AzureContainer/$blobName"
    }

    # Azure Blob Storage headers for SAS URL upload
    $headers = @{
        "x-ms-blob-type" = "BlockBlob"
    }

    return Invoke-Upload -Provider "Azure" -Method $Method -FilePath $FilePath `
        -FileSize $FileSize -Uri $uri -Headers $headers -HttpMethod "PUT"
}

#endregion

#region AWS S3 Uploads

function Send-ToAwsS3 {
    param([string]$FilePath, [string]$FileSize, [string]$Method)

    $objectKey = "${Method}_${FileSize}.txt" -replace '[^a-zA-Z0-9_.]', '_'
    $uri = "$AwsBucket/$objectKey"

    # AWS S3 headers for presigned URL
    $headers = @{
        "Content-Type" = "text/plain"
    }

    return Invoke-Upload -Provider "AWS S3" -Method $Method -FilePath $FilePath `
        -FileSize $FileSize -Uri $uri -Headers $headers -HttpMethod "PUT"
}

#endregion

#region GCP Cloud Storage Uploads

function Send-ToGcp {
    param([string]$FilePath, [string]$FileSize, [string]$Method)

    $objectName = "${Method}_${FileSize}.txt" -replace '[^a-zA-Z0-9_.]', '_'
    $encodedName = [System.Uri]::EscapeDataString($objectName)
    $uri = "$GcpBucket/$encodedName"

    # GCP Cloud Storage headers for signed URL
    $headers = @{
        "Content-Type" = "text/plain"
    }

    return Invoke-Upload -Provider "GCP" -Method $Method -FilePath $FilePath `
        -FileSize $FileSize -Uri $uri -Headers $headers -HttpMethod "PUT"
}

#endregion

#region Main Execution

Write-Host "`n===== Cloud Storage Upload Script =====" -ForegroundColor Cyan
Write-Host "Started: $(Get-Timestamp)`n" -ForegroundColor Cyan

# Verify files exist
foreach ($size in $Files.Keys) {
    if (-not (Test-Path $Files[$size])) {
        Write-Log "File not found: $($Files[$size])" -Level "ERROR"
        exit 1
    }
}

$methods = @("Invoke-WebRequest", "curl", "iwr", "wget", "Invoke-RestMethod", "irm")
$results = @()

# Azure uploads
Write-Host "`n----- AZURE BLOB STORAGE -----`n" -ForegroundColor Magenta
foreach ($method in $methods) {
    foreach ($size in @("5MB", "10MB", "1GB")) {
        $results += Send-ToAzure -FilePath $Files[$size] -FileSize $size -Method $method
        Write-Host ""
    }
}

# AWS S3 uploads
Write-Host "`n----- AWS S3 -----`n" -ForegroundColor Magenta
foreach ($method in $methods) {
    foreach ($size in @("5MB", "10MB", "1GB")) {
        $results += Send-ToAwsS3 -FilePath $Files[$size] -FileSize $size -Method $method
        Write-Host ""
    }
}

# GCP uploads
Write-Host "`n----- GCP CLOUD STORAGE -----`n" -ForegroundColor Magenta
foreach ($method in $methods) {
    foreach ($size in @("5MB", "10MB", "1GB")) {
        $results += Send-ToGcp -FilePath $Files[$size] -FileSize $size -Method $method
        Write-Host ""
    }
}

# Summary
Write-Host "`n===== UPLOAD SUMMARY =====" -ForegroundColor Cyan
Write-Host "Completed: $(Get-Timestamp)`n" -ForegroundColor Cyan

$results | Format-Table -AutoSize Provider, Method, FileSize, Status, Duration, Throughput, StartTime, EndTime

$successful = ($results | Where-Object { $_.Status -ne "FAILED" }).Count
Write-Host "`nTotal: $successful/$($results.Count) uploads successful" -ForegroundColor $(if ($successful -eq $results.Count) { "Green" } else { "Yellow" })

#endregion
