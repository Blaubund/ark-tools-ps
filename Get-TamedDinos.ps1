# Examples:
#
#   .\Get-TamedDinos.ps1 -Name Connor
#   .\Get-TamedDinos.ps1 -Species Rex -MinLevel 100
#   .\Get-TamedDinos.ps1 -Species Saber -Gender Female
#   .\Get-TamedDinos.ps1 -Species crab -MinUberStat 30
#   .\Get-TamedDinos.ps1 -Species wolf -MinMeleePoints 30
#   .\Get-TamedDinos.ps1 -NearDino Rocky -Range 5
#
# To do: 
#   - Automatically detect where the ARK saved game files are as a default
#   - Automatically create destination folder if it doesn't exist
#   - Add filter and output for:
#      o Owner
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

    [switch] $ShowSpeciesOnly,

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

if ($MinLevel -eq 0)
{
    $MinLevel = $defaultTamedMinLevel
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

# Clean up folder before extracting
Remove-Item -Path $DestinationFolder\* -Filter *.json

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
    $dinoClassName = $class.Name
    $dinoFile = "$dinoClass.json"
    $headerWritten = $false

    if ($dinoClassName -match "_Character")
    {
        $dinoClassName = $dinoClassName -split "_Character" | Select-Object -First 1
    }

    Write-Verbose "Class: $dinoClass, Name: $dinoClassName, File: $dinoFile"

    if ($ShowSpeciesOnly -eq $true)
    {
        Write-Output "$dinoClassName"
        continue
    }

    if ($dinoClassName -notmatch $Species)
    {
        Write-Verbose "Species not a match, skipping..."
        continue
    }

    $tamedDinos = Get-Content "$DestinationFolder\$dinoFile" -Raw | ConvertFrom-Json
    Write-Verbose "$($tamedDinos.Count) $dinoClassName found total"

    if ($ShowTotalsOnly -eq $true)
    {
        continue
    }

    foreach ($dino in $tamedDinos)
    {
        $colors = ""
        $hasUberStat = $false

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

        try
        {
            [int]$dinoLevel = $dinoBaseLevel + $dinoExtraLevel
        }
        catch
        {
            $dinoLevel = 0
        }
        
        Write-Verbose "Dino level: $dinoLevel"

        if ($dinoLevel -lt $MinLevel -or $dinoLevel -gt $MaxLevel)
        {
            Write-Verbose "Level not within specified range, skipping..."
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
            $dinoGender = "M"
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

        if ($headerWritten -ne $true)
        {
            Write-Output ""
            Write-Output "$dinoClassName"
            Write-Output "------------------------------------"
            $headerWritten = $true
        }
            
        Write-Output "$dinoName, Level $dinoLevel ($dinoBaseLevel) $dinoGender $location (H: $($dino.wildLevels.health) S: $($dino.wildLevels.stamina) O: $($dino.wildLevels.oxygen) F: $($dino.wildLevels.food) W: $($dino.wildLevels.weight) M: $($dino.wildLevels.melee) S: $($dino.wildLevels.speed)) {$colors}"
    }
}
