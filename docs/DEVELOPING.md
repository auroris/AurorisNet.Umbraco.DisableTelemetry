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
- On Windows, a short clone path. Playwright's package nests deeply, and the build fails
  with `MSB3021` when a path exceeds 260 characters unless long paths are enabled. The
  same limit applies to `-ArtifactsPath` in `Test-UmbracoReleases.ps1`.

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
`artifacts/umbraco-releases/<release>`, prints one line per release and exits with 1
when any release fails. It also writes a JSON summary with each release's result, test
counts and failed tests to `artifacts/umbraco-releases/results.json`, or to the file
`-SummaryPath` names. The New Umbraco releases workflow reads that summary.

## Support a new Umbraco release

The package supports an Umbraco release once `UmbracoReleases` lists it and the tests pass
on it, with and without the browser check.

### New Umbraco releases workflow

The **New Umbraco releases** workflow looks on NuGet every day for stable releases of the
supported major versions that are newer than the newest listed one, and runs the tests on
them with and without the browser check:

- Releases that pass are listed on a branch named `umbraco-releases/<releases>`, with a
  pull request. Merge it, then [publish a release](VERSIONING.md#publish-a-release).
  While the branch exists, later runs skip its releases, and GitHub deletes it when the
  pull request merges. To test a release again after closing its pull request unmerged,
  delete the branch.
- A release that fails gets an issue titled `Umbraco <release> fails the tests`, which
  links the run. The run's artifacts hold the build and test logs. Fix the cause as
  [Add a release by hand](#add-a-release-by-hand) describes. Closing the issue lets the
  next run test the release again.
- A stable release of a newer major version gets an issue titled
  `Support Umbraco <major>`, for the steps in
  [Support a new Umbraco major version](#support-a-new-umbraco-major-version).

The workflow opens pull requests once **Settings → Actions → General → Workflow
permissions → Allow GitHub Actions to create and approve pull requests** is on. Until
then, it pushes the branch and opens an issue that links it. To test chosen releases, or
to see the results without opening anything, run it from **Actions → New Umbraco
releases → Run workflow** with its `releases` and `dry-run` inputs.

The workflow keeps the tests apart from the reporting. Its test job builds and runs
releases that NuGet has only just published, so that job can only read the repository
and holds no token. A separate job reads the two summaries the tests wrote, then opens
the pull request and the issues. GitHub disables a scheduled workflow after 60 days
without activity in the repository, so each scheduled run also enables the workflow
again, which restarts that count.

### Add a release by hand

1. List the release:

   ```powershell
   pwsh .github/scripts/Add-UmbracoRelease.ps1 -Releases 18.3.2
   ```

   The script adds it to `UmbracoReleases`. When it is the newest release, the script
   also sets `UmbracoMaximumVersion` and `UmbracoVersion` to it, so the dependency range
   and the default test build include it. Then it updates the supported releases in
   `README.md` and `docs/NUGET.md`.
2. Run the tests on it, with and without the browser check:

   ```powershell
   pwsh tests/Test-UmbracoReleases.ps1 -Releases 18.3.2
   pwsh tests/Test-UmbracoReleases.ps1 -Releases 18.3.2 -Browser
   ```

3. When a test fails, check the Umbraco source for the extension points the package relies
   on. The registration matches `IRecurringBackgroundJob` registrations whose
   implementation type is `ReportSiteJob`, so a changed registration needs a review of the
   registration code. Installer reports must still go through `IInstallationService`, and
   the news dashboard must still read `INewsDashboardService` and show its fallback for an
   empty feed. Fix the package, then run the tests again.

The same steps extend support to an older release.

## Support a new Umbraco major version

The add script accepts only the major versions already listed, so a new major version
starts by hand:

1. Check the new major version's target framework. When it runs on a newer .NET, install
   that SDK, add it to the workflows' `setup-dotnet` steps, raise the SDK version in
   `global.json` to match, and target both frameworks in the package project.
2. List the first release of the major version in `UmbracoReleases` by hand. Add a row to
   the README's supported-versions table with an `<!-- umbraco-releases 19 -->` marker,
   and add the release to the supported releases in `docs/NUGET.md`. Update the other
   text that names the supported major versions, including the repository's description
   on GitHub.
3. Continue from step 2 of [Add a release by hand](#add-a-release-by-hand).

## Workflow scripts

The workflows run the scripts in `.github/scripts`:

| Script | Used by | Does |
|---|---|---|
| `Find-UmbracoReleases.ps1` | New Umbraco releases | Compares `UmbracoReleases` with the Umbraco.Cms versions on NuGet and returns the new releases and any newer major version. |
| `Add-UmbracoRelease.ps1` | New Umbraco releases, and by hand | Lists releases in `Directory.Build.props`, `README.md` and `docs/NUGET.md`. |
| `Submit-UmbracoReleaseResults.ps1` | New Umbraco releases | Reads the test summaries, then opens the pull request and the issues. |
| `Get-ReleaseVersion.ps1` | Release | Chooses each package version's count from the release tags. |
| `Test-LatestRelease.ps1` | Release | Decides whether a GitHub release is marked as the latest. |

Test them with Pester 5.7.1:

```powershell
Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -SkipPublisherCheck
Import-Module Pester -RequiredVersion 5.7.1
Invoke-Pester .github/scripts -CI
```

The tests work in disposable folders and Git repositories, so this repository and GitHub
stay untouched.

The workflows pin each action to a commit, with its version in a comment beside it.
Dependabot opens a pull request when an action publishes a newer release. Pin the hash
of a commit: a version tag can have a hash of its own, which stops resolving once the
tag moves to a later release.

## Documents

- `docs/NUGET.md` is the package's page on nuget.org, which shows Markdown without HTML or
  relative links. `Add-UmbracoRelease.ps1` rewrites its list of supported releases after
  "running Umbraco".
- The README's supported-versions table marks each major version's releases with
  `umbraco-releases` comments, which `Add-UmbracoRelease.ps1` rewrites.
