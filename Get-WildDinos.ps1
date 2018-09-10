# Examples:
#
#   .\Get-WildDinos.ps1
#   .\Get-WildDinos.ps1 -MinLevel 116
#   .\Get-WildDinos.ps1 -AlphasOnly
#   .\Get-WildDinos.ps1 -Species Argent
#   .\Get-WildDinos.ps1 -Species Rex -AlphasOnly
#   .\Get-WildDinos.ps1 -ShowTotalsOnly
#   .\Get-WildDinos.ps1 -Species wolf -Map Aberration -MinHealthPoints 20
#   .\Get-WildDinos.ps1 -Species raptor -NearDino Rocky -Range 20
#   .\Get-WildDinos.ps1 -Species lantern -MinUberStat 30
#   .\Get-WildDinos.ps1 -MinHealthPoints 40
#
# To do: 
#   - Automatically detect where the ARK saved game files are as a default
#   - Automatically create destination folder if it doesn't exist
#   - Clear out the working folder before running ark-tools.exe
#   - Search for specific colors (did I do this already?)
#   - Search for minimum pre-tame stats (e.g. 20 points in Health)


[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter()]
    [string] $Map,

    [Parameter()]
    [string] $Species,

    [Parameter()]
    [string] $Gender,

    [Parameter()]
    [int] $MinLevel,

    [Parameter()]
    [int] $MaxLevel,

    [Parameter()]
    [string] $NearDino,

    [Parameter()]
    [int] $Range,

    [Parameter()]
    [int] $MinUberStat,

    [Parameter()]
    [int] $MinHealthPoints,

    [Parameter()]
    [int] $MinStaminaPoints,

    [Parameter()]
    [int] $MinOxygenPoints,

    [Parameter()]
    [int] $MinFoodPoints,

    [Parameter()]
    [int] $MinWeightPoints,

    [Parameter()]
    [int] $MinMeleePoints,

    [switch] $AlphasOnly,

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

if ($AlphasOnly -eq $true)
{
    if ($MinLevel -eq "")
    {
        Write-Verbose "Adjusting min level to 1 for alpha hunting"
        $MinLevel = 1
    }
}

