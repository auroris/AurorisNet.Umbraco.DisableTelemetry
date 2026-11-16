#Requires -Version 7.0
<#
.SYNOPSIS
Builds and tests every supported Umbraco release in isolated processes.
.DESCRIPTION
Builds sequentially because Umbraco writes schemas into the project directory. Each test run uses a separate
process and temporary site. Results and logs are kept under artifacts/umbraco-releases.
.PARAMETER Releases
Releases to test, separated by commas. Defaults to UmbracoReleases in Directory.Build.props.
.PARAMETER Browser
Also checks backoffice login, the news dashboard fallback and the Users section in Chromium. Install Playwright Chromium first.
.PARAMETER Throttle
Maximum simultaneous test processes. Builds always run one at a time.
#>
param([string[]] $Releases, [switch] $Browser, [int] $Throttle = 4)

$ErrorActionPreference = 'Stop'
if ($Throttle -lt 1) { throw 'Throttle must be at least one.' }
$repository = Split-Path $PSScriptRoot -Parent
$project = Join-Path $PSScriptRoot 'AurorisNet.Umbraco.DisableTelemetry.Tests'
$artifacts = Join-Path $repository 'artifacts/umbraco-releases'
if ($Releases) { $Releases = @($Releases | ForEach-Object { $_.Split(',', [StringSplitOptions]::RemoveEmptyEntries -bor [StringSplitOptions]::TrimEntries) }) }
else {
    [xml] $settings = Get-Content -LiteralPath (Join-Path $repository 'Directory.Build.props')
    $Releases = $settings.SelectSingleNode('/Project/PropertyGroup/UmbracoReleases').InnerText.Split(';')
}
foreach ($release in $Releases) {
    if ($release -notmatch '^\d+\.\d+\.\d+$') { throw "Invalid release: $release" }
}
$results = [Collections.Generic.List[object]]::new()
$jobs = [Collections.Generic.List[object]]::new()
try {
    foreach ($release in $Releases) {
        $folder = Join-Path $artifacts $release
        New-Item -ItemType Directory -Force $folder | Out-Null
        Write-Host "Building Umbraco $release"
        dotnet build $project -c Release --disable-build-servers --artifacts-path "$folder/build" "-p:UmbracoVersion=$release" -nologo *> "$folder/build.log"
        if ($LASTEXITCODE -ne 0) {
            $results.Add([pscustomobject]@{ Release = $release; Result = 'build failed'; Log = "$folder/build.log" })
            continue
        }
        while (@($jobs | Where-Object State -eq Running).Count -ge $Throttle) {
            $jobs | Where-Object State -eq Running | Wait-Job -Any | Out-Null
        }
        Write-Host "Testing Umbraco $release"
        $jobs.Add((Start-Job -ScriptBlock {
            param($release, $folder, $browser)
            $env:DISABLE_TELEMETRY_BROWSER = $browser ? '1' : '0'
            $env:ASPNETCORE_ENVIRONMENT = 'Development'
            $assembly = "$folder/build/bin/AurorisNet.Umbraco.DisableTelemetry.Tests/release/AurorisNet.Umbraco.DisableTelemetry.Tests.dll"
            dotnet $assembly --timeout 4m --show-live-output on *> "$folder/test.log"
            [pscustomobject]@{ Release = $release; Result = $LASTEXITCODE -eq 0 ? 'passed' : 'failed'; Log = "$folder/test.log" }
        } -ArgumentList $release, $folder, $Browser.IsPresent))
    }
    if ($jobs.Count) {
        $jobs | Receive-Job -Wait | ForEach-Object { $results.Add($_) }
    }
} finally {
    # Only stop and remove the jobs created by this invocation.
    if ($jobs.Count) { $jobs | Stop-Job; $jobs | Remove-Job -Force }
}
$results = @($results | Sort-Object { [version] $_.Release })
$results | Format-Table Release, Result, Log -AutoSize | Out-String -Width 220 | Write-Host
$results | Select-Object Release,Result,Log | ConvertTo-Json -AsArray | Set-Content "$artifacts/results.json"
exit (@($results | Where-Object Result -ne passed).Count -eq 0 ? 0 : 1)
