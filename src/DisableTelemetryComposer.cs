using Umbraco.Cms.Core.Composing;
using Umbraco.Cms.Core.DependencyInjection;

namespace AurorisNet.Umbraco.DisableTelemetry;

/// <summary>Stops Umbraco's telemetry beacon, installer reporting and dashboard news requests.</summary>
public sealed class DisableTelemetryComposer : IComposer
{
    /// <summary>Applies suppression after all composers have registered their services.</summary>
    public void Compose(IUmbracoBuilder builder)
        => builder.WithCollectionBuilder<DisableTelemetryRegistration>();
}
