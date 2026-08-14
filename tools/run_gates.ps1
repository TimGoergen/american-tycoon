# Run American Tycoon's verification gates.
#
#   pwsh tools\run_gates.ps1              # the headless gates + a boot check
#   pwsh tools\run_gates.ps1 -All         # ...plus the portrait sheet, which needs a real renderer
#   pwsh tools\run_gates.ps1 -Only Money  # just the gates whose name matches
#
# WHY THIS EXISTS. game/sim/ holds 27 scripts, of which only 12 are pass/fail gates; the rest are
# studies and one-off tools that print numbers and are not supposed to be "run" as tests. Nothing
# distinguished them, so a person or an agent verifying a change had to know the list by heart — and
# on 2026-08-10 that failed exactly as you would expect: a whole session's worth of changes was
# verified against 9 of the 12, with two gates (MatchThreeTest, RushOverheatTest) never run at all
# despite edits to the files they cover.
#
# It judges by EXIT CODE, never by scraping output. Every gate calls quit(0) or quit(1), which is the
# one signal that cannot drift; the summary lines are for humans and did drift (MatchThreeTest prints
# "ALL TESTS PASS", everything else prints "ALL CHECKS PASSED"), which is precisely how a grep-based
# runner misses a gate while looking like it passed.

param(
    [switch]$All,          # also run the gates that need a window
    [string]$Only = "",    # substring filter on the gate name
    [string]$Godot = "D:\Downloads\Godot_v4.5.1-stable_win64\Godot_v4.5.1-stable_win64_console.exe"
)

# CONTINUE, not Stop. Godot writes ordinary progress and warnings to stderr, and in Windows
# PowerShell 5.1 a native command's stderr captured with 2>&1 arrives as ErrorRecords — under Stop,
# the first harmless warning ("Save version 8 differs from current 13") aborts the whole run. The
# exit code is what we judge by, so stderr is just text to us.
$ErrorActionPreference = "Continue"
$repo = Split-Path -Parent $PSScriptRoot
$game = Join-Path $repo "game"

# The HEADLESS gates. Order is cheapest-first so a broken build fails fast.
$headless = @(
    "MoneyTest",             # number formatting
    "EpochTest",             # epoch staffing + save migration
    "ChallengeGoalsTest",    # challenge ladders, met-minigame set
    "MatchThreeTest",        # the match-3 board's pure logic
    "RushOverheatTest",      # the push-your-luck heat model
    "AutoPurchaseTest",      # the Acquisitions Desk buying policy
    "MomentumBarStateTest",  # the bar paints what Main pushed it
    "ScrollEdgeFadeTest",    # list fade against an unlaid-out viewport
    "IncomeReadoutTest",     # what a property row displays
    "AudioSettingsTest",     # every ui_ preference survives a succession
    "AudioCoreTest",         # the audio system's rules
    "QolLegacyTest",         # offline cap, auto-restarts, auto-pop, frenzy upgrades
    "FinalDollarTest"        # Earth capture climax and commemorative certificate
)

# Gates that need a REAL RENDERER — headless has no framebuffer to capture, so these cannot run in
# the normal sweep and are opt-in.
$rendered = @(
    "PortraitSheet"          # renders all 25 alien civs and checks them
)

if (-not (Test-Path $Godot)) {
    Write-Host "Godot not found at $Godot" -ForegroundColor Red
    Write-Host "Pass -Godot <path> to override." -ForegroundColor Yellow
    exit 2
}

function Invoke-Gate {
    param([string]$Name, [string[]]$ExtraArgs)

    $arguments = @("--path", $game) + $ExtraArgs + @("--script", "res://sim/$Name.gd")
    $output = & $Godot @arguments 2>&1
    $ok = ($LASTEXITCODE -eq 0)

    $label = if ($ok) { "PASS" } else { "FAIL" }
    $color = if ($ok) { "Green" } else { "Red" }
    Write-Host ("  {0,-22} {1}" -f $Name, $label) -ForegroundColor $color
    if (-not $ok) {
        # Only the failures print their output. A passing gate's chatter is what makes people stop
        # reading the summary.
        $output | Select-Object -Last 25 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
    }
    return $ok
}

$gates = $headless
if ($All) { $gates += $rendered }
if ($Only -ne "") { $gates = $gates | Where-Object { $_ -like "*$Only*" } }

Write-Host ""
Write-Host "Gates ($($gates.Count))" -ForegroundColor Cyan
$failed = @()
foreach ($gate in $gates) {
    $extra = if ($rendered -contains $gate) { @("--rendering-driver", "opengl3") } else { @("--headless") }
    if (-not (Invoke-Gate -Name $gate -ExtraArgs $extra)) { $failed += $gate }
}

# THE BOOT CHECK. Several failure modes never show up in a gate — a bad autoload, a missing resource,
# a parse error in a scene the gates do not touch — and only surface when the real project starts.
if ($Only -eq "") {
    Write-Host ""
    Write-Host "Boot" -ForegroundColor Cyan
    $bootOutput = & $Godot --headless --path $game --quit-after 150 2>&1
    $bootErrors = $bootOutput | Where-Object {
        $_ -match "SCRIPT ERROR|Parse Error|Failed to load|Failed to instantiate"
    }
    if ($bootErrors) {
        Write-Host "  boot                   FAIL" -ForegroundColor Red
        $bootErrors | Select-Object -First 10 | ForEach-Object { Write-Host "      $_" -ForegroundColor DarkGray }
        $failed += "boot"
    } else {
        Write-Host "  boot                   PASS" -ForegroundColor Green
    }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "All green." -ForegroundColor Green
    if (-not $All -and $Only -eq "") {
        Write-Host "(PortraitSheet was skipped - it needs a window. Add -All to include it.)" -ForegroundColor DarkGray
    }
    exit 0
}
Write-Host "FAILED: $($failed -join ', ')" -ForegroundColor Red
exit 1
