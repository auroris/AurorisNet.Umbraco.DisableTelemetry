#Requires -Version 7.0
<#
.SYNOPSIS
Adds Umbraco releases to the releases the package supports.

.DESCRIPTION
Adds each release to UmbracoReleases in Directory.Build.props, keeping the list oldest first, and sets
UmbracoMinimumVersion, UmbracoMaximumVersion and UmbracoVersion to the oldest and newest listed releases. Then writes
each major version's releases, such as 18.0.0 to 18.3.2, between its <!-- umbraco-releases 18 --> and
<!-- /umbraco-releases --> markers in README.md and the Markdown files in docs. nuget.org shows docs/NUGET.md without
HTML, so that file lists the releases as plain text after "running Umbraco ", newest major version first, and the
script rewrites that list. A release that is already listed changes nothing. A release of a major version that the
list does not include stops the script, because supporting it takes the changes that docs/DEVELOPING.md describes.

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
        throw "Umbraco $release is a major version the package does not support yet. docs/DEVELOPING.md lists the steps."
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

# Each major version's releases, newest major version first: "18.0.0 to 18.3.2", or a release on its own.
$ranges = @($sorted | Group-Object Major | Sort-Object { [int] $_.Name } -Descending | ForEach-Object {
    [pscustomobject]@{ Major = $_.Name; Range = $_.Count -eq 1 ? "$($_.Group[0])" : "$($_.Group[0]) to $($_.Group[-1])" }
})
$rangeOf = @{}
$ranges | ForEach-Object { $rangeOf[$_.Major] = $_.Range }
$each = @($ranges.Range)
$nugetRanges = $each.Count -le 2 ? ($each -join ' or ') : ((@($each[0..($each.Count - 2)]) -join ', ') + ' or ' + $each[-1])

# Markers and the NuGet page's list hold the releases, so examples that mention other releases stay as they are.
$rangePattern = '\d+\.\d+\.\d+(?: to \d+\.\d+\.\d+)?'
$nugetList = "(?<=running Umbraco )$rangePattern(?:(?:,? or|,) $rangePattern)*"
$nuget = [IO.Path]::GetFullPath((Join-Path $Repository 'docs' 'NUGET.md'))
$documents = @(Join-Path $Repository 'README.md') + @(Get-ChildItem (Join-Path $Repository 'docs') -Filter *.md -ErrorAction SilentlyContinue | ForEach-Object FullName)
foreach ($path in $documents | Where-Object { Test-Path -LiteralPath $_ }) {
    $document = Read-Text $path
    $updated = $document.Text -creplace '(<!-- umbraco-releases (\d+) -->)[^<]*(<!-- /umbraco-releases -->)', {
        $range = $rangeOf[$_.Groups[2].Value]
        $range ? $_.Groups[1].Value + $range + $_.Groups[3].Value : $_.Value
    }
    if ([IO.Path]::GetFullPath($path) -eq $nuget) {
        if (-not [regex]::IsMatch($updated, $nugetList)) { throw 'docs/NUGET.md has no list of supported releases after "running Umbraco ".' }
        $updated = [regex]::Replace($updated, $nugetList, $nugetRanges)
    }
    if ($updated -cne $document.Text) { $writes.Add([pscustomobject]@{ Path = $path; Text = $updated; Bom = $document.Bom }) }
}
# Write nothing until every document has been read and checked.
foreach ($write in $writes) { Write-Text $write.Path $write.Text $write.Bom }

$added
