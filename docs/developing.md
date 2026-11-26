# Developing

Requires the .NET 10 SDK (`global.json`) and PowerShell 7. On Windows, clone to a short path unless long paths are enabled (Playwright builds deep paths in the test matrix).

```powershell
dotnet build -c Release
dotnet test --project tests/AurorisNet.Umbraco.DisableTelemetry.Tests -c Release

# Full release matrix (runs locally, not on GitHub)
pwsh tests/Test-UmbracoReleases.ps1
pwsh tests/Test-UmbracoReleases.ps1 -Releases 17.0.0,18.3.2 -Browser

# Install Chromium once after build / Playwright updates
pwsh tests/AurorisNet.Umbraco.DisableTelemetry.Tests/bin/Release/net10.0/playwright.ps1 install chromium

# Add an Umbraco release manually (requires sibling ../AurorisNet.Build)
pwsh ../AurorisNet.Build/scripts/Add-UmbracoRelease.ps1 -Releases 18.3.2

# Local package (count 0)
dotnet pack src/AurorisNet.Umbraco.DisableTelemetry.csproj -c Release -o artifacts/packages
```

## What the package replaces

- Removes `ReportSiteJob` (telemetry reports).
- Replaces `IInstallationService` (completes installer/upgrade reports locally).
- Replaces `INewsDashboardService` (returns an empty feed so only built-in links render).

Other outbound requests (webhooks, email, etc.) are untouched.

## Add an Umbraco major version

When Umbraco ships a new major version:

1. Update the .NET SDK in `global.json`, workflows, and `Directory.Build.props` if required.
2. Add the first release to `UmbracoReleases` in `Directory.Build.props` and update `UmbracoMaximumVersion` and `UmbracoVersion`.
3. Add a matching `<!-- umbraco-releases <major> -->` line and badge update in `README.md`.
4. Run `pwsh tests/Test-UmbracoReleases.ps1 -Releases <version>` and `-Browser`.

## Releases

Versions follow `<newest supported Umbraco release>.<count>` (for example `18.3.2.1` and `17.8.2.1`). See the shared [release guide](https://github.com/auroris/AurorisNet.Build/blob/main/docs/releasing.md).
