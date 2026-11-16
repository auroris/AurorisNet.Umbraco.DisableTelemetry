# Version numbering and releases

A package version is `<newest supported Umbraco release>.<release count>`. A release
publishes the same implementation under one version for each supported major version:

| Initial version | Site package reference |
|---|---|
| `18.3.1.1` | `18.*` |
| `17.8.1.1` | `17.*` |

Both packages depend on the full supported Umbraco range. The major version in their
number lets sites follow their own Umbraco version when choosing updates. Counts start
at 1 and increase independently. Adding support for 18.3.2 starts `18.3.2.1`; another
release for 17.8.1 increments its existing count. Local builds use count 0.

## Publishing setup

Before publishing the first release:

1. Create the GitHub repository `auroris/UmbracoDisableTelemetry` and push `main`.
2. Configure NuGet trusted publishing for the `AurorisNet` account, repository
   `auroris/UmbracoDisableTelemetry`, workflow `release.yml`, and no environment.
3. Enable private vulnerability reporting on GitHub and protect `v*` tags from deletion
   or replacement. NuGet retains published versions, so release tags must remain available
   for choosing the next count.

The workflow and metadata are prepared locally; these account settings must be completed
before a real release. See [NuGet trusted publishing](https://learn.microsoft.com/en-us/nuget/nuget-org/trusted-publishing).

## Publish

Run the compatibility matrix before releasing. The manual **Actions → Release → Run
workflow** action builds and publishes; it does not repeat the tests. Pushes never
publish packages.

Choose `main`. Use **dry-run** to build both packages and retain them as a workflow
artifact before publishing. On a real run, the workflow reserves both release tags,
logs in to NuGet with trusted publishing, pushes the packages, and creates GitHub
releases. The Umbraco 18 version is marked as latest unless a newer release already
exists. A retry reuses tags for that commit and skips packages NuGet already has.

The optional **notes** input supplies release notes above GitHub's generated list of
changes. Record changes committed directly to `main` there too.

## Marketplace

The package carries the `umbraco-marketplace` tag. `umbraco-marketplace.json` supplies
its category, licence and documentation links. Publish that metadata on `main` before
releasing, then check the listing with the
[Marketplace validation tools](https://marketplace.umbraco.com/validate) and package ID
`AurorisNet.Umbraco.DisableTelemetry`.
