# Examples:
#
#   ./get
#   .\Get-TamedDinos.ps1 -Name Connor
#   .\Get-TamedDinos.ps1 -Species Rex -MinLevel 100
#   .\Get-TamedDinos.ps1 -Species Saber -Gender Female
#
# To do: 
#   - Automatically detect where the ARK saved game files are as a default
#   - Automatically create destination folder if it doesn't exist
#   - Provide map name defaults for each main map (i.e. Ragnarok, Scorched Earth, etc)
#   - Process classes.json instead of using file name for dino name
#   - Add filter for:
#      o Owner
#      o Base Level
#      o Wild levels in various stats
#      o Imprinter
#      o Imprinting quality

# This might be useful
#PS C:\Users\Rand\repos\Blaubund\git-tools-ps> $dino = Get-Content ".\tamed\Wyvern_Character_BP_Poison_C.json" -Raw | ConvertFrom-Json
#PS C:\Users\Rand\repos\Blaubund\git-tools-ps> $dino


#allowLevelUps          : True
#baseLevel              : 175
#colorSetIndices        : @{0=8; 1=26; 2=8; 3=45; 4=25; 5=8}
#experience             : 33936.07
#extraLevel             : 62
#id                     : 1724025659628489529
#imprinter              : Cranius
#imprintingQuality      : 1.0
#lastEnterStasisTime    : 61855.2421875
#location               : @{x=173291.17; y=-13879.553; z=-7751.4106; lat=48.265057; lon=71.66139}
#myInventoryComponent   : 195
#name                   : Caustic
#ownerName              : Cranius
#playerId               : 862478282
#requiredTameAffinity   : 16750.0
#tamed                  : True
#tamedLevels            : @{health=14; stamina=29; weight=13; melee=6}
#tamedOnServerName      : ARK #808716
#tamer                  : Cranius
#tamingEffectivness     : 1.0
#tamingTeamID           : 862478282
#team                   : 862478282
#type                   : Poison Wyvern
#uploadedFromServerName :
#                         ARK #808716
#wildLevels             : @{health=26; stamina=37; oxygen=37; food=28; weight=19; melee=27}

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
#$defaultSavedGameFile = "C:\Users\Rand\desktop\TheIsland.ark"
#$defaultSavedGameFile = "D:\SteamLibrary\steamapps\common\ARK\ShooterGame\Saved\ScorchedEarth_PSavedArksLocal\ScorchedEarth_P.ark"
$defaultSavedGameFile = "D:\SteamLibrary\steamapps\common\ARK\ShooterGame\Saved\RagnarokSavedArksLocal\Ragnarok.ark"
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
        Write-Verbose "Skipping file $dinoSpecies"
        continue
    }
    elseif ($dinoSpecies -notmatch $Species)
    {
        Write-Verbose "Skipping dino $dinoSpecies"
        continue
    }

    Write-Output $dinoSpecies
    Write-Output "------------------------------------"

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
 
        # This appears to have changed
#       $colorsUsed = Get-Member -InputObject $dino -MemberType Properties -Name color* | Select-Object Name
#       Write-Verbose "Colors used: $colorsUsed"
#                       
#       foreach ($color in $colorsUsed)
#       {
#           if ($colors -ne "")
#           {
#               $colors += ", "
#           }
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

        # This appears to no longer be available, but leaving it here in case it comes back
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
