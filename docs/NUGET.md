# Umbraco Disable Telemetry

Disables reporting for Umbraco 17 and 18 sites. The package stops the telemetry beacon,
installer reports and dashboard news requests on a server without internet access.

## What it does

- **The telemetry beacon stays off.** Umbraco's **Minimal** telemetry level still sends a
  site identifier. The package removes the scheduled job that sends it, along with the
  version and package reports of the higher levels.
- **Installer and upgrade reports complete locally.** Umbraco 17.0.x sends a report after
  installation and upgrade; the package completes it on the server.
- **The news dashboard opens at once.** It shows Umbraco's built-in resource links in
  place of the remote feed, so an offline server sees no feed timeouts or repeated error
  logs.

The package changes service registrations through Umbraco's public extension points, and
installing it is the whole setup.

## Quick start

Add the package to a website running Umbraco 18.0.0 to 18.3.1 or 17.0.0 to 17.8.1.
Reference your site's Umbraco major version, so NuGet installs the newest package for it:

```xml
<PackageReference Include="AurorisNet.Umbraco.DisableTelemetry" Version="18.*" />
```

On Umbraco 17, use `Version="17.*"`. A site with central package management needs
`CentralPackageFloatingVersionsEnabled` for a floating version, or an exact version such
as `18.3.1.1`. Restart the site. The backoffice news dashboard then shows Umbraco's
built-in links, and the telemetry job is absent from the scheduler. Removing the package
and restarting restores Umbraco's reporting and news feed.

## Versions

A package version is the newest Umbraco release it supports, followed by our release
count: 18.3.1.1 supports every Umbraco 18 release up to 18.3.1, and 17.8.1.1 supports
every Umbraco 17 release up to 17.8.1. NuGet's dependency range spans the oldest and
newest supported releases. Check the
[supported versions](https://github.com/auroris/UmbracoDisableTelemetry#supported-versions)
to see whether your Umbraco release is tested and supported, and upgrade the package when
you upgrade Umbraco.

## Documentation

- [Behavior and compatibility](https://github.com/auroris/UmbracoDisableTelemetry/blob/main/docs/BEHAVIOR.md)
- [Version numbering and releases](https://github.com/auroris/UmbracoDisableTelemetry/blob/main/docs/VERSIONING.md)
- [Issue tracker](https://github.com/auroris/UmbracoDisableTelemetry/issues)

Licensed under the [MIT license](https://github.com/auroris/UmbracoDisableTelemetry/blob/main/LICENSE).
