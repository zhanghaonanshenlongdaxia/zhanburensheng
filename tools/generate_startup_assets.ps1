param(
    [string]$Model = "doubao-seedream-4-5-251128",
    [string]$Size = "2K",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not $env:ARK_API_KEY) {
    $env:ARK_API_KEY = [Environment]::GetEnvironmentVariable("ARK_API_KEY", "User")
}
if (-not $env:ARK_API_KEY) {
    throw "ARK_API_KEY is not set."
}

$assets = @(
    @{
        Out = "assets/generated/startup/title_ink_v1.jpg"
        Prompt = "Use case: illustration-story. Asset type: wide title screen background for a dark Chinese survival divination game. Pure environment, no UI and no text. A ruined rural village gate at predawn, muddy road leading inward, collapsed mud walls, distant mountains swallowed by mist, old talisman papers and broken bamboo divination sticks in the foreground, subtle ink wash clouds, aged paper texture, dark painterly comic-game background, low saturation, old sepia ink and cold blue gray, cinematic but not photorealistic, hand-painted 2D illustration, premium game title screen composition with clear central negative space for title. Avoid: people close-up, readable text, typography, logo, watermark, modern buildings, bright cartoon colors, realistic photo look, 3D render."
    },
    @{
        Out = "assets/generated/startup/story_debt_notice.jpg"
        Prompt = "Use case: illustration-story. Asset type: comic storyboard panel for a dark Chinese survival divination game. Pure illustration, no UI and no text. A poor rural home before dawn, cracked wooden door, debt collectors' shadows outside, a worried silhouette inside holding a small pouch of coins, old paper texture, ink-wash outlines, low saturation, dark sepia and blue gray, cinematic manga panel composition, strong foreground shadow, premium game opening art. Avoid readable writing, typography, logo, watermark, modern objects, photorealism, 3D render, bright cartoon colors."
    },
    @{
        Out = "assets/generated/startup/story_divination_table.jpg"
        Prompt = "Use case: illustration-story. Asset type: comic storyboard panel for a dark Chinese survival divination game. Pure illustration, no UI and no text. Close-up of ancient copper coins falling across a cracked wooden table, a small oil lamp, divination sticks, worn cloth, trembling hands partly visible, heavy ink shadows, old paper grain, low saturation Chinese fantasy survival atmosphere, dynamic diagonal composition, hand-painted 2D comic panel. Avoid readable text, typography, logo, watermark, modern objects, photorealism, 3D render."
    },
    @{
        Out = "assets/generated/startup/story_meager_supplies.jpg"
        Prompt = "Use case: illustration-story. Asset type: comic storyboard panel for a dark Chinese survival divination game. Pure illustration, no UI and no text. A patched backpack, coarse grain sack, bitter herbs, knife, and a few copper coins laid on a rough floor, cold morning light cutting through a broken window, survival preparation mood, old ink and parchment texture, low saturation, hand-painted comic game art, premium opening cinematic still. Avoid readable labels, typography, logo, watermark, modern objects, photorealistic photo look, 3D render."
    },
    @{
        Out = "assets/generated/startup/story_black_mountain.jpg"
        Prompt = "Use case: illustration-story. Asset type: comic storyboard panel for a dark Chinese survival divination game. Pure illustration, no UI and no text. A narrow path into Black Mountain, twisted trees, wet stones, cave mouth in mist, distant hostile animal eyes hidden in darkness, the lone traveler seen from behind as a small silhouette, old paper ink-wash texture, dark painterly 2D comic panel, low saturation, ominous survival exploration atmosphere. Avoid readable text, typography, logo, watermark, modern objects, photorealism, 3D render."
    },
    @{
        Out = "assets/generated/startup/story_town_trade.jpg"
        Prompt = "Use case: illustration-story. Asset type: comic storyboard panel for a dark Chinese survival divination game. Pure illustration, no UI and no text. A worn ancient town street at dusk, small grocer stall, apothecary sign shape without readable letters, villagers trading sacks of grain and herbs, the player silhouette bargaining in the foreground, lantern haze, old paper grain, ink-wash lines, dark low saturation Chinese survival style, hand-painted 2D comic panel. Avoid readable typography, logo, watermark, modern objects, photorealism, 3D render."
    },
    @{
        Out = "assets/generated/startup/story_clue_board.jpg"
        Prompt = "Use case: illustration-story. Asset type: comic storyboard panel for a dark Chinese survival divination game. Pure illustration, no UI and no text. An old wooden wall covered with pinned blank paper slips, red string, copper coins, herbs, small map fragments, and shadowy branching clues, candlelight, no readable writing, old paper texture, ink-wash painterly comic-game style, low saturation, mysterious investigation survival mood. Avoid readable text, typography, logo, watermark, modern objects, photorealism, 3D render."
    }
)

foreach ($asset in $assets) {
    if ((Test-Path $asset.Out) -and -not $Force) {
        Write-Output "skip $($asset.Out)"
        continue
    }
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\doubao_generate_image.ps1 `
        -Model $Model `
        -Size $Size `
        -Out $asset.Out `
        -Prompt $asset.Prompt | Out-Null
    Write-Output "generated $($asset.Out)"
}
