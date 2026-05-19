param(
    [Parameter(Mandatory = $true)]
    [string]$Prompt,

    [string]$Out = "assets/generated/scenes/doubao-test.png",
    [string]$Model = "doubao-seedream-5-0-260128",
    [string]$Size = "2K",
    [string]$BaseUrl = "https://ark.cn-beijing.volces.com/api/v3",
    [switch]$Watermark
)

$ErrorActionPreference = "Stop"

if (-not $env:ARK_API_KEY) {
    throw "ARK_API_KEY is not set. Set it in your shell or Windows environment variables before running this script."
}

$outputPath = Join-Path (Get-Location) $Out
$outputDir = Split-Path -Parent $outputPath
New-Item -ItemType Directory -Force $outputDir | Out-Null

$body = @{
    model = $Model
    prompt = $Prompt
    sequential_image_generation = "disabled"
    response_format = "url"
    size = $Size
    stream = $false
    watermark = [bool]$Watermark
} | ConvertTo-Json -Depth 8

$headers = @{
    "Authorization" = "Bearer $env:ARK_API_KEY"
    "Content-Type" = "application/json"
}

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$BaseUrl/images/generations" `
    -Headers $headers `
    -Body $body

$imageUrl = $null
if ($response.data -and $response.data.Count -gt 0) {
    $imageUrl = $response.data[0].url
}

if (-not $imageUrl) {
    $response | ConvertTo-Json -Depth 10
    throw "Image generation response did not include data[0].url."
}

Invoke-WebRequest -Uri $imageUrl -OutFile $outputPath | Out-Null
Write-Output $outputPath
