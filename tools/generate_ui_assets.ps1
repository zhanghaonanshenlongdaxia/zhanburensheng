param(
    [string]$Model = "doubao-seedream-4-5-251128",
    [string]$Size = "2048x2048",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not $env:ARK_API_KEY) {
    $env:ARK_API_KEY = [Environment]::GetEnvironmentVariable("ARK_API_KEY", "User")
}
if (-not $env:ARK_API_KEY) {
    throw "ARK_API_KEY is not set."
}

Add-Type -AssemblyName System.Drawing

function Save-JpegResized {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Target,
        [int]$Width = 256,
        [int]$Height = 256,
        [int]$Quality = 82
    )

    $sourcePath = Resolve-Path $Source
    $targetPath = Join-Path (Get-Location) $Target
    $targetDir = Split-Path -Parent $targetPath
    New-Item -ItemType Directory -Force $targetDir | Out-Null

    $src = [System.Drawing.Image]::FromFile($sourcePath)
    try {
        $targetAspect = $Width / [double]$Height
        $sourceAspect = $src.Width / [double]$src.Height
        if ($sourceAspect -gt $targetAspect) {
            $cropHeight = $src.Height
            $cropWidth = [int]($src.Height * $targetAspect)
            $cropX = [int](($src.Width - $cropWidth) / 2)
            $cropY = 0
        } else {
            $cropWidth = $src.Width
            $cropHeight = [int]($src.Width / $targetAspect)
            $cropX = 0
            $cropY = [int](($src.Height - $cropHeight) / 2)
        }

        $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.DrawImage(
                    $src,
                    (New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)),
                    (New-Object System.Drawing.Rectangle($cropX, $cropY, $cropWidth, $cropHeight)),
                    [System.Drawing.GraphicsUnit]::Pixel
                )
            } finally {
                $graphics.Dispose()
            }

            $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
            $encoder = [System.Drawing.Imaging.Encoder]::Quality
            $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
            $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($encoder, [long]$Quality)
            $bitmap.Save($targetPath, $codec, $params)
        } finally {
            if ($bitmap) { $bitmap.Dispose() }
        }
    } finally {
        $src.Dispose()
    }
}

function Invoke-DoubaoAsset {
    param(
        [Parameter(Mandatory = $true)][string]$Out,
        [Parameter(Mandatory = $true)][string]$Prompt
    )
    if ((Test-Path $Out) -and -not $Force) {
        Write-Output "skip $Out"
        return
    }
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\doubao_generate_image.ps1 `
        -Model $Model `
        -Size $Size `
        -Out $Out `
        -Prompt $Prompt | Out-Null
    Write-Output "generated $Out"
}

$baseIconPrompt = @"
Use case: stylized-concept
Asset type: square game inventory item icon
Style/medium: dark hand-painted 2D game icon, old paper and ink-wash texture, low saturation Chinese fantasy survival style, painterly linework, readable when downscaled to 64x64.
Composition/framing: strict square icon composition, centered object, object fills about 72 percent of the image, generous but not excessive padding, slightly top-down view.
Background: plain dark muted parchment texture only, no frame, no border, no panel, no UI card, no decorative corner, no glow at the edges.
Lighting/mood: dim warm rim light, subtle ink shadow directly under the item.
Constraints: no text, no typography, no numbers, no logo, no watermark, no photorealism, no modern objects, no bright cartoon colors, no glossy 3D render.
"@

$items = @(
    @{ id = "food"; subject = "a small tied sack of coarse grain and rough millet kernels, survival ration" },
    @{ id = "money"; subject = "a small stack of worn ancient copper coins with square holes, tied by frayed cord" },
    @{ id = "herb"; subject = "a simple bundle of common green medicinal herbs tied with straw" },
    @{ id = "meat"; subject = "a small strip of raw dried meat wrapped in old leaf, rustic survival food" },
    @{ id = "bitter_leaf"; subject = "one compact bundle of bitter medicinal leaves tied with rough hemp fiber" },
    @{ id = "dry_tuber"; subject = "several dry mountain tuber roots with dirt and cut ends, famine food" },
    @{ id = "rabbit_pelt"; subject = "a small folded wild rabbit pelt, rough fur and plain leather underside" },
    @{ id = "rusty_copper_piece"; subject = "an irregular rusty copper fragment, old metal scrap from a river bank" },
    @{ id = "bloodroot"; subject = "a red-veined medicinal root with thin fibers and dark soil still attached" },
    @{ id = "clear_moss"; subject = "cool blue-green moss clinging to a wet dark stone, medicinal creek moss" },
    @{ id = "boar_tusk"; subject = "a curved wild boar tusk with scratches and dried mud at the root" },
    @{ id = "old_coin_string"; subject = "a short string of corroded old dynasty coins, tied with dark cord" },
    @{ id = "mountain_ginseng"; subject = "a small mountain ginseng root with two pale leaves and thin root hairs" },
    @{ id = "snake_gall"; subject = "a small dark green snake gall bladder in a tied leaf pouch, bitter medicine" },
    @{ id = "broken_jade_button"; subject = "a broken half jade button with old carved pattern, pale green and cracked" },
    @{ id = "old_hunter_knife"; subject = "an old hunter knife with chipped blade and worn wooden handle" },
    @{ id = "purple_lingzhi"; subject = "a deep purple lingzhi mushroom growing from a small dark bark fragment" },
    @{ id = "wolf_pelt_complete"; subject = "a folded complete wolf pelt, dark gray fur, rugged and valuable" },
    @{ id = "silver_hairpin_bent"; subject = "a bent old silver hairpin with tarnish, refugee jewelry" },
    @{ id = "remnant_bow_manual"; subject = "a torn old bow manual scroll with faded diagrams but no readable text" },
    @{ id = "hundred_year_ginseng"; subject = "a large old ginseng root with many root hairs, wrapped with red thread" },
    @{ id = "tiger_bone"; subject = "a carved tiger bone talisman, worn and heavy, tied with dark cord" },
    @{ id = "soldier_hidden_seal"; subject = "a small hidden soldier seal, dark metal and old military mark, no readable text" },
    @{ id = "black_iron_shortblade"; subject = "a black iron short blade with simple wrapped handle, ominous old weapon" },
    @{ id = "blood_reishi"; subject = "a rare blood-red reishi mushroom with dark veins, ominous life-saving medicine" },
    @{ id = "tiger_king_pelt"; subject = "a folded legendary tiger king pelt, deep orange and black stripes, old and dangerous" },
    @{ id = "ancient_bone_token"; subject = "an ancient bone token carved with mysterious non-readable grooves, ivory and dark patina" }
)

