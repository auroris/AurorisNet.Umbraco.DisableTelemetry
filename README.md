# Umbraco Disable Telemetry

`AurorisNet.Umbraco.DisableTelemetry` stops Umbraco's telemetry beacon, installer
reporting and dashboard news requests on servers without internet access. Installing
the package activates it automatically through Umbraco's composers.

Umbraco's **Minimal** telemetry level still sends a site identifier. This package
stops that request, including the version and package reports sent at higher levels.
It also suppresses the separate installation and upgrade reports in Umbraco 17.0.x.
The news dashboard displays Umbraco's built-in fallback immediately, avoiding remote
feed timeouts and repeated error logs. Other background jobs continue to run.

## Install

Add the package version matching your site's Umbraco major version:

```xml
<PackageReference Include="AurorisNet.Umbraco.DisableTelemetry" Version="18.*" />
```

Use `17.*` for Umbraco 17. With central package management, choose an exact version
or enable `CentralPackageFloatingVersionsEnabled`. Restart the site after installation.
The package needs no configuration or database changes. Removing it and restarting
restores Umbraco's normal reporting and news behavior.

## Supported versions

| Umbraco | Supported releases | Package versions | Runtime |
|---|---|---|---|
| 18 | 18.0.0 to 18.3.1 | `18.*` | .NET 10 |
| 17 | 17.0.0 to 17.8.1 | `17.*` | .NET 10 |

The repository's `Directory.Build.props` lists each supported release. Compatibility
tests start a real site for each release and check reporting, the dashboard and user avatars.

## How it works

The composer registers a collection builder that runs when `IUmbracoBuilder.Build()`
finalizes dependency injection, after all composers. It:

- Removes the built-in `IRecurringBackgroundJob` registrations implemented by `ReportSiteJob`.
- Replaces `IInstallationService` registrations with a service that completes reports locally.
- Replaces `INewsDashboardService` registrations with a service that returns an empty feed.

An empty feed makes the standard news dashboard display its built-in resource links.
Those links connect externally only when clicked. Umbraco 17.1 and later already make
installer reporting a no-op; the replacement also covers the older 17.0.x sender.

The package uses Umbraco's public extension points. It does not patch methods at runtime,
intercept HTTP traffic, or change the site's telemetry consent or identifier. If another
component has already removed the job, it leaves that state in place. Custom code that
bypasses the replaced services or manually runs a reporting job remains responsible for
its own behavior.

### Gravatar and offline hosting

Umbraco 17 and 18 already return uploaded avatars or an empty avatar list. The old
Gravatar network lookup is gone, so user management needs no Gravatar patch. Uploaded
avatars continue to work.

Other internet-dependent features retain their normal behavior: the Marketplace iframe,
external media embeds, newsletter opt-in, configured webhooks and email. Umbraco 17.0.x
also has update checks; set `Umbraco:CMS:Global:VersionCheckPeriod` to `0` to disable their
normal backoffice trigger. Umbraco 17.1 and later make the update-check sender a no-op.

### Replacing an existing telemetry composer

Remove an existing composer that disables the same job when adopting this package.
In particular, UmbracoAppHost's original `Overrides/DisableTelemetryComposer` expects
to find the job and throws when it cannot. Use the package as the single owner of this
behavior.

## Version numbering

Versions follow `<newest supported Umbraco release>.<release count>`. The first release
is numbered `18.3.1.1` and `17.8.1.1`; both packages contain the same implementation and
support the full table above. Local builds use count `0`, which is never published.

See [Developing](https://github.com/auroris/UmbracoDisableTelemetry/blob/main/docs/DEVELOPING.md)
for validation commands and
[Version numbering and releases](https://github.com/auroris/UmbracoDisableTelemetry/blob/main/docs/VERSIONING.md)
for the manual release workflow and NuGet trusted publishing setup.

## License

MIT. Copyright 2026 Auroris.
