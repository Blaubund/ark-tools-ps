# Examples:
#
#   .\Get-WildDinos.ps1 -MinLevel 116
#   .\Get-WildDinos.ps1 -FindAlphas
#   .\Get-WildDinos.ps1 -MinLevel 1 -ShowTotalsOnly
#   .\Get-WildDinos.ps1 -ShowTotalsOnly
#
# To do: 
#   - Automatically detect where the ARK saved game files are as a default
#   - Search for specific colors
#   - Add -MaxLevel

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter()]
    [string] $Species,

    [Parameter()]
    [string] $MinLevel,

    [switch] $FindAlphas,

    [switch] $ShowTotalsOnly,

    [Parameter()]
    [string] $SavedGameFile,

    [Parameter()]
    [string] $DestinationFolder
)

. ".\DinoColors.ps1"

$defaultSpecies = ".*"
$defaultMinLevel = "112"
$defaultSavedGameFile = "D:\SteamLibrary\steamapps\common\ARK\ShooterGame\Saved\SavedArksLocal\TheIsland.ark"
$defaultDestinationFolder = "Wild"

if ($FindAlphas -eq $true)
{
    if ($Species -ne "")
    {
        Write-Warning "Species overridden to 'Mega' to find just alphas"
    }
    $Species = "Mega"
    if ($MinLevel -eq "")
    {
        $MinLevel = 1
    }
}

if ($Species -eq "")
{
    $Species = $defaultSpecies
}

if ($MinLevel -eq "")
{
    $MinLevel = $defaultMinLevel
}

if ($SavedGameFile -eq "")
{
    $SavedGameFile = $defaultSavedGameFile
}

if ($DestinationFolder -eq "")
{
    $DestinationFolder = $defaultDestinationFolder
}

Write-Verbose "Save game file: $SavedGameFile"
Write-Verbose "Destination folder: $DestinationFolder"
Write-Verbose "Dino Type: $Species"
Write-Verbose "Min level: $MinLevel"

[int]$MinLevelInt = [convert]::ToInt16($MinLevel, 10)

# Read raw saved game file using ark-tools.exe
Write-Output "Extracting wild dino details..."
.\ark-tools.exe wild $SavedGameFile $DestinationFolder

# Get a list of the files created
$wildFiles = Get-ChildItem -Path $DestinationFolder
Write-Verbose "$($wildFiles.Count) Wild Dinosaur files read..."

foreach ($wildFile in $wildFiles)
{
    $dinoName = $wildFile.Name -split "_Character" | Select-Object -First 1

    if ($dinoName -match "json")
    {
        continue
    }
    elseif ($dinoName -notmatch $Species)
    {
        continue
    }
    elseif ($dinoName -match "Megalodon" -and $FindAlphas -eq $true)
    {
        continue
    }

    Write-Verbose $dinoName

    $wildDinos = Get-Content $wildFile.FullName -Raw | ConvertFrom-Json
    Write-Output "$($wildDinos.Count) $($dinoName)s found"

    if ($ShowTotalsOnly -eq $true)
    {
        continue
    }

    foreach ($wildDino in $WildDinos)
    {
        $colors = ""

        [int]$dinoLevel = [convert]::ToInt16($wildDino.baseLevel, 10)
        if ($dinoLevel -ge $MinLevelInt)
        {
 
            $colorsUsed = Get-Member -InputObject $wildDino -MemberType Properties -Name color* | Select-Object Name
                        
            foreach ($color in $colorsUsed)
            {
                if ($colors -ne "")
                {
                    $colors += ", "
                }

                $colors += $dinoColors[$wildDino.$($color.Name)]
            }

            if ($wildDino.female -eq $true)
            {
                $gender = "Female"
            }
            else
            {
                $gender = "Male"
            }

            Write-Output "Level $dinoLevel $gender lat $($wildDino.lat), lon $($wildDino.lon) (H: $($wildDino.wildLevels.health) S: $($wildDino.wildLevels.stamina) O: $($wildDino.wildLevels.oxygen) F: $($wildDino.wildLevels.food) W: $($wildDino.wildLevels.weight) M: $($wildDino.wildLevels.melee) S: $($wildDino.wildLevels.speed)) {$colors}"
        }
    }
}
