param(
    [string]$AzureContainer = "",
    [string]$AwsBucket = "",
    [string]$GcpBucket = "",
    [string]$FileDirectory = "C:\TestFiles"
)

$files = @{
    "5MB"  = "$FileDirectory\test_5mb.txt"
    "10MB" = "$FileDirectory\test_10mb.txt"
    "1GB"  = "$FileDirectory\test_1gb.txt"
}

# Azure uploads
if ($AzureContainer) {
    Write-Host "===== AZURE UPLOADS =====" -ForegroundColor Cyan
    
    $headers = @{"x-ms-blob-type" = "BlockBlob"}
    
    foreach ($size in @("5MB", "10MB", "1GB")) {
        foreach ($method in @("Invoke-WebRequest", "curl", "iwr", "wget", "Invoke-RestMethod", "irm")) {
            $blobName = "${method}_${size}.txt" -replace '[^a-zA-Z0-9_.]', '_'
            $uri = $AzureContainer -replace '\?', "/$blobName?"
            $file = $files[$size]
            
            Write-Host "`n[$size] $method" -ForegroundColor Yellow
            Write-Host "Start: $(Get-Date -Format 'HH:mm:ss.fff')"
            
            try {
                switch ($method) {
                    "Invoke-WebRequest" {
                        Write-Host "Invoke-WebRequest -Method Put -Headers @{`"x-ms-blob-type`"=`"BlockBlob`"} -InFile `"$file`" -Uri `"$uri`" -UseBasicParsing"
                        Invoke-WebRequest -Method Put -Headers $headers -InFile $file -Uri $uri -UseBasicParsing | Out-Null
                    }
                    "curl" {
                        Write-Host "curl.exe -X PUT --data-binary `"@$file`" -H `"x-ms-blob-type: BlockBlob`" `"$uri`""
                        curl.exe -X PUT --data-binary "@$file" -H "x-ms-blob-type: BlockBlob" "$uri" -s -o NUL
                    }
                    "iwr" {
                        Write-Host "iwr -Method Put -Headers @{`"x-ms-blob-type`"=`"BlockBlob`"} -InFile `"$file`" -Uri `"$uri`" -UseBasicParsing"
                        iwr -Method Put -Headers $headers -InFile $file -Uri $uri -UseBasicParsing | Out-Null
                    }
                    "wget" {
                        Write-Host "wget.exe --method=PUT --body-file=`"$file`" --header=`"x-ms-blob-type: BlockBlob`" `"$uri`""
                        wget.exe --method=PUT --body-file="$file" --header="x-ms-blob-type: BlockBlob" "$uri" -q -O NUL 2>$null
                    }
                    "Invoke-RestMethod" {
                        Write-Host "Invoke-RestMethod -Method Put -Headers @{`"x-ms-blob-type`"=`"BlockBlob`"} -InFile `"$file`" -Uri `"$uri`""
                        Invoke-RestMethod -Method Put -Headers $headers -InFile $file -Uri $uri
                    }
                    "irm" {
                        Write-Host "irm -Method Put -Headers @{`"x-ms-blob-type`"=`"BlockBlob`"} -InFile `"$file`" -Uri `"$uri`""
                        irm -Method Put -Headers $headers -InFile $file -Uri $uri
                    }
                }
                Write-Host "End: $(Get-Date -Format 'HH:mm:ss.fff') - SUCCESS" -ForegroundColor Green
            }
            catch {
                Write-Host "End: $(Get-Date -Format 'HH:mm:ss.fff') - FAILED: $_" -ForegroundColor Red
            }
        }
    }
}