foreach ($item in $items) {
    $raw = "assets/generated/ui/raw/items/$($item.id).png"
    $final = "assets/generated/ui/items/$($item.id).jpg"
    if ((Test-Path $final) -and -not $Force) {
        Write-Output "skip $final"
        continue
    }
    $prompt = "$baseIconPrompt`nPrimary request: a single inventory icon for $($item.id).`nSubject: $($item.subject)."
    Invoke-DoubaoAsset -Out $raw -Prompt $prompt
    Save-JpegResized -Source $raw -Target $final -Width 256 -Height 256 -Quality 84
}

$optionIconBase = @"
Use case: stylized-concept
Asset type: square option card location icon
Style/medium: dark hand-painted 2D game icon, old paper and ink-wash texture, low saturation Chinese fantasy survival divination style, painterly linework, readable at 64x64.
Composition/framing: strict square icon composition, centered symbolic scene object, object fills about 70 percent, no characters.
Background: plain dark muted parchment texture only, no frame, no UI card, no border, no text.
Constraints: no typography, no numbers, no logo, no watermark, no photorealism, no modern objects, no bright cartoon colors, no glossy 3D render.
"@

$locations = @(
    @{ id = "field"; icon = "withered wild field grass and a small broken village path"; bg = "a bleak wild field outside an ancient village, dry grass, low mud wall silhouette, old paper ink mood" },
    @{ id = "mountain"; icon = "dark small mountain ridge with a narrow rocky path and cold mist"; bg = "Little Black Mountain in a war-torn countryside, steep path, dark rocks, cold mist, old ink paper mood" },
    @{ id = "river"; icon = "a cold river bend with wet stones and a half-submerged scrap of iron"; bg = "a cold muddy river bank, wet stones, low fog, dim water reflection, old ink paper mood" },
    @{ id = "graveyard"; icon = "a tilted old grave marker, dead grass, and a small hidden mound"; bg = "an abandoned graveyard edge, broken grave markers, dead grass, uneasy mist, old ink paper mood" },
    @{ id = "forest"; icon = "dense dark forest path with beast tracks and tangled branches"; bg = "deep dark forest interior, tangled branches, hidden beast trail, dangerous old ink paper mood" }
)

foreach ($loc in $locations) {
    $rawIcon = "assets/generated/ui/raw/options/$($loc.id)_icon.png"
    $finalIcon = "assets/generated/ui/options/$($loc.id)_icon.jpg"
    if ((Test-Path $finalIcon) -and -not $Force) {
        Write-Output "skip $finalIcon"
    } else {
        $iconPrompt = "$optionIconBase`nPrimary request: a location icon for $($loc.id).`nSubject: $($loc.icon)."
        Invoke-DoubaoAsset -Out $rawIcon -Prompt $iconPrompt
        Save-JpegResized -Source $rawIcon -Target $finalIcon -Width 256 -Height 256 -Quality 84
    }

    $rawBanner = "assets/generated/ui/raw/options/$($loc.id)_banner.png"
    $finalBanner = "assets/generated/ui/options/$($loc.id)_banner.jpg"
    if ((Test-Path $finalBanner) -and -not $Force) {
        Write-Output "skip $finalBanner"
        continue
    }
    $bannerPrompt = @"
Use case: stylized-concept
Asset type: wide horizontal option card background strip
Primary request: a wide banner background for $($loc.id) option cards in a dark Chinese survival divination game.
Scene/backdrop: $($loc.bg).
Style/medium: dark hand-painted game background, old paper and ink-wash texture, low saturation Chinese fantasy survival atmosphere, not photorealistic.
Composition/framing: very wide horizontal composition, environmental silhouettes and depth on the right side, left side slightly darker and calmer for overlaid UI text, no central hero object, no characters close-up.
Lighting/mood: dim, immersive, old ink, weathered paper, subtle fog, no bright sunlight.
Constraints: no UI, no card frame, no text, no typography, no logo, no watermark, no modern objects, no pure geometry.
"@
    Invoke-DoubaoAsset -Out $rawBanner -Prompt $bannerPrompt
    Save-JpegResized -Source $rawBanner -Target $finalBanner -Width 768 -Height 180 -Quality 78
}

Write-Output "done"
