[CmdletBinding(SupportsShouldProcess=$true)]
Param()

$savedGameFile = "D:\SteamLibrary\steamapps\common\ARK\ShooterGame\Saved\SavedArksLocal\TheIsland.ark"
$wildPath = "Wild"
$tamedPath = "Tamed"

# Read raw files
Write-Output "Extracting tamed dino details..."
#.\ark-tools.exe tamed $savedGameFile $tamedPath
Write-Output "Extracting wild dino details..."
#.\ark-tools.exe wild $savedGameFile $wildPath

# Get a list of the files created
$tamedFiles = Get-ChildItem -Path $tamedPath
Write-Verbose "$($tamedFiles.Count) Tamed Dinosaur files read..."

$wildFiles = Get-ChildItem -Path $wildPath
Write-Verbose "$($wildFiles.Count) Wild Dinosaur files read..."

foreach ($wildFile in $wildFiles)
{
    $dinoName = $wildFile.Name.Split('_')[0]

    $wildDinos = Get-Content $wildFile.FullName -Raw | ConvertFrom-Json
    Write-Output "$($wildDinos.Count) $($dinoName)s found"

    foreach ($wildDino in $WildDinos)
    {
        if ($wildDino.baseLevel -eq "116" -or $wildDino.baseLevel -eq "120")
        {
            Write-Output "Level $($wildDino.baseLevel) $dinoName detected at $($wildDino.lat), $($wildDino.lon)"
        }
    }
}
