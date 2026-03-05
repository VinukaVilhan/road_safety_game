# Download standard road sign images (public domain) for the Road Signs MCQ test.
# Saves files into road_safety_game/assets/roadsigns/
# Run from repo root or from road_safety_game: .\scripts\download_roadsigns.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$OutDir = Join-Path $ProjectRoot "assets\roadsigns"

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

# Wikimedia Commons thumbnail URLs (public domain / free license). 200px width for app use.
# Paths use correct Commons hash (e.g. 4/41 for UK_traffic_sign_613). Add 1s delay to avoid rate limits.
$signs = @{
    "stop.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Canada_Stop_sign.svg/200px-Canada_Stop_sign.svg.png"
    "give_way.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c2/UK_traffic_sign_602.svg/200px-UK_traffic_sign_602.svg.png"
    "no_entry.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/UK_traffic_sign_616.svg/200px-UK_traffic_sign_616.svg.png"
    "speed_50.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2f/UK_traffic_sign_670.svg/200px-UK_traffic_sign_670.svg.png"
    "no_parking.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0d/UK_traffic_sign_642.svg/200px-UK_traffic_sign_642.svg.png"
    "slippery_road.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/UK_traffic_sign_679.svg/200px-UK_traffic_sign_679.svg.png"
    "children_crossing.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/UK_traffic_sign_880.svg/200px-UK_traffic_sign_880.svg.png"
    "cattle.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/UK_traffic_sign_826.svg/200px-UK_traffic_sign_826.svg.png"
    "curve_left.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/UK_traffic_sign_514.svg/200px-UK_traffic_sign_514.svg.png"
    "curve_right.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5d/UK_traffic_sign_515.svg/200px-UK_traffic_sign_515.svg.png"
    "road_works.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/UK_traffic_sign_701.svg/200px-UK_traffic_sign_701.svg.png"
    "pedestrian_crossing.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/UK_traffic_sign_1025.svg/200px-UK_traffic_sign_1025.svg.png"
    "level_crossing.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/UK_traffic_sign_773.svg/200px-UK_traffic_sign_773.svg.png"
    "no_overtaking.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/UK_traffic_sign_632.svg/200px-UK_traffic_sign_632.svg.png"
    "keep_left.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/UK_traffic_sign_610.svg/200px-UK_traffic_sign_610.svg.png"
    "no_horn.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/UK_traffic_sign_645.svg/200px-UK_traffic_sign_645.svg.png"
    "compulsory_left.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6c/UK_traffic_sign_612.svg/200px-UK_traffic_sign_612.svg.png"
    "compulsory_right.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/UK_traffic_sign_613.svg/200px-UK_traffic_sign_613.svg.png"
    "no_left_turn.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/41/UK_traffic_sign_613.svg/200px-UK_traffic_sign_613.svg.png"
    "no_right_turn.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8e/UK_traffic_sign_617.svg/200px-UK_traffic_sign_617.svg.png"
    "main_road.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c2/UK_traffic_sign_602.svg/200px-UK_traffic_sign_602.svg.png"
    "roundabout.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/UK_traffic_sign_543.svg/200px-UK_traffic_sign_543.svg.png"
    "hump.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/UK_traffic_sign_557.svg/200px-UK_traffic_sign_557.svg.png"
    "narrow_road.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/UK_traffic_sign_528.svg/200px-UK_traffic_sign_528.svg.png"
    "two_way_traffic.png" = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4a/UK_traffic_sign_523.svg/200px-UK_traffic_sign_523.svg.png"
}

$count = 0
foreach ($file in $signs.Keys) {
    $url = $signs[$file]
    $path = Join-Path $OutDir $file
    try {
        Write-Host "Downloading $file ..."
        Invoke-WebRequest -Uri $url -OutFile $path -UseBasicParsing
        $count++
        Start-Sleep -Seconds 1
    } catch {
        Write-Warning "Failed to download $file : $_"
    }
}

Write-Host "Done. Downloaded $count road sign image(s) to $OutDir"
