# Behavior and compatibility

The package removes Umbraco's scheduled telemetry sender and replaces installer reporting
and dashboard news with services that answer on the server. It registers through
`.AddComposers()`: the composer adds a collection builder that runs when
`IUmbracoBuilder.Build()` finalizes dependency injection, after every composer has
registered its services.

## What it changes

| Umbraco behavior | With the package |
|---|---|
| `ReportSiteJob` sends a telemetry report to Umbraco on a schedule. The **Minimal** level sends the site identifier, and the higher levels add the Umbraco version and installed packages. | The job's `IRecurringBackgroundJob` registration is removed, so the scheduler never runs it. The telemetry service, the consent level and the site identifier stay as configured. |
| Umbraco 17.0.x sends an installation or upgrade report through `IInstallationService`. Umbraco 17.1 and later complete the report locally. | `IInstallationService` resolves to a service that completes every report on the server, on every supported release. |
| The news dashboard requests Umbraco's remote feed. On an offline server it waits for a timeout, logs an error and then shows its fallback. | `INewsDashboardService` returns an empty feed, so the dashboard shows its built-in resource links at once. Those links open external sites only when clicked. |

The package works through service registrations alone. Umbraco's methods, HTTP pipeline,
telemetry consent level and site identifier stay as they are, so other components see an
ordinary site and uninstalling the package restores Umbraco's behavior. When another
component has already removed the job, the registration leaves that state in place.
Custom code that bypasses the replaced services, or runs a reporting job directly, keeps
its own network behavior.

## Features that keep their network behavior

The package covers the requests that Umbraco makes on its own: the telemetry beacon,
installer reporting and the news feed. These features keep their normal behavior:

- **The Marketplace iframe, external media embeds and newsletter opt-in** request their
  sources when a user opens them.
- **Configured webhooks and email** send to the endpoints the site configures.
- **Update checks on Umbraco 17.0.x** run from the backoffice. Set
  `Umbraco:CMS:Global:VersionCheckPeriod` to `0` to switch them off. Umbraco 17.1 and
  later make the update-check sender a no-op, so the setting matters on 17.0.x only.
- **User avatars** come from the site's media. Umbraco 17 and 18 serve uploaded avatars
  and return an empty avatar list for users without one, so user management works
  offline without a Gravatar patch.

## Replacing an existing telemetry composer

Remove a composer that disables the same job when adopting this package, so the package is
the single owner of this behavior. In particular, UmbracoAppHost's original
`Overrides/DisableTelemetryComposer` expects to find the job and throws when it cannot.

## Testing

Every supported release passes a registration test and a live-site test. The browser
check runs on the same site in Chromium. [Developing](DEVELOPING.md) shows how to run
them.

| Test | Checks |
|---|---|
| Registration | Runs the registration twice against a service collection built with Umbraco's own extension. Duplicate telemetry job registrations are removed and the installer and news services are replaced, while unrelated jobs, factories and lifetimes stay as registered. |
| Live site | Composes a site with SQLite and Kestrel through ordinary composer discovery. The telemetry job is absent and every other recurring job remains. The telemetry service still produces a report with a valid site identifier, which shows that removing the job is what stops the beacon. Installation and upgrade reports complete on the server, and repeated news requests return empty feeds. The site then creates 200 users, looks up every avatar, uploads an avatar and downloads its five sizes, and removes it. |
| Browser | Signs in over HTTPS, checks the news dashboard's built-in fallback on the first visit and after a reload, and opens the Users collection on the populated site. |

The test site records every outgoing request. The HTTP client factory handler records
and rejects requests, and a .NET HTTP event listener observes directly constructed
clients, including the static clients of early Umbraco releases. Successful local avatar
downloads prove that the listener is recording. The browser check records and blocks
external browser requests. A test fails on any telemetry, installer reporting, news or
Gravatar attempt. [Validation](VALIDATION.md) records the latest run.