if ($Species -eq "")
{
    $Species = $defaultSpecies
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

if ($NearDino -ne "")
{
    if ($Range -eq "")
    {
        $Range = $defaultRange
    }

    $dino = .\Get-TamedDinos.ps1 -Name $NearDino | where { $_ -match $NearDino }
    if ($dino -ne $null)
    {
        Write-Verbose "Found dino $($NearDino):"
        Write-Verbose "$dino"
        $temp = $dino -match "lat (.*), lon (.*) \("
        $nearLat = [math]::Round($matches[1], 1)
        $nearLon = [math]::Round($matches[2], 1)
        Write-Verbose "$nearLat, $nearLon"
    }
    else
    {
        Write-Output "Cannot find dino named $NearDino"
        exit
    }
}

# Special case where user is looking for dinos below a specific level and the default MinLevel will be wrong
if ($MinLevel -eq 0 -and $MaxLevel -ne 0)
{
    $MinLevel = 1
}

if ($MinLevel -eq 0)
{
    $MinLevel = $defaultWildMinLevel
}

if ($MaxLevel -eq 0)
{
    $MaxLevel = $defaultMaxLevel
}

if ($SavedGameFile -eq "")
{
    $SavedGameFile = $defaultSaveFiles[$Map]
}

if ($SavedGameFile -eq "")
{
    Write-Error "Invalid map specified, aborting..."
    exit
}

if ($DestinationFolder -eq "")
{
    $DestinationFolder = $defaultWildDestinationFolder
}

if ($MaxLevel -lt $MinLevel)
{
    Write-Error "MaxLevel is less than MinLevel"
    exit
}

Write-Verbose "Map: $Map"
Write-Verbose "Species: $Species"
Write-Verbose "Gender: $Gender"
Write-Verbose "Min level: $MinLevel"
Write-Verbose "Max level: $MaxLevel"
Write-Verbose "Near Dino: $NearDino"
Write-Verbose "Range: $Range"
Write-Verbose "Min uber stat: $MinUberStat"
Write-Verbose "Min health points: $MinHealthPoints"
Write-Verbose "Min stamina points: $MinStaminaPoints"
Write-Verbose "Min oxygen points: $MinOxygenPoints"
Write-Verbose "Min food points: $MinFoodPoints"
Write-Verbose "Min weight points: $MinWeightPoints"
Write-Verbose "Min melee points: $MinMeleePoints"
Write-Verbose "Save game file: $SavedGameFile"
Write-Verbose "Destination folder: $DestinationFolder"

# Read raw saved game file using ark-tools.exe
Write-Output "Extracting wild dino details..."
.\ark-tools.exe wild $SavedGameFile $DestinationFolder

# Read the Classes file
$classFile = "$DestinationFolder\classes.json"
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
    elseif ($AlphasOnly -eq $true -and $dinoName -notmatch "Alpha")
    {
        Write-Verbose "Not an alpha, skipping..."
        continue
    }

    Write-Output ""
    Write-Output "$dinoName"
    Write-Output "------------------------------------"

    $wildDinos = Get-Content "$DestinationFolder\$dinoFile" -Raw | ConvertFrom-Json
    Write-Verbose "$($wildDinos.Count) $dinoName found total"

    if ($ShowTotalsOnly -eq $true)
    {
        continue
    }

    foreach ($dino in $wildDinos)
    {
        $colors = ""
        $hasUberStat = $false

        [int]$dinoLevel = [convert]::ToInt16($dino.baseLevel, 10)

        if ($dinoLevel -lt $MinLevel -or $dinoLevel -gt $MaxLevel)
        {
            continue
        }

        # Calculate stats
        if ($dino.wildLevels.health -ne $null)
        {
            [int]$hp = [convert]::ToInt16($dino.wildLevels.health, 10)
        }

        if ($dino.wildLevels.stamina -ne $null)
        {
            [int]$sp = [convert]::ToInt16($dino.wildLevels.stamina, 10)
        }

        if ($dino.wildLevels.oxygen -ne $null)
        {
            [int]$op = [convert]::ToInt16($dino.wildLevels.oxygen, 10)
        }

        if ($dino.wildLevels.food -ne $null)
        {
            [int]$fp = [convert]::ToInt16($dino.wildLevels.food, 10)
        }

        if ($dino.wildLevels.weight -ne $null)
        {
            [int]$wp = [convert]::ToInt16($dino.wildLevels.weight, 10)
        }

        if ($dino.wildLevels.melee -ne $null)
        {
            [int]$mp = [convert]::ToInt16($dino.wildLevels.melee, 10)
        }

        # Check for uber stat, if specified
        if ($MinUberStat -ne "")
        {
            if ($hp -ge $MinUberStat)
            {
                $hasUberStat = $true
            }

            if ($sp -ge $MinUberStat)
            {
                $hasUberStat = $true
            }

            if ($op -ge $MinUberStat)
            {
                $hasUberStat = $true
            }

            if ($fp -ge $MinUberStat)
            {
                $hasUberStat = $true
            }

            if ($wp -ge $MinUberStat)
            {
                $hasUberStat = $true
            }

            if ($mp -ge $MinUberStat)
            {
                $hasUberStat = $true
            }

            if ($hasUberStat -eq $false)
            {
                continue
            }
        }

        # Check minimum stats
        if ($MinHealthPoints -ne "")
        {
            if ($hp -lt $MinHealthPoints)
            {
                continue
            }
        }

        if ($MinStaminaPoints -ne "")
        {
            if ($sp -lt $MinStaminaPoints)
            {
                continue
            }
        }

        if ($MinOxygenPoints -ne "")
        {
            if ($op -lt $MinOxygenPoints)
            {
                continue
            }
        }

        if ($MinFoodPoints -ne "")
        {
            if ($fp -lt $MinFoodPoints)
            {
                continue
            }
        }

        if ($MinWeightPoints -ne "")
        {
            if ($wp -lt $MinWeightPoints)
            {
                continue
            }
        }

        if ($MinMeleePoints -ne "")
        {
            if ($mp -lt $MinMeleePoints)
            {
                continue
            }
        }

        if ($dino.female -eq $true)
        {
            $dinoGender = "F"
        }
        else
        {
            $DinoGender = "M"
        }

        if ($Gender -ne "" -and $Gender -ne $dinoGender)
        {
            continue
        }

        if ($dino.colorSetIndices -ne $null)
        {
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
        }

        $lat = [math]::Round($dino.location.lat, 1)
        $lon = [math]::Round($dino.location.lon, 1)

        if ($NearDino -ne "")
        {
            $diffLat = [math]::Abs($lat - $nearLat)
            $diffLon = [math]::Abs($lon - $nearLon)
            Write-Verbose "diffLat: $diffLat"
            Write-Verbose "diffLon: $diffLon"
            if ($diffLat  -gt $Range)
            {
                Write-Verbose "Latitude not within range of $NearDino"
                continue
            }
            if ($diffLon -gt $Range)
            {
                Write-Verbose "Longitude not within range of $NearDino"
                continue
            }
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
            $location = "lat $lat, lon $lon"
        }
        Write-Verbose "Location: $location"

        Write-Output "Level $dinoLevel $dinoGender $location (H: $($dino.wildLevels.health) S: $($dino.wildLevels.stamina) O: $($dino.wildLevels.oxygen) F: $($dino.wildLevels.food) W: $($dino.wildLevels.weight) M: $($dino.wildLevels.melee) S: $($dino.wildLevels.speed)) {$colors}"
    }
}
