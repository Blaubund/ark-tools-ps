# Examples:
#
#   .\Get-TamedDinos.ps1
#   .\Get-TamedDinos.ps1 -Name Connor
#   .\Get-TamedDinos.ps1 -Species Rex -MinLevel 100
#
# To do: 
#   - Automatically detect where the ARK saved game files are as a default
#   - Automatically create destination folder if it doesn't exist

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter()]
    [string] $Species,

    [Parameter()]
    [string] $Name,

    [Parameter()]
    [string] $Gender,

    [Parameter()]
    [int] $MinLevel,

    [Parameter()]
    [int] $MaxLevel,

    [switch] $ShowTotalsOnly,

    [switch] $ShowXYZ,
    
    [Parameter()]
    [string] $SavedGameFile,

    [Parameter()]
    [string] $DestinationFolder
)

. ".\DinoColors.ps1"

$defaultSpecies = ".*"
$defaultName = ".*"
$defaultMinLevel = 1
$defaultMaxLevel = 99999
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

if ($Gender -ne "")
{
    if ($Gender -match "^f")
    {
        $Gender = "Female"
    }
    else
    {
        $Gender = "Male"
    }
}

if ($MinLevel -eq 0)
{
    $MinLevel = $defaultMinLevel
}

if ($MaxLevel -eq 0)
{
    $MaxLevel = $defaultMaxLevel
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
Write-Verbose "Gender: $Gender"
Write-Verbose "Min level: $MinLevel"
Write-Verbose "Max level: $MaxLevel"
Write-Verbose "Save game file: $SavedGameFile"
Write-Verbose "Destination folder: $DestinationFolder"

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

    if ($ShowTotalsOnly -eq $true)
    {
        continue
    }

    foreach ($dino in $tamedDinos)
    {
        $colors = ""

        $dinoName = $dino.Name
        if ($dinoName -eq "" -or $dinoName -eq $null)
        {
            $dinoName = "Unnamed"
        }
        if ($dinoName -notmatch $Name)
        {
            continue
        }

        [int]$dinoBaseLevel = [convert]::ToInt16($dino.baseLevel, 10)

        if ($dino.fullLevel -ne "" -and $dino.fullLevel -ne $null)
        {
            [int]$dinoLevel = [convert]::ToInt16($dino.fullLevel, 10)
        }
        else
        {
            [int]$dinoLevel = 0;
        }

        if ($dinoLevel -lt $MinLevel -or $dinoLevel -gt $MaxLevel)
        {
            continue
        }
 
        $colorsUsed = Get-Member -InputObject $dino -MemberType Properties -Name color* | Select-Object Name
                        
        foreach ($color in $colorsUsed)
        {
            if ($colors -ne "")
            {
                $colors += ", "
            }

            $colors += $dinoColors[$dino.$($color.Name)]
        }

        if ($dino.female -eq $true)
        {
            $dinoGender = "Female"
        }
        else
        {
            $dinoGender = "Male"
        }

        if ($Gender -ne "" -and $Gender -ne $dinoGender)
        {
            continue
        }

        if ($ShowXYZ -eq $true)
        {
            $x = [math]::Round($dino.x)
            $y = [math]::Round($dino.y)
            $z = [math]::Round($dino.z)
            $location =  "xyz $x $y $z"
        }
        else
        {
            $location = "lat $($dino.lat), lon $($dino.lon)"
        }
            
        Write-Output "$dinoName, Level $dinoLevel ($dinoBaseLevel) $dinoGender $location (H: $($dino.wildLevels.health) S: $($dino.wildLevels.stamina) O: $($dino.wildLevels.oxygen) F: $($dino.wildLevels.food) W: $($dino.wildLevels.weight) M: $($dino.wildLevels.melee) S: $($dino.wildLevels.speed)) {$colors}"
    }
}
