# Examples:
#
#   .\Get-TamedDinos.ps1
#
# To do: 
#   - Automatically detect where the ARK saved game files are as a default

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter()]
    [string] $Species,

    [Parameter()]
    [string] $Name,

    [Parameter()]
    [string] $MinLevel,
    
    [Parameter()]
    [string] $SavedGameFile,

    [Parameter()]
    [string] $DestinationFolder
)

. ".\DinoColors.ps1"

$defaultSpecies = ".*"
$defaultName = ".*"
$defaultMinLevel = "1"
$defaultSavedGameFile = "D:\SteamLibrary\steamapps\common\ARK\ShooterGame\Saved\SavedArksLocal\TheIsland.ark"
$defaultDestinationFolder = "Tamed"

if ($Species -eq "")
{
    $Species = $defaultSpecies
}

if ($Name -eq "")
{
    $Name = $defaultName
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

Write-Verbose "Species: $Species"
Write-Verbose "Name: $Name"
Write-Verbose "Min level: $MinLevel"
Write-Verbose "Save game file: $SavedGameFile"
Write-Verbose "Destination folder: $DestinationFolder"

[int]$MinLevelInt = [convert]::ToInt16($MinLevel, 10)

# Read raw saved game file using ark-tools.exe
Write-Output "Extracting Tamed dino details..."
.\ark-tools.exe tamed $SavedGameFile $DestinationFolder

# Get a list of the files created
$tamedFiles = Get-ChildItem -Path $DestinationFolder
Write-Verbose "$($tamedFiles.Count) Tamed Dinosaur files read..."

foreach ($tamedFile in $tamedFiles)
{
    $dinoSpecies = $tamedFile.Name -split "_Character" | Select-Object -First 1

    if ($dinoSpecies -match "json")
    {
        continue
    }
    elseif ($dinoSpecies -notmatch $Species)
    {
        continue
    }

    Write-Verbose $dinoSpecies

    $tamedDinos = Get-Content $tamedFile.FullName -Raw | ConvertFrom-Json
    Write-Verbose "$($tamedDinos.Count) $dinoSpecies found total"

    foreach ($tamedDino in $tamedDinos)
    {
        $colors = ""

        $dinoName = $tamedDino.Name
        if ($dinoName -eq "" -or $dinoName -eq $null)
        {
            $dinoName = "Unnamed"
        }
        if ($dinoName -notmatch $Name)
        {
            continue
        }

        [int]$dinoBaseLevel = [convert]::ToInt16($tamedDino.baseLevel, 10)
        [int]$dinoLevel = [convert]::ToInt16($tamedDino.fullLevel, 10)
        if ($dinoLevel -ge $MinLevelInt)
        {
 
            $colorsUsed = Get-Member -InputObject $tamedDino -MemberType Properties -Name color* | Select-Object Name
                        
            foreach ($color in $colorsUsed)
            {
                if ($colors -ne "")
                {
                    $colors += ", "
                }

                $colors += $dinoColors[$tamedDino.$($color.Name)]
            }

            if ($tamedDino.female -eq $true)
            {
                $gender = "Female"
            }
            else
            {
                $gender = "Male"
            }
          
            Write-Output "$dinoName, Level $dinoLevel ($dinoBaseLevel) $gender lat $($tamedDino.lat), lon $($tamedDino.lon) (H: $($tamedDino.wildLevels.health) S: $($tamedDino.wildLevels.stamina) O: $($tamedDino.wildLevels.oxygen) F: $($tamedDino.wildLevels.food) W: $($tamedDino.wildLevels.weight) M: $($tamedDino.wildLevels.melee) S: $($tamedDino.wildLevels.speed)) {$colors}"
        }
    }
}
