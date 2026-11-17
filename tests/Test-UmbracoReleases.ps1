#Requires -Version 7.0
<#
.SYNOPSIS
Builds the package and runs its tests against each supported Umbraco release.

.DESCRIPTION
Reads the supported releases from UmbracoReleases in Directory.Build.props, unless -Releases names others. Builds the
test project once for each release, one at a time, into <ArtifactsPath>/<release>/build, then runs each release's
tests in a process of its own, several at once. Builds run one at a time because Umbraco's build targets write
appsettings-schema.json into the project folder. Each test process uses a temporary site and has a four-minute timeout.
Prints one line per release, writes a JSON summary and exits with 1 when any release fails.

.PARAMETER Releases
The Umbraco releases to test, such as 18.3.1. Defaults to every release in UmbracoReleases.

.PARAMETER Browser
Also signs in to the backoffice in Chromium, checks the news dashboard's fallback and opens the Users collection.
Install Chromium once after dotnet build -c Release, and again after upgrading Playwright:
    pwsh tests/AurorisNet.Umbraco.DisableTelemetry.Tests/bin/Release/net10.0/playwright.ps1 install chromium

.PARAMETER Configuration
The build configuration. Defaults to Release.

.PARAMETER ArtifactsPath
Where the builds, logs and summary go. Defaults to artifacts/umbraco-releases in the repository.

.PARAMETER Throttle
How many test processes run at once. Defaults to 4. Builds always run one at a time.

.PARAMETER SummaryPath
The JSON summary to write: one object per release with Release, Result, Tests and Failures, where Failures lists each
failed test. Defaults to results.json in ArtifactsPath. The New Umbraco releases workflow reads it.
#>
param(
    [string[]] $Releases,
    [switch] $Browser,
    [string] $Configuration = 'Release',
    [string] $ArtifactsPath,
    [int] $Throttle = 4,
    [string] $SummaryPath
)

$ErrorActionPreference = 'Stop'
if ($Throttle -lt 1) { throw 'Throttle must be at least one.' }
$split = [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries
$repository = Split-Path $PSScriptRoot -Parent
$project = Join-Path $PSScriptRoot 'AurorisNet.Umbraco.DisableTelemetry.Tests'
if (-not $ArtifactsPath) { $ArtifactsPath = Join-Path $repository 'artifacts/umbraco-releases' }
if (-not $SummaryPath) { $SummaryPath = Join-Path $ArtifactsPath 'results.json' }
# pwsh -File passes "17.0.0,18.3.1" as one string, so split each value on commas too.
if ($Releases) { $Releases = @($Releases | ForEach-Object { $_.Split(',', $split) }) }
if (-not $Releases) {
    [xml] $settings = Get-Content -LiteralPath (Join-Path $repository 'Directory.Build.props')
    # The file can have several property groups, so find the property by its path rather than through one group.
    $Releases = ([string] $settings.SelectSingleNode('/Project/PropertyGroup/UmbracoReleases').InnerText).Split(';', $split)
}
foreach ($release in $Releases) {
    if ($release -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid release: $release" }
}

# Runs one release's tests in its own process, so Umbraco's process-wide state stays apart between releases.
$test = {
    param($release, $folder, $configuration, $browser)
    $env:DISABLE_TELEMETRY_BROWSER = $browser ? '1' : '0'
    $env:ASPNETCORE_ENVIRONMENT = 'Development'
    $assembly = Join-Path $folder "build/bin/AurorisNet.Umbraco.DisableTelemetry.Tests/$($configuration.ToLowerInvariant())/AurorisNet.Umbraco.DisableTelemetry.Tests.dll"
    $log = Join-Path $folder 'test.log'
    dotnet $assembly --timeout 4m --show-live-output on *> $log
    $exitCode = $LASTEXITCODE
    $lines = Get-Content $log
    $counts = @($lines | Select-String -Pattern '^\s+(total|failed|succeeded|skipped): (\d+)')
    $failed = @($lines | Select-String -Pattern '^failed (.+?)( \(\d.*\))?$' | ForEach-Object { $_.Matches[0].Groups[1].Value })
    $ran = @($counts | Where-Object { $_.Matches[0].Groups[1].Value -eq 'succeeded' -and $_.Matches[0].Groups[2].Value -ne '0' }).Count -gt 0
    if ($exitCode -eq 0 -and -not $ran) { $failed += 'No test ran.' }
    [pscustomobject]@{
        Release = $release
        Result = $exitCode -eq 0 -and $ran ? 'passed' : 'failed'
        Tests = ($counts | ForEach-Object { $_.Line.Trim() }) -join ', '
        Log = $log
        Failures = $failed
    }
}

$results = [Collections.Generic.List[object]]::new()
$jobs = [Collections.Generic.List[object]]::new()
try {
    foreach ($release in $Releases) {
        $folder = Join-Path $ArtifactsPath $release
        New-Item -ItemType Directory -Force $folder | Out-Null
        $log = Join-Path $folder 'build.log'
        Write-Host "Building Umbraco $release"
        dotnet build $project -c $Configuration --disable-build-servers --artifacts-path (Join-Path $folder 'build') "-p:UmbracoVersion=$release" -nologo *> $log
        if ($LASTEXITCODE -ne 0) {
            $results.Add([pscustomobject]@{ Release = $release; Result = 'build failed'; Tests = ''; Log = $log; Failures = @('The build failed.') })
            continue
        }
        while (@($jobs | Where-Object State -eq Running).Count -ge $Throttle) {
            $jobs | Where-Object State -eq Running | Wait-Job -Any | Out-Null
        }
        Write-Host "Testing Umbraco $release"
        $jobs.Add((Start-Job -ScriptBlock $test -ArgumentList $release, $folder, $Configuration, $Browser.IsPresent))
    }
    if ($jobs.Count) { $jobs | Receive-Job -Wait | ForEach-Object { $results.Add($_) } }
} finally {
    # Only stop and remove the jobs created by this invocation.
    if ($jobs.Count) { $jobs | Stop-Job; $jobs | Remove-Job -Force }
}

$results = @($results | Sort-Object { [version] $_.Release })
$results | Format-Table Release, Result, Tests, Log -AutoSize | Out-String -Width 250 | Write-Host
foreach ($outcome in $results | Where-Object Result -ne 'passed') {
    Write-Host "Umbraco $($outcome.Release) $($outcome.Result): $($outcome.Log)"
    $outcome.Failures | ForEach-Object { Write-Host "  $_" }
}
$records = foreach ($outcome in $results) {
    [pscustomobject]@{ Release = $outcome.Release; Result = $outcome.Result; Tests = $outcome.Tests; Failures = @($outcome.Failures) }
}
New-Item -ItemType Directory -Force (Split-Path -Parent ([IO.Path]::GetFullPath($SummaryPath))) | Out-Null
ConvertTo-Json -InputObject @($records) -Depth 4 | Set-Content -LiteralPath $SummaryPath -Encoding utf8
exit (@($results | Where-Object Result -ne 'passed').Count -eq 0 ? 0 : 1)
