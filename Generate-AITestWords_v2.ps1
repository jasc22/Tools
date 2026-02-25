# ============================================================
#  Generate-AITestWords.ps1
#  Generates configurable amounts of words to test AI systems
# ============================================================

param(
    [int]    $WordCount       = 10000,
    [string] $Mode            = "mixed",      # mixed | random | lorem | sentences | edge
    [string] $OutputFile      = "",           # Optional: path to save output
    [switch] $IncludeStats,                   # Print word/char stats
    [switch] $Shuffle                         # Randomise final word list
)

# ── Word banks ────────────────────────────────────────────────────────────────

$commonWords = @(
    "the","be","to","of","and","a","in","that","have","it","for","not","on","with",
    "he","she","they","we","you","do","at","this","but","from","or","an","all","would",
    "there","their","what","so","up","out","if","about","who","get","which","go","me",
    "when","make","can","like","time","no","just","him","know","take","people","into",
    "year","your","good","some","could","them","see","other","than","then","now","look",
    "only","come","its","over","think","also","back","after","use","two","how","our",
    "work","first","well","way","even","new","want","because","any","these","give","day",
    "most","us","great","between","need","large","often","hand","high","place","hold",
    "turn","here","why","ask","went","men","read","land","different","home","move"
)

$technicalWords = @(
    "algorithm","neural","network","transformer","token","embedding","inference","gradient",
    "backpropagation","tensor","matrix","vector","parameter","hyperparameter","epoch",
    "batch","dropout","activation","sigmoid","softmax","attention","encoder","decoder",
    "latent","semantic","corpus","tokenizer","fine-tuning","prompt","context","hallucination",
    "temperature","sampling","logit","probability","classification","regression","cluster",
    "dataset","validation","accuracy","precision","recall","F1","benchmark","evaluation",
    "multimodal","retrieval","augmented","generation","chain-of-thought","zero-shot",
    "few-shot","reinforcement","learning","reward","policy","model","weights","bias",
    "normalization","regularization","overfitting","underfitting","convergence","loss"
)

$edgeCaseWords = @(
    "cafe","naive","resume","uber","facade","pinata","jalapeno",
    "iPhone","ChatGPT","OpenAI","GPT-4","BERT","ReLU","APIs","URLs","JSON","YAML",
    "dont","cant","wont","its","theyre","ive","well","shouldnt","couldnt",
    "3rd","21st","1000x","top-10","2024","42","100pct","0.001","1e-5",
    "supercalifragilisticexpialidocious","pneumonoultramicroscopicsilicovolcanoconiosis",
    "antidisestablishmentarianism","electroencephalographically","floccinaucinihilipilification",
    "a","I","AI","OK","hi","bye","yes","no","go","do","so",
    "zero","letter-O","digit-0","one","letter-l","digit-1","rn","m","vv","w",
    "aaaaaa","111111","xxxxxx","dotdotdot","dashes","hashes",
    "bold-tag","script-tag","SELECT-star","key-value","console-log",
    "leading-spaces","trailing-spaces","tab-separated","empty-placeholder","dot"
)

$loremWords = @(
    "lorem","ipsum","dolor","sit","amet","consectetur","adipiscing","elit","sed","do",
    "eiusmod","tempor","incididunt","ut","labore","et","dolore","magna","aliqua","enim",
    "ad","minim","veniam","quis","nostrud","exercitation","ullamco","laboris","nisi",
    "aliquip","ex","ea","commodo","consequat","duis","aute","irure","in","reprehenderit",
    "voluptate","velit","esse","cillum","fugiat","nulla","pariatur","excepteur","sint",
    "occaecat","cupidatat","non","proident","sunt","culpa","qui","officia","deserunt",
    "mollit","anim","id","est","laborum"
)

$sentenceTemplates = @(
    "The {adj} {noun} {verb} the {adj} {noun}.",
    "In {year}, {noun} and {noun} worked together to {verb} a new {noun}.",
    "Why does the {noun} always {verb} when the {noun} is {adj}?",
    "Please {verb} the {adj} {noun} before processing the {noun}.",
    "{adj} {noun}s can {verb} up to {num} {noun}s per {noun}.",
    "The question is: can an {adj} {noun} {verb} a {adj} {noun}?",
    "Error: {noun} failed to {verb} because the {noun} was {adj}.",
    "According to the {noun}, {adj} {noun}s should never {verb} alone."
)

$adjectives = @("quick","lazy","smart","complex","simple","large","tiny","random",
                "broken","efficient","recursive","abstract","dynamic","static","async")
$nouns      = @("model","user","system","token","layer","node","graph","loop",
                "function","class","object","request","response","agent","task")
$verbs      = @("process","generate","return","evaluate","call","update","merge",
                "parse","encode","decode","train","test","validate","compile","run")

# ── Helpers ───────────────────────────────────────────────────────────────────

