#Requires -Version 7.0
<#
.SYNOPSIS
Tells whether the GitHub release of a package version should be marked as the latest.

.DESCRIPTION
GitHub shows one release of a repository as the latest. A release takes that place only when no published release has a
newer package version. Running Release again for an older commit, after a newer release was published, then creates
the older release without moving the mark back to it. The script compares the versions in release tags, such as
v18.3.1.2, as numbers. Other tags and draft releases do not count.

.PARAMETER Version
The package version being released, such as 18.3.1.2.

.PARAMETER Published
The tags of the published releases to compare with, for tests. Defaults to the releases of the repository in
GITHUB_REPOSITORY, read with the GitHub CLI, which needs GH_TOKEN.

.OUTPUTS
True when no published release has a newer version, and false otherwise.
#>
param(
    [Parameter(Mandatory)][string] $Version,
    [string[]] $Published
)

$ErrorActionPreference = 'Stop'
$packageVersion = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.([1-9][0-9]*)$'
if ($Version -cnotmatch $packageVersion) { throw "$Version is not a package version such as 18.3.1.2." }
if (-not $PSBoundParameters.ContainsKey('Published')) {
    if (-not $env:GITHUB_REPOSITORY) { throw 'GITHUB_REPOSITORY must name the repository whose releases to read.' }
    $Published = @(gh api "repos/$env:GITHUB_REPOSITORY/releases" --paginate --jq '.[] | select(.draft | not) | .tag_name')
    if ($LASTEXITCODE -ne 0) { throw 'Could not read the GitHub releases.' }
}

$newer = @($Published | Where-Object { $_ -cmatch ('^v' + $packageVersion.Substring(1)) } |
    Where-Object { [version] $_.Substring(1) -gt [version] $Version })
$newer.Count -eq 0
