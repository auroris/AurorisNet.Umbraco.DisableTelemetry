<#
.SYNOPSIS
Chooses the package versions and release tags for the next release from main.

.DESCRIPTION
A release publishes the same package once for each Umbraco major version in UmbracoReleases in Directory.Build.props,
so a site can float on the version numbers of its own Umbraco major version, such as 17.* or 18.*. Each package version
is the newest listed release of its major version followed by a release count. For the newest major version, that
release is UmbracoMaximumVersion. Without UmbracoReleases, the release publishes one package, for
UmbracoMaximumVersion.

The script checks that the release runs from main and that the checkout is the commit being released. A commit that
already carries a release tag for an Umbraco release reuses that count, so a retried release can finish. Any other
commit must be the tip of main on origin, and it gets the count after the highest existing tag for the same Umbraco
release, starting at 1.

.PARAMETER BranchName
The branch being released, which must be main.

.PARAMETER Commit
The full hash of the commit being released. It must match the checked-out HEAD.

.OUTPUTS
One object per Umbraco major version, newest first, with Umbraco, the Umbraco release its version starts with, such as
18.3.1, Version, such as 18.3.1.2, and Tag, such as v18.3.1.2.
#>
param(
    [Parameter(Mandatory)][string] $BranchName,
    [Parameter(Mandatory)][string] $Commit
)

$ErrorActionPreference = 'Stop'
$releaseNumber = '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
[xml] $settings = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../../Directory.Build.props')

<#
.SYNOPSIS
Returns the value of the property <name> in Directory.Build.props, or an empty string when the file does not set it.
The file can have several property groups, so the property is found by its path rather than through one group.
#>
function Get-BuildProperty([string] $name) {
    [string] $settings.SelectSingleNode("/Project/PropertyGroup/$name").InnerText
}

$umbracoVersion = Get-BuildProperty 'UmbracoMaximumVersion'
if ($umbracoVersion -cnotmatch $releaseNumber) {
    throw 'UmbracoMaximumVersion must contain exactly three numeric components.'
}

# The newest major version's package follows UmbracoMaximumVersion, and each older major version's follows its newest
# listed release.
$releases = @($umbracoVersion)
$listed = @((Get-BuildProperty 'UmbracoReleases').Split(';',
        [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries))
foreach ($release in $listed) {
    if ($release -cnotmatch $releaseNumber) { throw "UmbracoReleases lists $release, which must contain exactly three numeric components." }
}
$releases += @($listed | Group-Object { ([version] $_).Major } |
    Where-Object { [int] $_.Name -ne ([version] $umbracoVersion).Major } |
    ForEach-Object { ($_.Group | Sort-Object { [version] $_ })[-1] } |
    Sort-Object { [version] $_ } -Descending)

if ($BranchName -cne 'main') {
    throw "Release from the main branch, not $BranchName."
}
$headCommit = git rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $headCommit -cne $Commit) {
    throw 'The checkout must be the exact commit being released.'
}

<#
.SYNOPSIS
Returns the release count for the next package version that starts with the Umbraco release <umbraco>.
#>
function Get-Revision([string] $umbraco) {
    $tags = @(git tag --list "v$umbraco.*")
    if ($LASTEXITCODE -ne 0) { throw 'Could not read release tags.' }
    $pattern = '^v' + [regex]::Escape($umbraco) + '\.([1-9][0-9]*)$'
    $revisions = @($tags | ForEach-Object {
        if ($_ -cmatch $pattern) { [int] $Matches[1] }
    })
    $headTags = @(git tag --points-at $Commit --list "v$umbraco.*")
    if ($LASTEXITCODE -ne 0) { throw 'Could not read tags for the release commit.' }
    $headRevisions = @($headTags | ForEach-Object {
        if ($_ -cmatch $pattern) { [int] $Matches[1] }
    })
    $revision = 1
    if ($headRevisions.Count -gt 0) {
        # A retried release reuses the version reserved for this commit, even after a newer commit has been released.
        $revision = [int] ($headRevisions | Measure-Object -Maximum).Maximum
    } else {
        # Allocate a new revision only for the branch tip. Re-running an old workflow run checks out its original commit,
        # and that would publish older code under the newest revision.
        $branchTip = git rev-parse --verify --quiet "refs/remotes/origin/$BranchName"
        if ($LASTEXITCODE -ne 0 -or $branchTip -cne $Commit) {
            throw "Commit $Commit is not the tip of $BranchName. Run Release again from the branch to publish its latest commit."
        }
        if ($revisions.Count -gt 0) {
            $revision = [int] ($revisions | Measure-Object -Maximum).Maximum + 1
        }
    }
    if ($revision -gt 65534) { throw 'The revision exceeds the .NET assembly version limit.' }
    $revision
}

foreach ($umbraco in $releases) {
    $revision = Get-Revision $umbraco
    [pscustomobject]@{
        Umbraco = $umbraco
        Version = "$umbraco.$revision"
        Tag = "v$umbraco.$revision"
    }
}
