#Requires -Version 7.0
<#
.SYNOPSIS
Finds Umbraco releases on NuGet that the package does not list yet.

.DESCRIPTION
Reads UmbracoReleases from Directory.Build.props and compares it with the published versions of Umbraco.Cms. A
release is new when it is a stable release of a supported major version and newer than the newest listed release of
that major version; older releases that the list leaves out were left out on purpose. A stable release of a newer major
version is reported separately, because supporting it takes the changes that docs/DEVELOPING.md describes. Prereleases
are ignored.

.PARAMETER Published
The published versions to compare with, for tests. Defaults to the versions of Umbraco.Cms on nuget.org.

.OUTPUTS
An object with Releases, the new releases of supported major versions, oldest first, and NewMajors, the newest stable
release of each newer major version.
#>
param(
    [string[]] $Published
)

$ErrorActionPreference = 'Stop'
$split = [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries
[xml] $settings = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Directory.Build.props')
# The file can have several property groups, so find the property by its path rather than through one group.
$listed = @(([string] $settings.SelectSingleNode('/Project/PropertyGroup/UmbracoReleases').InnerText).Split(';', $split) |
    ForEach-Object { [version] $_ })
if (-not $listed) { throw 'Directory.Build.props lists no UmbracoReleases.' }
if (-not $Published) {
    $Published = (Invoke-RestMethod -Uri 'https://api.nuget.org/v3-flatcontainer/umbraco.cms/index.json' -TimeoutSec 60).versions
}

# The newest listed release of each supported major version.
$newestListed = @{}
foreach ($group in $listed | Group-Object Major) {
    $newestListed[[int] $group.Name] = ($group.Group | Sort-Object)[-1]
}
$newestMajor = ($newestListed.Keys | Measure-Object -Maximum).Maximum

$stable = @($Published | Where-Object { $_ -match '^\d+\.\d+\.\d+$' } | ForEach-Object { [version] $_ })
$releases = @($stable | Where-Object { $newestListed.ContainsKey($_.Major) -and $_ -gt $newestListed[$_.Major] } | Sort-Object)
$newMajors = @($stable | Where-Object { $_.Major -gt $newestMajor } | Group-Object Major |
    ForEach-Object { ($_.Group | Sort-Object)[-1] } | Sort-Object)

[pscustomobject]@{
    Releases = @($releases | ForEach-Object { $_.ToString() })
    NewMajors = @($newMajors | ForEach-Object { $_.ToString() })
}