# AWS S3 uploads
if ($AwsBucket) {
    Write-Host "`n===== AWS S3 UPLOADS =====" -ForegroundColor Cyan
    
    $headers = @{"Content-Type" = "text/plain"}
    
    foreach ($size in @("5MB", "10MB", "1GB")) {
        foreach ($method in @("Invoke-WebRequest", "curl", "iwr", "wget", "Invoke-RestMethod", "irm")) {
            $objectKey = "${method}_${size}.txt" -replace '[^a-zA-Z0-9_.]', '_'
            $uri = "$AwsBucket/$objectKey"
            $file = $files[$size]
            
            Write-Host "`n[$size] $method" -ForegroundColor Yellow
            Write-Host "Start: $(Get-Date -Format 'HH:mm:ss.fff')"
            
            try {
                switch ($method) {
                    "Invoke-WebRequest" {
                        Write-Host "Invoke-WebRequest -Method Put -Headers @{`"Content-Type`"=`"text/plain`"} -InFile `"$file`" -Uri `"$uri`" -UseBasicParsing"
                        Invoke-WebRequest -Method Put -Headers $headers -InFile $file -Uri $uri -UseBasicParsing | Out-Null
                    }
                    "curl" {
                        Write-Host "curl.exe -X PUT --data-binary `"@$file`" -H `"Content-Type: text/plain`" `"$uri`""
                        curl.exe -X PUT --data-binary "@$file" -H "Content-Type: text/plain" "$uri" -s -o NUL
                    }
                    "iwr" {
                        Write-Host "iwr -Method Put -Headers @{`"Content-Type`"=`"text/plain`"} -InFile `"$file`" -Uri `"$uri`" -UseBasicParsing"
                        iwr -Method Put -Headers $headers -InFile $file -Uri $uri -UseBasicParsing | Out-Null
                    }
                    "wget" {
                        Write-Host "wget.exe --method=PUT --body-file=`"$file`" --header=`"Content-Type: text/plain`" `"$uri`""
                        wget.exe --method=PUT --body-file="$file" --header="Content-Type: text/plain" "$uri" -q -O NUL 2>$null
                    }
                    "Invoke-RestMethod" {
                        Write-Host "Invoke-RestMethod -Method Put -Headers @{`"Content-Type`"=`"text/plain`"} -InFile `"$file`" -Uri `"$uri`""
                        Invoke-RestMethod -Method Put -Headers $headers -InFile $file -Uri $uri
                    }
                    "irm" {
                        Write-Host "irm -Method Put -Headers @{`"Content-Type`"=`"text/plain`"} -InFile `"$file`" -Uri `"$uri`""
                        irm -Method Put -Headers $headers -InFile $file -Uri $uri
                    }
                }
                Write-Host "End: $(Get-Date -Format 'HH:mm:ss.fff') - SUCCESS" -ForegroundColor Green
            }
            catch {
                Write-Host "End: $(Get-Date -Format 'HH:mm:ss.fff') - FAILED: $_" -ForegroundColor Red
            }
        }
    }
}

# GCP uploads
if ($GcpBucket) {
    Write-Host "`n===== GCP UPLOADS =====" -ForegroundColor Cyan
    
    $headers = @{"Content-Type" = "text/plain"}
    
    foreach ($size in @("5MB", "10MB", "1GB")) {
        foreach ($method in @("Invoke-WebRequest", "curl", "iwr", "wget", "Invoke-RestMethod", "irm")) {
            $objectName = "${method}_${size}.txt" -replace '[^a-zA-Z0-9_.]', '_'
            $uri = "$GcpBucket/$objectName"
            $file = $files[$size]
            
            Write-Host "`n[$size] $method" -ForegroundColor Yellow
            Write-Host "Start: $(Get-Date -Format 'HH:mm:ss.fff')"
            
            try {
                switch ($method) {
                    "Invoke-WebRequest" {
                        Write-Host "Invoke-WebRequest -Method Put -Headers @{`"Content-Type`"=`"text/plain`"} -InFile `"$file`" -Uri `"$uri`" -UseBasicParsing"
                        Invoke-WebRequest -Method Put -Headers $headers -InFile $file -Uri $uri -UseBasicParsing | Out-Null
                    }
                    "curl" {
                        Write-Host "curl.exe -X PUT --data-binary `"@$file`" -H `"Content-Type: text/plain`" `"$uri`""
                        curl.exe -X PUT --data-binary "@$file" -H "Content-Type: text/plain" "$uri" -s -o NUL
                    }
                    "iwr" {
                        Write-Host "iwr -Method Put -Headers @{`"Content-Type`"=`"text/plain`"} -InFile `"$file`" -Uri `"$uri`" -UseBasicParsing"
                        iwr -Method Put -Headers $headers -InFile $file -Uri $uri -UseBasicParsing | Out-Null
                    }
                    "wget" {
                        Write-Host "wget.exe --method=PUT --body-file=`"$file`" --header=`"Content-Type: text/plain`" `"$uri`""
                        wget.exe --method=PUT --body-file="$file" --header="Content-Type: text/plain" "$uri" -q -O NUL 2>$null
                    }
                    "Invoke-RestMethod" {
                        Write-Host "Invoke-RestMethod -Method Put -Headers @{`"Content-Type`"=`"text/plain`"} -InFile `"$file`" -Uri `"$uri`""
                        Invoke-RestMethod -Method Put -Headers $headers -InFile $file -Uri $uri
                    }
                    "irm" {
                        Write-Host "irm -Method Put -Headers @{`"Content-Type`"=`"text/plain`"} -InFile `"$file`" -Uri `"$uri`""
                        irm -Method Put -Headers $headers -InFile $file -Uri $uri
                    }
                }
                Write-Host "End: $(Get-Date -Format 'HH:mm:ss.fff') - SUCCESS" -ForegroundColor Green
            }
            catch {
                Write-Host "End: $(Get-Date -Format 'HH:mm:ss.fff') - FAILED: $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`nDone." -ForegroundColor Cyan
