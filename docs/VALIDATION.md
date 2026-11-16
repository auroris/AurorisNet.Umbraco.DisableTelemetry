# Validation

Validated on 15 November 2026 on Windows with .NET SDK 10.0.403, SQLite, Kestrel HTTPS
and Playwright Chromium.

## Results

| Check | Result |
|---|---|
| Every stable Umbraco release from 17.0.0 through 17.8.1 | All 28 passed |
| Every stable Umbraco release from 18.0.0 through 18.3.1 | All 10 passed |
| Registration test and live-site test | 76 passing test cases across the 38 releases |
| Browser login, news fallback, reload and Users collection | Passed on every release, with 201 users per site |
| Avatar upload, five image sizes and removal | Passed on every release |
| Installer reporting and news services | Replacements resolved; reports completed locally and repeated news requests returned empty feeds |
| Telemetry job and HTTP request checks | Job absent; no telemetry, installer reporting, news or Gravatar attempts observed |
| Release version and latest-release scripts | Prior validation: 30 Pester tests passed; scripts unchanged |
| Marketplace metadata | Prior validation: passed the published Marketplace JSON schema; metadata unchanged |
| Local packages | Both major-version variants built and inspected |

Each site used ordinary composer discovery. Before composition completed, Umbraco's
built-in telemetry registration was present. Afterwards it was absent, while every
other recurring job registration was preserved. A valid telemetry report remained
available from the telemetry service, confirming that suppression came from removing
the scheduled sender. Installer reporting and news service registrations were checked
before boot, so the original services could not run during unattended installation.

The browser tests signed in over HTTPS, checked the news dashboard's built-in fallback
on the first visit and after a reload, then opened the Users collection. Server HTTP
client factory requests and external browser requests were recorded and blocked.

A .NET HTTP event listener also observed directly constructed clients, including the
static clients used by early Umbraco releases. Successful local avatar downloads proved
that the event listener was recording those requests. It observes requests rather than
blocking them. The earlier factory-only recorder did not cover these clients.

The fixture sets `VersionCheckPeriod` to `0` to keep the separate Umbraco 17.0.x update
checker from contacting its endpoint. The package leaves that setting under the site's
control. No network settings on the host machine were changed.

## Evidence and limits

Local build and test logs are under `artifacts/umbraco-releases/<version>`. The combined
verified result is `artifacts/umbraco-releases/verified-results.json`. Artifacts are
Git-ignored.

Older Umbraco test hosts emitted NuGet audit warnings for their own dependency graphs.
The package's release builds completed without warnings. Compatibility coverage does
not change the security support status of an older Umbraco release.

The package and release workflow are prepared locally. GitHub publishing, NuGet trusted
publishing and the Marketplace listing have not been exercised for this new repository.
The package removes the built-in telemetry job and replaces installer reporting and news
fetching. Other internet-dependent features retain their normal behavior. These checks
cover the exercised Umbraco paths, not third-party packages or operating-system traffic.
