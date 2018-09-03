# Examples:
#
#   .\Get-TamedDinos.ps1 -Name Connor
#   .\Get-TamedDinos.ps1 -Species Rex -MinLevel 100
#   .\Get-TamedDinos.ps1 -Species Saber -Gender Female
#
# To do: 
#   - Automatically detect where the ARK saved game files are as a default
#   - Automatically create destination folder if it doesn't exist
#   - Clear out the working folder before running ark-tools.exe
#   - Add filter for:
#      o Owner
#      o Base Level
#      o Wild levels in various stats
#      o Imprinter
#      o Imprinting quality

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter()]
    [string] $Map,

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

. ".\Config.ps1"
. ".\DinoColors.ps1"

if ($Map -eq "")
{
    $Map = $defaultMap
}

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
        $Gender = "F"
    }
    else
    {
        $Gender = "M"
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
    $SavedGameFile = $defaultSaveFiles[$Map]
}

if ($DestinationFolder -eq "")
{
    $DestinationFolder = $defaultTamedDestinationFolder
}

Write-Verbose "Map: $Map"
Write-Verbose "Species: $Species"
Write-Verbose "Name: $Name"
Write-Verbose "Gender: $Gender"
Write-Verbose "Min level: $MinLevel"
Write-Verbose "Max level: $MaxLevel"
Write-Verbose "Save game file: $SavedGameFile"
Write-Verbose "Destination folder: $DestinationFolder"

# Read raw saved game file using ark-tools.exe
Write-Output "Extracting tamed dino details..."
.\ark-tools.exe tamed $SavedGameFile $DestinationFolder

# Read the Classes file
$classFile = "$($DestinationFolder)\classes.json"
$dinoClasses = Get-Content $classfile -Raw | ConvertFrom-Json
Write-Verbose "$($dinoClasses.Count) dino classes exist"
foreach ($class in $dinoClasses)
{
    $dinoClass = $class.cls
    $dinoName = $class.Name
    $dinoFile = "$dinoClass.json"

    if ($dinoName -match "_Character")
    {
        $dinoName = $dinoName -split "_Character" | Select-Object -First 1
    }

    Write-Verbose "Class: $dinoClass, Name: $dinoName, File: $dinoFile"

    if ($dinoName -notmatch $Species)
    {
        Write-Verbose "Species not a match, skipping..."
        continue
    }

    Write-Output ""
    Write-Output "$dinoName"
    Write-Output "------------------------------------"

    $tamedDinos = Get-Content "$DestinationFolder\$dinoFile" -Raw | ConvertFrom-Json
    Write-Verbose "$($tamedDinos.Count) $dinoName found total"

    if ($ShowTotalsOnly -eq $true)
    {
        continue
    }

    foreach ($dino in $tamedDinos)
    {
        $colors = ""

        $dinoName = $dino.Name
        Write-Verbose "Dino name: $dinoName"
        if ($dinoName -eq "" -or $dinoName -eq $null)
        {
            $dinoName = "Unnamed"
        }
        if ($dinoName -notmatch $Name)
        {
            continue
        }

        [int]$dinoBaseLevel = [convert]::ToInt16($dino.baseLevel, 10)
        Write-Verbose "Dino base level: $dinoBaseLevel"

        if ($dino.extraLevel -ne "" -and $dino.extraLevel -ne $null)
        {
            [int]$dinoExtraLevel = [convert]::ToInt16($dino.extraLevel, 10)
        }
        else
        {
            [int]$dinoExtraLevel = 0;
        }
        Write-Verbose "Dino extra level: $dinoExtraLevel"

        [int]$dinoLevel = $dinoBaseLevel + $dinoExtraLevel
        Write-Verbose "Dino level: $dinoLevel"

        if ($dinoLevel -lt $MinLevel -or $dinoLevel -gt $MaxLevel)
        {
            Write-Verbose "Level not within specified range, skipping..."
            continue
        }
 
        $colorRegions = Get-Member -InputObject $dino.colorSetIndices -MemberType NoteProperty | Select-Object -ExpandProperty Name
        Write-Verbose "Color regions: $colorRegions"

        foreach ($colorRegion in $colorRegions)
        {
            $colorValue = $dino.colorSetIndices.$colorRegion
            $colorName = $dinoColors[$colorValue]
            Write-Verbose "   $colorRegion, Value: $colorValue ($colorName)"

            if ($colors -ne "")
            {
                $colors += ", "
            }
 
             $colors += $colorName
        }

        # This appears to no longer be available, but leaving it here in case it comes back
        if ($dino.female -eq $true)
        {
            $dinoGender = "F"
        }
        else
        {
            $dinoGender = "M"
        }

        if ($Gender -ne "" -and $Gender -ne $dinoGender)
        {
            continue
        }

        if ($ShowXYZ -eq $true)
        {
            $x = [math]::Round($dino.location.x)
            $y = [math]::Round($dino.location.y)
            $z = [math]::Round($dino.location.z)
            $location =  "xyz $x $y $z"
        }
        else
        {
            $lat = [math]::Round($dino.location.lat, 1)
            $lon = [math]::Round($dino.location.lon, 1)
            $location = "lat $lat, lon $lon"
        }
        Write-Verbose "Location: $location"
            
        Write-Output "$dinoName, Level $dinoLevel ($dinoBaseLevel) $dinoGender $location (H: $($dino.wildLevels.health) S: $($dino.wildLevels.stamina) O: $($dino.wildLevels.oxygen) F: $($dino.wildLevels.food) W: $($dino.wildLevels.weight) M: $($dino.wildLevels.melee) S: $($dino.wildLevels.speed)) {$colors}"
    }
}
