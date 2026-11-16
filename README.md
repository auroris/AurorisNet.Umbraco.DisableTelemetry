<h1 align="center">Umbraco Disable Telemetry</h1>

<p align="center">
  Offline reporting for Umbraco 17 and 18 sites.<br>
  Stop the telemetry beacon, installer reports and dashboard news requests on a server without internet access.
</p>

<p align="center">
  <a href="LICENSE"><img alt="MIT license" src="docs/images/badge-license.svg"></a>
  <img alt=".NET 10" src="docs/images/badge-dotnet-10.svg">
</p>

<p align="center">
  <a href="https://www.nuget.org/packages/AurorisNet.Umbraco.DisableTelemetry">NuGet package</a> ·
  <a href="#supported-versions">Supported versions</a> ·
  <a href="#version-numbering">Version numbering</a>
</p>

## What it does

`AurorisNet.Umbraco.DisableTelemetry` lets a standard Umbraco site run on a server
without internet access. It registers itself through Umbraco's composers, and installing
it is the whole setup.

- **The telemetry beacon stays off.** Umbraco's **Minimal** telemetry level still sends a
  site identifier. The package removes the scheduled job that sends it, along with the
  version and package reports of the higher levels.
- **Installer and upgrade reports complete locally.** Umbraco 17.0.x sends a report after
  installation and upgrade; the package completes it on the server.
- **The news dashboard opens at once.** It shows Umbraco's built-in resource links in
  place of the remote feed, so an offline server sees no feed timeouts or repeated error
  logs.
- **Other background jobs keep running.** Scheduled publishing, temp-file cleanup and the
  other recurring jobs keep their registrations.

The package changes service registrations through Umbraco's public extension points.
[Behavior and compatibility](docs/BEHAVIOR.md) describes each change, the features that
keep their network behavior and the tests.

## Supported versions

| Umbraco | Tested and supported releases | Package versions | Runtime |
|---|---|---|---|
| 18 | <!-- umbraco-releases 18 -->18.0.0 to 18.3.1<!-- /umbraco-releases --> | `18.*` | .NET 10 |
| 17 | <!-- umbraco-releases 17 -->17.0.0 to 17.8.1<!-- /umbraco-releases --> | `17.*` | .NET 10 |

[`UmbracoReleases`](Directory.Build.props) lists each tested release. NuGet's dependency
range spans the oldest and newest of these. Check this table to see whether your Umbraco
release is tested and supported.

## Quick start

Add the package to a website running a [supported Umbraco release](#supported-versions).
Reference your site's Umbraco major version, so NuGet installs the newest package for it:

```xml
<PackageReference Include="AurorisNet.Umbraco.DisableTelemetry" Version="18.*" />
```

On Umbraco 17, use `Version="17.*"`. A site with central package management needs
`CentralPackageFloatingVersionsEnabled` for a floating version, or an exact version such
as `18.3.1.1`. Restart the site. The backoffice news dashboard then shows Umbraco's
built-in links, and the telemetry job is absent from the scheduler. Removing the package
and restarting restores Umbraco's reporting and news feed.

## Version numbering

A package version is **`<newest supported Umbraco release>.<release count>`**. Version
`18.3.1.1` supports every Umbraco 18 release up to 18.3.1, and it is our first release
for 18.3.1.

| Package version | Supports | Release count |
|---|---|---|
| `18.3.1.1` | Every Umbraco 18 release up to 18.3.1 | Our first release for 18.3.1 |
| `17.8.1.1` | Every Umbraco 17 release up to 17.8.1 | Our first release for 17.8.1 |
| `18.3.2.1` | Every Umbraco 18 release up to 18.3.2 | Our first release for 18.3.2, after adding it |

Each release publishes one version for each supported Umbraco major version, built from
the same source: the release that publishes `18.3.1.1` also publishes `17.8.1.1`.
[Version numbering and releases](docs/VERSIONING.md) explains the counts and how a
release is published.

## Documentation

| Guide | Read it for |
|---|---|
| [Behavior and compatibility](docs/BEHAVIOR.md) | What the package changes, which features keep their network behavior, and test coverage. |
| [Developing](docs/DEVELOPING.md) | Building, testing and adding Umbraco releases. |
| [Version numbering and releases](docs/VERSIONING.md) | How versions are numbered and how a release is published. |
| [Validation](docs/VALIDATION.md) | The test run of 15 November 2026: environment, results and limits. |

## License

[MIT](LICENSE)
