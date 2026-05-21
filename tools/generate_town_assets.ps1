param(
    [string]$Model = "doubao-seedream-4-5-251128",
    [string]$Size = "2K"
)

$ErrorActionPreference = "Stop"

if (-not $env:ARK_API_KEY) {
    $env:ARK_API_KEY = [Environment]::GetEnvironmentVariable("ARK_API_KEY", "User")
}
if (-not $env:ARK_API_KEY) {
    throw "ARK_API_KEY is not set."
}

$backgroundStyle = "Use case: stylized-concept. Asset type: pure 2D game environment background, wide horizontal scene. Style: dark hand-painted illustration, old paper and ink-wash texture, low saturation, smoky brown, muted ochre, worn and immersive, suitable for a Chinese survival RPG. Composition: full environment scene with visual detail across the frame, clear darker empty areas for UI overlay but no blank parchment panel. Constraints: pure background only, no UI, no buttons, no card slots, no icons, no text, no Chinese characters, no signs, no labels, no logo, no watermark, no close-up people, no modern objects, no photorealism."
$portraitStyle = "Use case: stylized-concept. Asset type: square NPC portrait icon for a 2D game UI. Style: dark hand-painted Chinese ink illustration, old paper texture, low saturation, muted ochre and smoky brown, expressive but grounded, survival RPG mood. Composition: bust portrait, centered, readable silhouette, simple dark aged-paper background. Constraints: no text, no Chinese characters, no logo, no watermark, no modern objects, no photorealism."

$backgrounds = @(
    @{ Id = "gate"; Scene = "Scene: a poor ancient rural Chinese town gate, low mud walls, broken wooden posts, dusty road, thin morning fog, worn threshold, famine-era atmosphere." },
    @{ Id = "street"; Scene = "Scene: a narrow ancient rural Chinese town street, mud walls, patched roofs, cart ruts, hanging dry grass, quiet and tense famine-era lane." },
    @{ Id = "grocer"; Scene = "Scene: an ancient rural Chinese grocery shop in a famine-era town, cracked mud walls, rough wooden counter, grain sacks, clay jars, old shelves, weighing scale, dim oil lamp, dusty air." },
    @{ Id = "apothecary"; Scene = "Scene: an old Chinese apothecary shop, drawers of herbs, hanging dried roots, small mortar, paper medicine packets, dim green-brown light, poor town clinic feeling." },
    @{ Id = "pawn"; Scene = "Scene: a peddler and pawn stall at the edge of town, rough cloth bundles, old scale, worn boxes, shadowy goods under an awning, secretive atmosphere." },
    @{ Id = "tea"; Scene = "Scene: a roadside tea shed in an old Chinese town, low wooden tables, cracked tea bowls, smoke from a small stove, half-open reed screen, gossip atmosphere." },
    @{ Id = "back_alley"; Scene = "Scene: a damp back alley behind shops, stacked grain sacks, narrow mud walls, broken crates, deep shadows, hidden warehouse door, secret errand mood." },
    @{ Id = "sick_house"; Scene = "Scene: a poor sick house doorway at town edge, low hut, hanging cloth curtain, medicine bowl, dim interior, cold quiet air, worried survival mood." },
    @{ Id = "old_bridge"; Scene = "Scene: an old stone and wood bridge outside a rural Chinese town, muddy footprints, shallow water, reeds, worn bridge rail, dusk mist, suspicious quiet." },
    @{ Id = "ferry"; Scene = "Scene: a rural river ferry crossing, wet mud bank, old boat ropes, cargo bundles, cold water, reed shadows, dim overcast light." }
)

$portraits = @(
    @{ Id = "grocer"; Subject = "Subject: middle-aged grain shopkeeper, thin face, patched dark robe, cautious eyes, famine-era merchant, honest but calculating." },
    @{ Id = "doctor"; Subject = "Subject: older village doctor, sparse beard, plain robe, tired kind eyes, small medicine pouch, calm and observant." },
    @{ Id = "peddler"; Subject = "Subject: traveling peddler, lean face, sly half-smile, patched hooded coat, old goods strapped over shoulder, secretive." },
    @{ Id = "tea_oldman"; Subject = "Subject: old tea shed keeper, wrinkled face, short white beard, worn cap, quiet knowing eyes, speaks in half-sentences." },
    @{ Id = "porter"; Subject = "Subject: river porter, sunken cheeks, strong shoulders, rough cloth headwrap, weathered skin, practical and wary." }
)

foreach ($entry in $backgrounds) {
    $prompt = "$backgroundStyle $($entry.Scene)"
    $out = "assets/generated/town/backgrounds/$($entry.Id).jpg"
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\doubao_generate_image.ps1 -Model $Model -Out $out -Size $Size -Prompt $prompt | Out-Host
}

foreach ($entry in $portraits) {
    $prompt = "$portraitStyle $($entry.Subject)"
    $out = "assets/generated/town/npcs/$($entry.Id).jpg"
    powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\doubao_generate_image.ps1 -Model $Model -Out $out -Size $Size -Prompt $prompt | Out-Host
}
