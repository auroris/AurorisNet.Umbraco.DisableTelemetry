using Umbraco.Cms.Api.Management.Services.NewsDashboard;
using Umbraco.Cms.Api.Management.ViewModels.NewsDashboard;

namespace AurorisNet.Umbraco.DisableTelemetry;

/// <summary>Uses Umbraco's built-in dashboard fallback without requesting a remote news feed.</summary>
internal sealed class DisabledNewsDashboardService : INewsDashboardService
{
    /// <inheritdoc />
    public Task<NewsDashboardResponseModel> GetItemsAsync()
        => Task.FromResult(new NewsDashboardResponseModel { Items = [] });
}
