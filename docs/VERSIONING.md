# Version numbering and releases

A package version is `<newest supported Umbraco release>.<release count>`. Version
`18.3.1.1` supports every Umbraco 18 release up to 18.3.1, and it is our first release
for 18.3.1.

## One version per Umbraco major version

Each release publishes one version for each supported Umbraco major version, built from
the same source:

| Version | Supports |
|---|---|
| `18.3.1.1` | Every Umbraco 18 release up to 18.3.1 |
| `17.8.1.1` | Every Umbraco 17 release up to 17.8.1 |

Reference your site's major version, such as `18.*` or `17.*`, so NuGet installs the
newest package for it. Both versions of a release depend on the whole supported range,
from the oldest supported Umbraco release to the newest, so either one installs on
Umbraco 17 or 18. The [supported-versions table](../README.md#supported-versions) lists
the tested releases.

## Release counts

The count starts at 1 for each Umbraco release, and each major version counts on its
own:

- Adding Umbraco 18.3.2 makes the next Umbraco 18 version `18.3.2.1`. The Umbraco 17
  version of the same release takes its next count, `17.8.1.2`.
- Adding Umbraco 17.8.2 makes the next Umbraco 17 version `17.8.2.1`. The Umbraco 18
  version takes its next count.

Local builds use count 0, which is never published.

## Publishing setup

Complete these account settings before the first release:

1. Configure NuGet trusted publishing for the `AurorisNet` account, the repository
   `auroris/UmbracoDisableTelemetry`, the workflow `release.yml` and no environment. See
   [NuGet trusted publishing](https://learn.microsoft.com/en-us/nuget/nuget-org/trusted-publishing).
2. Enable private vulnerability reporting on GitHub, so the form in
   [Security](../SECURITY.md) reaches the maintainers.
3. Add a tag rule that keeps `v*` tags from being moved or deleted. NuGet keeps every
   version it has published, so the workflow counts past every existing tag when it
   chooses the next count.

## Publish a release

Run the [compatibility matrix](DEVELOPING.md#test-other-umbraco-releases) first. Then open
**Actions → Release → Run workflow** on GitHub and select `main`. Pushes never start a
release, and the workflow runs no tests, because each Umbraco release was tested when it
was added. It:

1. chooses each version's count from the release tags;
2. builds and packs each version, and stops on any build warning;
3. reserves a tag for each, such as `v18.3.1.1` and `v17.8.1.1`, before publishing any;
4. publishes each package to NuGet and creates a GitHub release for each. The Umbraco 18
   release is marked as the latest, and the Umbraco 17 release points to it.

The workflow has two inputs:

- **dry-run** stops after step 2 and keeps the packages as an artifact of the run, named
  `packages-<run>`. Nothing is tagged or published, so use it to see what a release of
  `main` would publish, or to try a change to the workflow.
- **notes** is Markdown for the GitHub release. The workflow places it above GitHub's
  generated list of changes, which names merged pull requests only. Describe changes
  that were committed to `main` directly, and anything a site must do when it updates.

Running Release again for a tagged commit reuses its tags and skips the packages NuGet
already has, so a partial publication can finish. A new count goes only to the tip of
`main`. When a newer release is published already, the retried one leaves it marked as the
latest.

## Marketplace listing

The package carries the `umbraco-marketplace` tag, and Umbraco Marketplace reads
[`umbraco-marketplace.json`](../umbraco-marketplace.json) from `main` for its category,
license, documentation link and issue tracker. Push changes to that file before
releasing. After publishing, check the listing with the
[Marketplace validation tools](https://marketplace.umbraco.com/validate) and package ID
`AurorisNet.Umbraco.DisableTelemetry`.
