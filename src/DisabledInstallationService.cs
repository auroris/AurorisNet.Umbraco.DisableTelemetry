using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Services;

namespace AurorisNet.Umbraco.DisableTelemetry;

/// <summary>Completes installer reporting locally, including on Umbraco 17.0.x.</summary>
internal sealed class DisabledInstallationService : IInstallationService
{
    /// <inheritdoc />
    public Task LogInstall(InstallLog installLog) => Task.CompletedTask;
}
