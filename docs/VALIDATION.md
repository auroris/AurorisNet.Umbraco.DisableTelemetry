# Validation

This record covers the test run of 15 November 2026 on Windows with .NET SDK 10.0.403,
SQLite, Kestrel HTTPS and Playwright Chromium. [Developing](DEVELOPING.md) describes the
tests, and [Behavior and compatibility](BEHAVIOR.md#testing) summarizes what they check.

## Results

| Check | Result |
|---|---|
| Every stable Umbraco release from 17.0.0 through 17.8.1 | All 28 passed |
| Every stable Umbraco release from 18.0.0 through 18.3.1 | All 10 passed |
| Registration test and live-site test | 76 passing test cases across the 38 releases |
| Browser sign-in, news fallback, reload and Users collection | Passed on every release, with 201 users per site |
| Avatar upload, five image sizes and removal | Passed on every release |
| Installer reporting and news services | Replacements resolved; reports completed on the server, and repeated news requests returned empty feeds |
| Telemetry job and HTTP request checks | Job absent; no telemetry, installer reporting, news or Gravatar attempts observed |
| Release version and latest-release scripts | Prior validation: 30 Pester tests passed; scripts unchanged since |
| Marketplace metadata | Prior validation: passed the published Marketplace JSON schema; metadata unchanged since |
| Local packages | Both major-version variants built and inspected |

## What the run showed

Each site composed through ordinary composer discovery. Before composition completed,
Umbraco's built-in telemetry registration was present. Afterwards it was absent, and
every other recurring job registration remained. The telemetry service still produced a
valid report, which confirms that removing the scheduled sender is what suppresses the
beacon. The fixture checked the installer reporting and news service registrations before
boot, so the original services could not run during unattended installation.

The browser check signed in over HTTPS, checked the news dashboard's built-in fallback on
the first visit and after a reload, then opened the Users collection. Server HTTP client
factory requests and external browser requests were recorded and blocked.

The .NET HTTP event listener observed directly constructed clients, including the static
clients of early Umbraco releases. Successful local avatar downloads proved that the
listener was recording those requests. The listener observes requests and leaves them to
complete; the factory handler is what blocks requests. An earlier factory-only recorder
missed these clients, which is why the listener was added.

The fixture set `VersionCheckPeriod` to `0`, which kept the separate Umbraco 17.0.x update
checker from contacting its endpoint. The package leaves that setting to the site. The
host machine's network settings stayed as they were.

## Evidence and limits

Build and test logs are under `artifacts/umbraco-releases/<version>`. The combined
verified result is `artifacts/umbraco-releases/verified-results.json`. Artifacts are
Git-ignored, so they exist on the machine that ran the tests.

Older Umbraco test hosts emitted NuGet audit warnings for their own dependency graphs.
The package's release builds completed without warnings. Compatibility coverage leaves the
security support status of an older Umbraco release unchanged.

The package and release workflow were prepared locally. GitHub publishing, NuGet trusted
publishing and the Marketplace listing remain unexercised for this repository. The checks
cover the Umbraco paths the tests exercise: the telemetry job, installer reporting and the
news feed. Third-party packages and operating-system traffic are outside their scope.
