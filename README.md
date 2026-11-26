# Disable Telemetry

Disables Umbraco's telemetry beacon, installer/upgrade reports, and backoffice news feed requests for Umbraco 17 and 18—useful for offline or air-gapped servers.

![MIT license](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/license-mit.svg)
![.NET 10](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/dotnet-10.svg)
![Umbraco 17 and 18](https://raw.githubusercontent.com/auroris/AurorisNet.Build/main/badges/umbraco-17-18.svg)

## Install

Add the package matching your Umbraco major version (`18.*` or `17.*`). It registers itself automatically via a composer—no code changes needed.

```xml
<PackageReference Include="AurorisNet.Umbraco.DisableTelemetry" Version="18.*" />
```

On Umbraco 17.0.x, also set `Umbraco:CMS:Global:VersionCheckPeriod` to `0` to stop update checks.

## Supported versions

- Umbraco 18: <!-- umbraco-releases 18 -->18.0.0 to 18.3.2<!-- /umbraco-releases --> (.NET 10)
- Umbraco 17: <!-- umbraco-releases 17 -->17.0.0 to 17.8.2<!-- /umbraco-releases --> (.NET 10)

## Links

- [Developing and releases](https://github.com/auroris/AurorisNet.Umbraco.DisableTelemetry/blob/main/docs/developing.md)
- [MIT License](https://github.com/auroris/AurorisNet.Umbraco.DisableTelemetry/blob/main/LICENSE)
