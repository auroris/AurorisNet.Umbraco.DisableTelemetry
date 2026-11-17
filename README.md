# Umbraco Disable Telemetry

![MIT license](https://raw.githubusercontent.com/auroris/UmbracoDisableTelemetry/main/docs/images/badge-license.svg)
![.NET 10](https://raw.githubusercontent.com/auroris/UmbracoDisableTelemetry/main/docs/images/badge-dotnet-10.svg)

`AurorisNet.Umbraco.DisableTelemetry` lets a standard Umbraco 17 or 18 site run on a server
without internet access. It registers itself through an Umbraco composer and changes three
service registrations:

- **Telemetry:** removes the scheduled `ReportSiteJob`, so the site sends no telemetry
  report at any level, including the site identifier that the **Minimal** level sends.
- **Installer and upgrade reports:** replaces `IInstallationService` with a service that
  completes each report on the server. Umbraco 17.0.x otherwise sends it to Umbraco.
- **News dashboard:** replaces `INewsDashboardService` with a service that returns an empty
  feed, so the dashboard shows Umbraco's built-in resource links at once, with no feed
  timeout or error log.

The telemetry level and site identifier keep their configured values. Requests that a user
or the site's configuration starts keep their normal behavior: the Marketplace, media
embeds, the newsletter opt-in, webhooks and email. On Umbraco 17.0.x, set
`Umbraco:CMS:Global:VersionCheckPeriod` to `0` to stop the backoffice update check as well.

## Install

Reference the package with your site's Umbraco major version, so NuGet installs the newest
package for it:

```xml
<PackageReference Include="AurorisNet.Umbraco.DisableTelemetry" Version="18.*" />
```

On Umbraco 17, use `Version="17.*"`. With central package management, put the version on
the `PackageVersion` item and set `CentralPackageFloatingVersionsEnabled` to `true`, or use
an exact version such as `18.3.1.1`.

Restart the site. The news dashboard then shows the built-in links, and the scheduler runs
no telemetry job. Removing the package and restarting restores Umbraco's reporting and
news feed.

## Supported versions

| Umbraco | Tested and supported releases | Package versions | Runtime |
|---|---|---|---|
| 18 | <!-- umbraco-releases 18 -->18.0.0 to 18.3.2<!-- /umbraco-releases --> | `18.*` | .NET 10 |
| 17 | <!-- umbraco-releases 17 -->17.0.0 to 17.8.2<!-- /umbraco-releases --> | `17.*` | .NET 10 |

`UmbracoReleases` in
[`Directory.Build.props`](https://github.com/auroris/UmbracoDisableTelemetry/blob/main/Directory.Build.props)
lists each tested release, and the package's Umbraco dependency spans the oldest to the
newest of them. Upgrade the package when you upgrade Umbraco.

## Version numbering

A package version is `<newest supported Umbraco release>.<release count>`:

- `18.3.1.1` is the first package for Umbraco 18.3.1 and supports every Umbraco 18 release
  up to 18.3.1.
- Each release publishes one package per supported major version, built from the same
  source, such as `18.3.1.1` and `17.8.1.1`.
- The count starts at 1 for each Umbraco release, and each major version counts on its own.
  After Umbraco 18.3.2 is added, the next release publishes `18.3.2.1` and `17.8.1.2`.

Local builds use count 0, which is never published.

## Developing

Requires the .NET 10 SDK and PowerShell 7. On Windows, clone to a short path: the build
fails with `MSB3021` when a path exceeds 260 characters.

```powershell
dotnet build -c Release
dotnet test --project tests/AurorisNet.Umbraco.DisableTelemetry.Tests -c Release
dotnet pack src/AurorisNet.Umbraco.DisableTelemetry.csproj -c Release -o artifacts/packages
Invoke-Pester .github/scripts -CI   # the workflow scripts' tests, with Pester 5.7.1
```

The tests run the registration against Umbraco's own service collection and compose a
site with SQLite and Kestrel. They fail on any telemetry, installer report or news request.

### Add an Umbraco release

The **New Umbraco releases** workflow checks NuGet each day for stable releases of the
supported major versions and tests them. It opens a pull request that lists the releases
that pass, and an issue for each release that fails. Merge the pull request, then publish
with **Actions → Release → Run workflow** on `main`.

To add a release by hand, list it, then test it with and without the browser check:

```powershell
pwsh .github/scripts/Add-UmbracoRelease.ps1 -Releases 18.3.2
pwsh tests/Test-UmbracoReleases.ps1 -Releases 18.3.2
pwsh tests/Test-UmbracoReleases.ps1 -Releases 18.3.2 -Browser
```

`Add-UmbracoRelease.ps1` updates `Directory.Build.props` and the supported-versions table.
`-Browser` needs Playwright Chromium, installed once after `dotnet build -c Release`:

```powershell
pwsh tests/AurorisNet.Umbraco.DisableTelemetry.Tests/bin/Release/net10.0/playwright.ps1 install chromium
```

A new Umbraco major version starts by hand:

1. If it targets a newer .NET, raise `global.json` to that SDK, add the SDK to the
   workflows' `setup-dotnet` steps, and add the framework to the package project.
2. Add its first release to `UmbracoReleases`, and add a row to the supported-versions
   table with `umbraco-releases 19` markers like those in the rows above.
3. Test that release as shown above.

## License

[MIT](https://github.com/auroris/UmbracoDisableTelemetry/blob/main/LICENSE)
