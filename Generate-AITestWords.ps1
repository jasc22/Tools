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
    "turn","here","why","ask","went","men","read","need","land","different","home","move"
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
    # Unicode & special chars
    "café","naïve","résumé","über","façade","piñata","jalapeño",
    # Mixed case / capitalisation
    "iPhone","ChatGPT","OpenAI","GPT-4","BERT","ReLU","APIs","URLs","JSON","YAML",
    # Punctuation-heavy
    "don't","can't","won't","it's","they're","I've","we'll","shouldn't","couldn't",
    # Numbers mixed with text
    "3rd","21st","1000x","top-10","2024","42","100%","0.001","1e-5",
    # Very long words
    "supercalifragilisticexpialidocious","pneumonoultramicroscopicsilicovolcanoconiosis",
    "antidisestablishmentarianism","electroencephalographically","floccinaucinihilipilification",
    # Very short
    "a","I","AI","OK","hi","bye","yes","no","go","do","so",
    # Homoglyphs / lookalikes (common confusers)
    "zero","O","0","one","l","1","rn","m","vv","w",
    # Repeated chars
    "aaaaaa","111111","!!!!!!","......","------","######",
    # Emojis embedded
    "hello😊","AI🤖","test✅","error❌","warning⚠️",
    # HTML/code fragments
    "<b>bold</b>","<script>","SELECT * FROM","{ key: value }","console.log()",
    # SQL/injection-style
    "'; DROP TABLE","OR 1=1--","<img src=x onerror=alert(1)>",
    # Whitespace variations
    "word word","word`tword","  leading","trailing  ",
    # Empty-ish
    "","  ","."
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
    "Please {verb} the {adj} {noun} before {verb}ing the {noun}.",
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
        "common"    { $commonWords }
        "technical" { $technicalWords }
        "edge"      { $edgeCaseWords }
        "lorem"     { $loremWords }
        default     { $commonWords + $technicalWords }
    }
    return $list | Get-Random
}

function New-SentenceFromTemplate {
    $template = $sentenceTemplates | Get-Random
    $result = $template `
        -replace '\{adj\}',  ($adjectives | Get-Random) `
        -replace '\{noun\}', ($nouns      | Get-Random) `
        -replace '\{verb\}', ($verbs      | Get-Random) `
        -replace '\{year\}', (Get-Random -Minimum 2000 -Maximum 2030) `
        -replace '\{num\}',  (Get-Random -Minimum 1    -Maximum 9999)
    return $result
}

function New-RandomString([int]$length) {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    -join ((1..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

# ── Word generators by mode ───────────────────────────────────────────────────

function Get-WordsByMode([string]$mode, [int]$count) {
    $words = [System.Collections.Generic.List[string]]::new()

    switch ($mode) {

        "lorem" {
            while ($words.Count -lt $count) {
                $words.Add(($loremWords | Get-Random))
            }
        }

        "random" {
            while ($words.Count -lt $count) {
                $len = Get-Random -Minimum 2 -Maximum 16
                $words.Add((New-RandomString $len))
            }
        }

        "sentences" {
            while ($words.Count -lt $count) {
                $sentence = New-SentenceFromTemplate
                foreach ($w in ($sentence -split '\s+')) {
                    if ($words.Count -lt $count) { $words.Add($w) }
                }
            }
        }

        "edge" {
            # Cycle through edge-case words
            $i = 0
            while ($words.Count -lt $count) {
                $words.Add($edgeCaseWords[$i % $edgeCaseWords.Count])
                $i++
            }
        }

        default {
            # "mixed" – blend of all pools
            $pools = @("common","common","common","technical","lorem","edge","random")
            while ($words.Count -lt $count) {
                $pool = $pools | Get-Random
                $words.Add((Get-RandomWord $pool))
            }
        }
    }

    return $words
}

# ── Main ──────────────────────────────────────────────────────────────────────

Write-Host "`n=== AI Test Word Generator ===" -ForegroundColor Cyan
Write-Host "Mode      : $Mode"           -ForegroundColor Yellow
Write-Host "WordCount : $WordCount"      -ForegroundColor Yellow
Write-Host ""

$words = Get-WordsByMode -mode $Mode -count $WordCount

if ($Shuffle) {
    $words = $words | Sort-Object { Get-Random }
}

$output = $words -join " "

# ── Output ────────────────────────────────────────────────────────────────────

Write-Host "--- Generated Output ---" -ForegroundColor Green
Write-Host $output
Write-Host ""

if ($IncludeStats) {
    Write-Host "--- Stats ---" -ForegroundColor Magenta
    Write-Host "  Words      : $($words.Count)"
    Write-Host "  Characters : $($output.Length)"
    Write-Host "  Avg length : $([math]::Round(($words | ForEach-Object {$_.Length} | Measure-Object -Average).Average, 2))"
    $uniqueCount = ($words | Sort-Object -Unique).Count
    Write-Host "  Unique     : $uniqueCount"
    Write-Host ""
}

if ($OutputFile -ne "") {
    $output | Out-File -FilePath $OutputFile -Encoding UTF8
    Write-Host "Output saved to: $OutputFile" -ForegroundColor Cyan
}

Write-Host "Done." -ForegroundColor Green