function Get-RandomWord([string]$pool) {
    $list = switch ($pool) {
        "common"    { $script:commonWords }
        "technical" { $script:technicalWords }
        "edge"      { $script:edgeCaseWords }
        "lorem"     { $script:loremWords }
        default     { $script:commonWords + $script:technicalWords }
    }
    $idx = Get-Random -Minimum 0 -Maximum $list.Count
    return $list[$idx]
}

function New-SentenceFromTemplate {
    $idx      = Get-Random -Minimum 0 -Maximum $script:sentenceTemplates.Count
    $template = $script:sentenceTemplates[$idx]
    $result   = $template `
        -replace '\{adj\}',  ($script:adjectives[(Get-Random -Minimum 0 -Maximum $script:adjectives.Count)]) `
        -replace '\{noun\}', ($script:nouns[(Get-Random -Minimum 0 -Maximum $script:nouns.Count)]) `
        -replace '\{verb\}', ($script:verbs[(Get-Random -Minimum 0 -Maximum $script:verbs.Count)]) `
        -replace '\{year\}', (Get-Random -Minimum 2000 -Maximum 2030) `
        -replace '\{num\}',  (Get-Random -Minimum 1    -Maximum 9999)
    return $result
}

function New-RandomString([int]$length) {
    $chars  = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    $result = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt $length; $i++) {
        $null = $result.Append($chars[(Get-Random -Minimum 0 -Maximum $chars.Length)])
    }
    return $result.ToString()
}

# ── Fisher-Yates shuffle — avoids Sort-Object pipeline InputObject errors ─────

function Invoke-FisherYatesShuffle([string[]]$arr) {
    for ($i = $arr.Length - 1; $i -gt 0; $i--) {
        $j       = Get-Random -Minimum 0 -Maximum ($i + 1)
        $tmp     = $arr[$i]
        $arr[$i] = $arr[$j]
        $arr[$j] = $tmp
    }
    return $arr
}

# ── Word generators by mode ───────────────────────────────────────────────────

function Get-WordsByMode([string]$mode, [int]$count) {
    $list = [System.Collections.Generic.List[string]]::new($count)

    switch ($mode) {

        "lorem" {
            while ($list.Count -lt $count) {
                $idx = Get-Random -Minimum 0 -Maximum $script:loremWords.Count
                $list.Add($script:loremWords[$idx])
            }
        }

        "random" {
            while ($list.Count -lt $count) {
                $len = Get-Random -Minimum 2 -Maximum 16
                $list.Add((New-RandomString $len))
            }
        }

        "sentences" {
            while ($list.Count -lt $count) {
                $sentence = New-SentenceFromTemplate
                foreach ($w in ($sentence -split '\s+')) {
                    if ($w.Length -gt 0 -and $list.Count -lt $count) {
                        $list.Add($w)
                    }
                }
            }
        }

        "edge" {
            $i = 0
            while ($list.Count -lt $count) {
                $word = $script:edgeCaseWords[$i % $script:edgeCaseWords.Count]
                if ($null -ne $word -and $word.Length -gt 0) {
                    $list.Add($word)
                }
                $i++
            }
        }

        default {
            # "mixed" – blend of all pools
            $pools = @("common","common","common","technical","lorem","edge","random")
            while ($list.Count -lt $count) {
                $pool = $pools[(Get-Random -Minimum 0 -Maximum $pools.Count)]
                $word = Get-RandomWord $pool
                if ($null -ne $word -and $word.Length -gt 0) {
                    $list.Add($word)
                }
            }
        }
    }

    # Cast to typed array to prevent downstream pipeline InputObject validation errors
    return [string[]]$list.ToArray()
}

# ── Main ──────────────────────────────────────────────────────────────────────

Write-Host "`n=== AI Test Word Generator ===" -ForegroundColor Cyan
Write-Host "Mode      : $Mode"      -ForegroundColor Yellow
Write-Host "WordCount : $WordCount" -ForegroundColor Yellow
Write-Host ""

[string[]]$wordArray = Get-WordsByMode -mode $Mode -count $WordCount

if ($Shuffle) {
    $wordArray = Invoke-FisherYatesShuffle -arr $wordArray
}

$output = $wordArray -join " "

# ── Output ────────────────────────────────────────────────────────────────────

Write-Host "--- Generated Output ---" -ForegroundColor Green
Write-Host $output
Write-Host ""

if ($IncludeStats) {
    $lengths = $wordArray | ForEach-Object { $_.Length }
    $avgLen  = [math]::Round(($lengths | Measure-Object -Average).Average, 2)
    $unique  = ($wordArray | Sort-Object -Unique).Count

    Write-Host "--- Stats ---" -ForegroundColor Magenta
    Write-Host "  Words      : $($wordArray.Count)"
    Write-Host "  Characters : $($output.Length)"
    Write-Host "  Avg length : $avgLen"
    Write-Host "  Unique     : $unique"
    Write-Host ""
}

if ($OutputFile -ne "") {
    $output | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Output saved to: $OutputFile" -ForegroundColor Cyan
}

Write-Host "Done." -ForegroundColor Green
