# Developing

This page covers building the package, running its tests and adding Umbraco releases.
The source is four files under `src`: the composer, the registration that edits the
service collection, and the two replacement services. The test project holds a
registration test, a live-site test and the fixture that hosts the site.

## Requirements

- The .NET 10 SDK and PowerShell 7. [`global.json`](../global.json) keeps every build on a
  .NET 10 SDK, also on a machine that has a newer one, and selects the Microsoft Testing
  Platform runner.
- Playwright Chromium for the [browser check](#browser-check).
- Pester 5 for the [workflow script tests](#workflow-scripts).

## Build

```powershell
dotnet build -c Release
```

The tests build against the Umbraco release in `UmbracoVersion` in
[`Directory.Build.props`](../Directory.Build.props), the newest supported release. Add
`-p:UmbracoVersion=17.0.0` to build against another supported release. The package itself
compiles against the oldest supported release, `UmbracoMinimumVersion`, and its NuGet
dependency range spans every supported release.

Both projects generate XML documentation, so the compiler checks every doc comment. Keep
the build free of warnings: the Release workflow builds with
`ContinuousIntegrationBuild`, which turns a warning into an error. NuGet's vulnerability
reports stay warnings there.

To build a package:

```powershell
dotnet pack src/AurorisNet.Umbraco.DisableTelemetry.csproj -c Release -o artifacts/packages
```

A local package is numbered `<UmbracoMaximumVersion>.0`, which NuGet writes as `18.3.1`.
Published versions count from 1, so NuGet's cache keeps local and published packages
apart. Add `artifacts/packages` as a NuGet source to try the package in a separate site.
The package contains the assembly, its XML documentation, the NuGet README and the MIT
licence. [Version numbering and releases](VERSIONING.md) covers publishing.

## Tests

```powershell
dotnet test --project tests/AurorisNet.Umbraco.DisableTelemetry.Tests -c Release
```

The test project has two classes:

- **`RegistrationTests`** runs the registration twice against a service collection built
  with Umbraco's own `AddRecurringBackgroundJob` extension. The collection holds duplicate
  telemetry job registrations, unrelated jobs, a factory registration that must never
  resolve during composition, and duplicate installer and news services. The test checks
  that only the telemetry job and the replaced services change.
- **`SiteTests`** composes a real site with SQLite and Kestrel through ordinary composer
  discovery. It checks that the telemetry job is absent and every other recurring job
  remains, that the telemetry service still produces a report with a valid site
  identifier, and that the replacement services complete reports on the server and return
  empty news feeds. It then creates 200 users beside the administrator, looks up every
  avatar, uploads an avatar, downloads its five sizes and removes it.

The fixture in `TestSite.cs` records every outgoing request. Its HTTP client factory
handler records and rejects requests, and its .NET HTTP event listener observes directly
constructed clients, including the static clients of early Umbraco releases. The listener
observes requests without blocking them, and the successful avatar downloads prove that
it is recording. The fixture checks the replacement registrations before the site boots,
so the original services cannot run during installation. It also sets
`Umbraco:CMS:Global:VersionCheckPeriod` to `0`, which keeps the separate Umbraco 17.0.x
update checker from contacting its endpoint; the package leaves that setting to the site.
A test fails on any telemetry, installer reporting, news or Gravatar attempt.

## Browser check

Install Chromium once, and again after upgrading Playwright. Then run the live-site test
with the browser check on:

```powershell
pwsh tests/AurorisNet.Umbraco.DisableTelemetry.Tests/bin/Release/net10.0/playwright.ps1 install chromium
pwsh tests/Test-UmbracoReleases.ps1 -Browser -Releases 17.0.0,17.8.1,18.0.0,18.3.1
```

`-Browser` sets `DISABLE_TELEMETRY_BROWSER` to `1` for the test processes. With it, the
live-site test signs in over HTTPS, checks the news dashboard's built-in fallback on the
first visit and after a reload, and opens the Users collection on the populated site. It
records and blocks external browser requests and fails on any telemetry, installer
reporting, news or Gravatar attempt. The check uses the machine's network settings as they
are. Each test stops its own server and browser and deletes its temporary site.

## Test other Umbraco releases

[`tests/Test-UmbracoReleases.ps1`](../tests/Test-UmbracoReleases.ps1) builds the tests
for each release you name, then runs each release's tests in its own process:

```powershell
pwsh tests/Test-UmbracoReleases.ps1 -Releases 17.0.0,18.3.1
pwsh tests/Test-UmbracoReleases.ps1 -Releases 17.0.0,18.3.1 -Browser
```

Without `-Releases`, it tests every release in `UmbracoReleases`. Builds run one at a
time, because Umbraco writes schemas into the project directory, and up to four test
processes run at once; `-Throttle 1` runs them one at a time. Each test process has a
four-minute timeout. The script writes each release's build and test logs under
`artifacts/umbraco-releases/<release>`, writes the summary to
`artifacts/umbraco-releases/results.json`, prints one line per release and exits with 1
when any release fails.

## Support a new Umbraco release

The package supports an Umbraco release once `UmbracoReleases` lists it and the tests pass
on it, with and without the browser check:

1. Run the tests on the release before listing it:

   ```powershell
   pwsh tests/Test-UmbracoReleases.ps1 -Releases 18.3.2
   pwsh tests/Test-UmbracoReleases.ps1 -Releases 18.3.2 -Browser
   ```

2. Check the Umbraco source for the extension points the package relies on. The
   registration matches `IRecurringBackgroundJob` registrations whose implementation type
   is `ReportSiteJob`, so a changed registration needs a review of the registration code.
   Installer reports must still go through `IInstallationService`, and the news dashboard
   must still read `INewsDashboardService` and show its fallback for an empty feed.
3. Add the release to `UmbracoReleases` in [`Directory.Build.props`](../Directory.Build.props).
   When it is the newest release, also set `UmbracoMaximumVersion` and `UmbracoVersion` to
   it, so the dependency range and the default test build include it.
4. Update the supported-versions table in `README.md` and the supported releases in
   `docs/NUGET.md`.

The same steps extend support to an older release.

## Workflow scripts

The Release workflow runs the scripts in `.github/scripts`: `Get-ReleaseVersion.ps1`
chooses the package versions and tags, and `Test-LatestRelease.ps1` decides whether a
GitHub release is marked as the latest. Test them with Pester 5:

```powershell
Invoke-Pester .github/scripts -CI
```

The tests work in disposable folders and Git repositories, so this repository and GitHub
stay untouched. The workflow pins each action to a commit, with its version in a comment
beside it. Pin the hash of a commit: a version tag can have a hash of its own, which stops
resolving once the tag moves to a later release.

## Documents

- `docs/NUGET.md` is the package's page on nuget.org, which shows Markdown without HTML or
  relative links. Keep its supported releases in step with the README table.
- `docs/VALIDATION.md` records a test run: its date, environment, results and limits.
  Update it after validating a changed set of releases.
