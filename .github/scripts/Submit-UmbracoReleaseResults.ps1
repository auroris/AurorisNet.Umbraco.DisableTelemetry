#Requires -Version 7.0
<#
.SYNOPSIS
Reports the results of testing new Umbraco releases on GitHub: a pull request that adds the releases that passed, and
an issue for each release that failed.

.DESCRIPTION
Reads the summaries that tests/Test-UmbracoReleases.ps1 wrote with -SummaryPath. A release passed when it passed in
every summary; a missing summary, from a step that never ran, fails every release. For the releases that passed, the
script restores Directory.Build.props and README.md from the last commit, adds the releases with
Add-UmbracoRelease.ps1, commits the change on a new branch, pushes it and opens a pull request. GitHub refuses pull
requests from workflows unless the repository allows them, so it then opens an issue that links the branch instead.
For each release that failed, it opens an issue, or comments on the open issue with the same title. With -DryRun it
prints what it would report and changes nothing. Exits with 1 when any release failed.

.PARAMETER Releases
The releases that were tested. A value can list several, separated by commas.

.PARAMETER Summaries
The JSON summaries to read, such as the tests' and the browser check's.

.PARAMETER RunUrl
The address of the workflow run, whose artifacts hold the logs.

.PARAMETER DryRun
Prints the pull request and issues instead of creating them.
#>
param(
    [Parameter(Mandatory)][string[]] $Releases,
    [Parameter(Mandatory)][string[]] $Summaries,
    [string] $RunUrl = '',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$split = [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries
$Releases = @($Releases | ForEach-Object { $_.Split(',', $split) })
$Summaries = @($Summaries | ForEach-Object { $_.Split(',', $split) })
$label = 'umbraco-release'
$repository = Resolve-Path (Join-Path $PSScriptRoot '../..')

$records = foreach ($path in $Summaries) {
    $name = [IO.Path]::GetFileNameWithoutExtension($path)
    if (Test-Path -LiteralPath $path) {
        foreach ($record in Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) {
            [pscustomobject]@{ Summary = $name; Release = $record.Release; Result = $record.Result; Tests = $record.Tests; Failures = @($record.Failures) }
        }
    }
    else {
        foreach ($release in $Releases) {
            [pscustomobject]@{ Summary = $name; Release = $release; Result = 'not run'; Tests = ''; Failures = @("The $name tests did not run.") }
        }
    }
}
$passed = @($Releases | Where-Object {
    $release = $_
    @($records | Where-Object { $_.Release -eq $release -and $_.Result -eq 'passed' }).Count -eq $Summaries.Count
})
$failed = @($Releases | Where-Object { $_ -notin $passed })
$link = $RunUrl ? "[the test run]($RunUrl)" : 'the test run'

<#
.SYNOPSIS
Returns a Markdown table of the results for <releases>, one row per release and summary.
#>
function Format-Results([string[]] $releases) {
    "| Release | Tests | Result |"
    "|---|---|---|"
    foreach ($record in $records | Where-Object Release -in $releases | Sort-Object { [version] $_.Release }, Summary) {
        "| $($record.Release) | $($record.Summary): $($record.Tests) | $($record.Result) |"
    }
}

<#
.SYNOPSIS
Runs a command and throws when it fails, or on a dry run prints it instead.
#>
function Invoke-Checked([string] $command, [string[]] $arguments) {
    if ($DryRun) { Write-Host "Would run: $command $($arguments -join ' ')"; return }
    & $command @arguments
    if ($LASTEXITCODE -ne 0) { throw "$command $($arguments[0]) failed." }
}

<#
.SYNOPSIS
Opens an issue titled <title>, or comments on the open issue with that title, with <body> as its text.
#>
function Submit-Issue([string] $title, [string] $body) {
    if ($DryRun) { Write-Host "Would open the issue ""$title"":`n$body`n"; return }
    $file = New-TemporaryFile
    Set-Content -LiteralPath $file -Value $body -Encoding utf8
    $existing = gh issue list --state open --search "$title in:title" --json number,title | ConvertFrom-Json |
        Where-Object title -eq $title | Select-Object -First 1
    if ($existing) { Invoke-Checked gh @('issue', 'comment', [string] $existing.number, '--body-file', $file) }
    else { Invoke-Checked gh @('issue', 'create', '--title', $title, '--body-file', $file, '--label', $label) }
    Remove-Item -LiteralPath $file
}

if (-not $DryRun) {
    gh label create $label --color 0e8a16 --description 'A new Umbraco release and its test results' --force | Out-Null
}

foreach ($release in $failed) {
    $details = foreach ($record in $records | Where-Object { $_.Release -eq $release -and $_.Result -ne 'passed' }) {
        $record.Failures | ForEach-Object { "- $($record.Summary): $_" }
    }
    Submit-Issue "Umbraco $release fails the tests" (@(
            "The tests failed on Umbraco $release, so it stays out of ``UmbracoReleases``, and the package's dependency range"
            'keeps a site on it from restoring the package.'
            ''
            Format-Results @($release)
            ''
            $details
            ''
            "The artifacts of $link hold the logs. Close this issue once the cause is fixed; the next daily run of the"
            'New Umbraco releases workflow tests the release again, or run it now with this release.'
        ) -join "`n")
}

<#
.SYNOPSIS
Returns the text of the pull request that adds <releases>.
#>
function Format-PullRequest([string[]] $releases) {
    $one = $releases.Count -eq 1
    @(
        "The tests passed on Umbraco $($releases -join ', ') with and without the browser check, so this adds"
        "$($one ? 'it' : 'them') to ``UmbracoReleases``."
        ''
        Format-Results $releases
        ''
        "Merge it, then run the Release workflow to publish a package that lists $($one ? 'it' : 'them'). Until then, the"
        "package's dependency range keeps a site on $($one ? 'this release' : 'these releases') from restoring it. The"
        "artifacts of $link hold the logs."
    ) -join "`n"
}

if ($passed -and $DryRun) {
    Write-Host "Would add Umbraco $($passed -join ', ') unless listed already, push umbraco-releases/$($passed -join '-') and open the pull request ""Add Umbraco $($passed -join ', ')"":`n$(Format-PullRequest $passed)`n"
}
elseif ($passed) {
    Push-Location $repository
    try {
        # The tests ran with every tested release listed. Start again from the commit and add only those that passed.
        Invoke-Checked git @('checkout', '--', 'Directory.Build.props', 'README.md')
        $added = @(& (Join-Path $PSScriptRoot 'Add-UmbracoRelease.ps1') -Releases $passed)
        if ($added) {
            $names = $added -join ', '
            $branch = "umbraco-releases/$($added -join '-')"
            $body = Format-PullRequest $added
            Invoke-Checked git @('config', 'user.name', 'github-actions[bot]')
            Invoke-Checked git @('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
            Invoke-Checked git @('switch', '-c', $branch)
            Invoke-Checked git @('add', '--', 'Directory.Build.props', 'README.md')
            Invoke-Checked git @('commit', '-m', "Add Umbraco $names", '-m', "The tests passed on $names with and without the browser check.")
            Invoke-Checked git @('push', 'origin', $branch)
            $file = New-TemporaryFile
            Set-Content -LiteralPath $file -Value $body -Encoding utf8
            gh pr create --base main --head $branch --title "Add Umbraco $names" --body-file $file --label $label
            if ($LASTEXITCODE -ne 0) {
                $origin = (gh repo view --json url --jq .url)
                Submit-Issue "Umbraco $names passed the tests" (@(
                        "GitHub did not let the workflow open a pull request, so the change waits on the branch ``$branch``."
                        "[Open the pull request]($origin/compare/main...$($branch)?expand=1), or allow GitHub Actions to create"
                        'pull requests in the repository settings.'
                        ''
                        $body
                    ) -join "`n")
            }
            Remove-Item -LiteralPath $file
        }
        else {
            # A manual run can retest releases that are listed already, which leaves nothing to add.
            Write-Host "Umbraco $($passed -join ', ') is listed already, so there is nothing to add."
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host "Passed: $($passed -join ', ')"
Write-Host "Failed: $($failed -join ', ')"
exit ($failed ? 1 : 0)
