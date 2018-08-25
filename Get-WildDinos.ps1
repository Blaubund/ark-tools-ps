# Examples:
#
#   .\Get-WildDinos.ps1
#   .\Get-WildDinos.ps1 -MinLevel 116
#   .\Get-WildDinos.ps1 -FindAlphas
#   .\Get-WildDinos.ps1 -ShowTotalsOnly
#
# To do: 
#   - Automatically detect where the ARK saved game files are as a default
#   - Search for specific colors (did I do this already?)
#   - Automatically create destination folder if it doesn't exist
#   - Mega is used to find alphas, but this now matches Megatheriums
#   - Find dinos near me (or near my dino)
#   - Process classes.json instead of using file name for dino name

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

    [switch] $FindAlphas,

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

# Special case where user is looking for dinos below a specific level and the default MinLevel will be wrong
if ($MinLevel -eq 0 -and $MaxLevel -ne 0)
{
    $MinLevel = 1
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
    $DestinationFolder = $defaultDestinationFolder
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
Write-Verbose "Save game file: $SavedGameFile"
Write-Verbose "Destination folder: $DestinationFolder"

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
    Write-Output "$($wildDinos.Count) $($dinoName)s exist"

    if ($ShowTotalsOnly -eq $true)
    {
        continue
    }

    foreach ($dino in $WildDinos)
    {
        $colors = ""

        [int]$dinoLevel = [convert]::ToInt16($dino.baseLevel, 10)

        if ($dinoLevel -lt $MinLevel -or $dinoLevel -gt $MaxLevel)
        {
            continue
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

#        $colorsUsed = Get-Member -InputObject $dino -MemberType Properties -Name color* | Select-Object Name
#                        
#        foreach ($color in $colorsUsed)
#        {
####            if ($colors -ne "")
#            {
#                $colors += ", "
#            }
#
#            $colors += $dinoColors[$dino.$($color.Name)]
#        }

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

        Write-Output "Level $dinoLevel $dinoGender $location (H: $($dino.wildLevels.health) S: $($dino.wildLevels.stamina) O: $($dino.wildLevels.oxygen) F: $($dino.wildLevels.food) W: $($dino.wildLevels.weight) M: $($dino.wildLevels.melee) S: $($dino.wildLevels.speed)) {$colors}"
    }
}
