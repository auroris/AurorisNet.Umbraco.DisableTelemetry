#Requires -Version 7.0
<#
.SYNOPSIS
Adds Umbraco releases to the releases the package supports.

.DESCRIPTION
Adds each release to UmbracoReleases in Directory.Build.props, keeping the list oldest first, and sets
UmbracoMinimumVersion, UmbracoMaximumVersion and UmbracoVersion to the oldest and newest listed releases. Then writes
each major version's releases, such as 18.0.0 to 18.3.2, between its <!-- umbraco-releases 18 --> and
<!-- /umbraco-releases --> markers in README.md. A release that is already listed changes nothing. A release of a
major version that the list does not include stops the script, because supporting it takes the steps in the README's
Developing section.

.PARAMETER Releases
The releases to add, such as 18.3.2. A value can list several, separated by commas.

.PARAMETER Repository
The repository's root folder. Defaults to the one this script is in.

.OUTPUTS
The releases it added.
#>
param(
    [Parameter(Mandatory)][string[]] $Releases,
    [string] $Repository = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)

$ErrorActionPreference = 'Stop'
$split = [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries
$Releases = @($Releases | ForEach-Object { $_.Split(',', $split) })

<#
.SYNOPSIS
Reads a text file and returns its text and whether it starts with a UTF-8 byte order mark, so it can be written back
the same way.
#>
function Read-Text([string] $path) {
    $bytes = [IO.File]::ReadAllBytes($path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    [pscustomobject]@{ Text = [Text.UTF8Encoding]::new($false).GetString($bytes, $bom ? 3 : 0, $bytes.Length - ($bom ? 3 : 0)); Bom = $bom }
}

<#
.SYNOPSIS
Writes text to a file as UTF-8, with a byte order mark only when the file had one.
#>
function Write-Text([string] $path, [string] $text, [bool] $bom) {
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($bom))
}

$propsPath = Join-Path $Repository 'Directory.Build.props'
$props = Read-Text $propsPath
$list = [regex]::Match($props.Text, '<UmbracoReleases>([^<]*)</UmbracoReleases>')
if (-not $list.Success) { throw 'Directory.Build.props has no UmbracoReleases.' }
$listed = [Collections.Generic.List[version]]::new()
$list.Groups[1].Value.Split(';', $split) | ForEach-Object { $listed.Add([version] $_) }
$majors = @($listed | ForEach-Object Major | Sort-Object -Unique)

$added = foreach ($text in $Releases) {
    if ($text -notmatch '^\d+\.\d+\.\d+$') { throw "$text is not a release number such as 18.3.2." }
    $release = [version] $text
    if ($release.Major -notin $majors) {
        throw "Umbraco $release is a major version the package does not support yet. The README's Developing section lists the steps."
    }
    if ($listed.Contains($release)) { continue }
    $listed.Add($release)
    $release.ToString()
}
if (-not $added) { return }

$sorted = @($listed | Sort-Object)
$text = $props.Text
$text = $text -replace '<UmbracoReleases>[^<]*</UmbracoReleases>', "<UmbracoReleases>$($sorted -join ';')</UmbracoReleases>"
$text = $text -replace '<UmbracoMinimumVersion>[^<]*</UmbracoMinimumVersion>', "<UmbracoMinimumVersion>$($sorted[0])</UmbracoMinimumVersion>"
$text = $text -replace '<UmbracoMaximumVersion>[^<]*</UmbracoMaximumVersion>', "<UmbracoMaximumVersion>$($sorted[-1])</UmbracoMaximumVersion>"
$text = $text -replace '<UmbracoVersion>[^<]*</UmbracoVersion>', "<UmbracoVersion>$($sorted[-1])</UmbracoVersion>"
$writes = [Collections.Generic.List[object]]::new()
$writes.Add([pscustomobject]@{ Path = $propsPath; Text = $text; Bom = $props.Bom })

# Each major version's releases: "18.0.0 to 18.3.2", or a release on its own.
$rangeOf = @{}
$sorted | Group-Object Major | ForEach-Object {
    $rangeOf[$_.Name] = $_.Count -eq 1 ? "$($_.Group[0])" : "$($_.Group[0]) to $($_.Group[-1])"
}

# Only the markers hold the releases, so examples that mention other releases stay as they are.
$readmePath = Join-Path $Repository 'README.md'
if (Test-Path -LiteralPath $readmePath) {
    $readme = Read-Text $readmePath
    $updated = $readme.Text -creplace '(<!-- umbraco-releases (\d+) -->)[^<]*(<!-- /umbraco-releases -->)', {
        $range = $rangeOf[$_.Groups[2].Value]
        $range ? $_.Groups[1].Value + $range + $_.Groups[3].Value : $_.Value
    }
    if ($updated -cne $readme.Text) { $writes.Add([pscustomobject]@{ Path = $readmePath; Text = $updated; Bom = $readme.Bom }) }
}
# Write nothing until every file has been read.
foreach ($write in $writes) { Write-Text $write.Path $write.Text $write.Bom }

$added
