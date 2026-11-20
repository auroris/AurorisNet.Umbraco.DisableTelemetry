# Umbraco Disable Telemetry

`AurorisNet.Umbraco.DisableTelemetry` stops the telemetry, installer report and news feed
requests that an Umbraco 17 or 18 site sends to Umbraco, so the site can run on a server
without internet access.

![MIT license](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/license-mit.svg)
![.NET 10](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/dotnet-10.svg)
![Umbraco 17 and 18](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/umbraco-17-18.svg)

The package changes three service registrations:

- **Telemetry.** It removes the scheduled `ReportSiteJob`, so the site sends no telemetry
  report, whatever its telemetry level.
- **Installer and upgrade reports.** It replaces `IInstallationService` with a service that
  completes each report on the server. Umbraco 17.0.x otherwise sends the report to Umbraco.
- **News dashboard.** It replaces `INewsDashboardService` with a service that returns an
  empty feed, so the dashboard shows Umbraco's built-in links and requests no feed.

The telemetry level and site identifier keep their configured values. Every other outbound
request, such as a webhook or an email, works as before.

## Install

Reference the package with your site's Umbraco major version, so NuGet installs the newest
package for it:

```xml
<PackageReference Include="AurorisNet.Umbraco.DisableTelemetry" Version="18.*" />
```

On Umbraco 17, use `Version="17.*"`. With central package management, a floating version
needs `CentralPackageFloatingVersionsEnabled` set to `true`; otherwise give an exact package
version.

The package registers itself through an Umbraco composer, so the site needs no code. After
the site restarts, the scheduler runs no telemetry job and the news dashboard shows the
built-in links.

On Umbraco 17.0.x, also set `Umbraco:CMS:Global:VersionCheckPeriod` to `0`. Those releases
check Umbraco's servers for updates, and the setting stops that check.

## Supported versions

| Umbraco | Supported releases | Runtime |
|---|---|---|
| 18 | <!-- umbraco-releases 18 -->18.0.0 to 18.3.2<!-- /umbraco-releases --> | .NET 10 |
| 17 | <!-- umbraco-releases 17 -->17.0.0 to 17.8.2<!-- /umbraco-releases --> | .NET 10 |

Every release in these ranges is tested.
[`Directory.Build.props`](https://github.com/auroris/AurorisNet.Umbraco.DisableTelemetry/blob/main/Directory.Build.props)
lists them in `UmbracoReleases`, and the package's Umbraco dependency spans the oldest to the
newest. Upgrade the package when you upgrade Umbraco.

## Developing

Building needs the .NET 10 SDK, which `global.json` selects, and PowerShell 7 for the
scripts. On Windows, clone to a short path unless long paths are enabled: the test matrix
builds Playwright's files about 200 characters below the repository root.

```powershell
dotnet build -c Release
# The tests, on the newest supported Umbraco release
dotnet test --project tests/AurorisNet.Umbraco.DisableTelemetry.Tests -c Release
# The full matrix: the tests on every release in UmbracoReleases
pwsh tests/Test-UmbracoReleases.ps1
# Chosen releases, and the same with a browser check of the backoffice
pwsh tests/Test-UmbracoReleases.ps1 -Releases 17.0.0,18.3.2
pwsh tests/Test-UmbracoReleases.ps1 -Releases 17.0.0,18.3.2 -Browser
# Chromium for -Browser: install once after the build, and again after a Playwright update
pwsh tests/AurorisNet.Umbraco.DisableTelemetry.Tests/bin/Release/net10.0/playwright.ps1 install chromium
# Add an Umbraco release by hand, with AurorisNet.Build cloned beside this repository
pwsh ../AurorisNet.Build/scripts/Add-UmbracoRelease.ps1 -Releases 18.3.2
# A local package, numbered with count 0
dotnet pack src/AurorisNet.Umbraco.DisableTelemetry.csproj -c Release -o artifacts/packages
```

The tests run the registration against Umbraco's own service collection and start a site on
SQLite and Kestrel. They fail when the site attempts a telemetry, installer report or news
feed request. `-Browser` also signs in to the backoffice in Chromium and checks the news
dashboard.

`Test-UmbracoReleases.ps1` builds each release into `artifacts/umbraco-releases/<release>`,
prints one line per release and exits with 1 when a release fails. The full matrix runs on a
developer's machine. GitHub tests the newest supported release, and each new Umbraco release
when it appears.

`Add-UmbracoRelease.ps1` adds the release to `UmbracoReleases`, moves `UmbracoMaximumVersion`
and `UmbracoVersion` to the newest listed release, and rewrites the ranges in the
**Supported versions** table.

### Add an Umbraco major version

`Add-UmbracoRelease.ps1` and the weekly workflow accept releases of the listed major versions
only. When Umbraco publishes a new major version, the workflow opens an issue titled
`Support Umbraco <major>`, and a person adds it:

1. If it runs on a newer .NET, raise the SDK in `global.json`, add the SDK to the workflows'
   `setup-dotnet` steps, and add the target framework to `Directory.Build.props`.
2. Add its first release to `UmbracoReleases` in `Directory.Build.props`, and set
   `UmbracoMaximumVersion` and `UmbracoVersion` to it.
3. Add a row to the **Supported versions** table with `umbraco-releases 19` markers like
   those in the rows above, and add the major version to the text and badge that name the
   supported versions.
4. Test the release with `pwsh tests/Test-UmbracoReleases.ps1 -Releases 19.0.0`, then again
   with `-Browser`.

## Releases

The package follows Umbraco. Each week `umbraco-releases.yml` looks on nuget.org for new
Umbraco releases and tests the package on each. A release that passes is added to
`UmbracoReleases` and to the **Supported versions** table, and `weekly-release.yml` then starts
`release.yml`, which publishes the package to nuget.org and GitHub. A release that fails gets an issue.

A package version is `<newest supported Umbraco release>.<count>`, such as `18.3.2.1`. Each
release publishes one package for each supported major version, such as `18.3.2.1` and
`17.8.2.1`, so a site can float on `18.*` or `17.*`. The count starts at 1 for each Umbraco
release.

The [release guide](https://github.com/auroris/AurorisNet.Build/blob/main/docs/releasing.md)
describes the workflows and how to start a release by hand.

## License

[MIT](https://github.com/auroris/AurorisNet.Umbraco.DisableTelemetry/blob/main/LICENSE)
