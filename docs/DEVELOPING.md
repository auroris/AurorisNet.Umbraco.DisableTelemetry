# Build and validate

Use the .NET 10 SDK and PowerShell 7. `global.json` selects the SDK and the Microsoft
Testing Platform runner.

```powershell
dotnet build -c Release
dotnet test --project tests/AurorisNet.Umbraco.DisableTelemetry.Tests -c Release
```

The default test release is 18.3.1. To test another release, pass
`-p:UmbracoVersion=17.0.0` to the build or test command. The package always compiles
against the oldest supported release; only the test host's Umbraco version changes.

## Compatibility matrix

```powershell
./tests/Test-UmbracoReleases.ps1
```

The script builds every release in `UmbracoReleases`, then runs each test host in its
own process. Builds run sequentially because Umbraco writes schemas into the project
directory. Up to four test processes run at once. Use `-Releases 17.0.0,18.3.1` to select
releases, or `-Throttle 1` to run one test process at a time. Logs and a JSON summary are
written under `artifacts/umbraco-releases`. Each test process has a four-minute timeout.

The tests check:

- Removal of duplicate telemetry job registrations and replacement of installer reporting and
  news services, with unrelated registrations preserved and repeated composition supported.
- Automatic composer discovery through ordinary Umbraco startup, using SQLite and Kestrel.
- Absence of the telemetry job and preservation of every other recurring job registration.
- Availability of a telemetry report with a valid site identifier, confirming that job removal
  is responsible for suppressing the beacon.
- Local completion of installation and upgrade reports and empty results on repeated news requests.
- A population of 200 users plus the administrator, avatar lookup for every user, upload and
  download of all five avatar sizes, and avatar removal.
- Absence of telemetry, installer reporting, news and Gravatar requests. The HTTP client factory
  handler records and rejects requests, and a .NET HTTP event listener also observes directly
  constructed clients. Avatar downloads verify that the latter recorder is active. The listener
  observes requests; it does not block them. Replacement registrations are checked before boot.

The fixture sets `VersionCheckPeriod` to `0` so Umbraco 17.0.x's separate update checker
does not contact its real endpoint during browser tests. The package leaves that setting
under the site's control.

## Browser checks

After building, install Chromium and run the browser cases:

```powershell
pwsh tests/AurorisNet.Umbraco.DisableTelemetry.Tests/bin/Release/net10.0/playwright.ps1 install chromium
./tests/Test-UmbracoReleases.ps1 -Browser -Releases 17.0.0,17.8.1,18.0.0,18.3.1
```

The browser check signs in over HTTPS, verifies the news dashboard's built-in fallback,
reloads it and opens the Users collection on the populated site. It records and blocks
external browser requests and fails on telemetry, installer reporting, news or Gravatar
attempts. These checks require no changes to the machine's network settings. Each test
stops its own server and browser and deletes its temporary site.

## Release scripts and local packages

With Pester 5 installed:

```powershell
Invoke-Pester .github/scripts -CI
dotnet pack src/AurorisNet.Umbraco.DisableTelemetry.csproj -c Release -o artifacts/packages
```

Local packages use version `18.3.1.0`, which NuGet normalizes to `18.3.1` in filenames and
package metadata. Add `artifacts/packages` as a NuGet source to try one
in a separate site. The package contains the assembly, XML documentation, README and
MIT licence. Test and browser dependencies are confined to the test project.

## Adding an Umbraco release

Run the tests against the new release before adding it to `UmbracoReleases` or widening
the NuGet dependency range. Check that Umbraco still registers `ReportSiteJob` as an
`IRecurringBackgroundJob` with an implementation type. This package deliberately removes
that built-in registration; a changed registration needs an implementation review.
Check that installer reports still use `IInstallationService` and that the dashboard
still uses `INewsDashboardService` and displays its fallback for an empty feed.

Update the supported-version table and maximum version after validation. The same rule
applies when extending support to older releases.
