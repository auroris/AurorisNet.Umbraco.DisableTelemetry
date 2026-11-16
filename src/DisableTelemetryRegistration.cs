using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Umbraco.Cms.Api.Management.Services.NewsDashboard;
using Umbraco.Cms.Core.Composing;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.BackgroundJobs;
using Umbraco.Cms.Infrastructure.BackgroundJobs.Jobs;

namespace AurorisNet.Umbraco.DisableTelemetry;

/// <summary>Disables reporting and news fetching when Umbraco finalizes its service registrations.</summary>
internal sealed class DisableTelemetryRegistration : ICollectionBuilder
{
    /// <summary>
    /// Removes the built-in report job and replaces installer reporting and news fetching with local responses.
    /// Other recurring jobs and the scheduler keep their original registrations.
    /// </summary>
    public void RegisterWith(IServiceCollection services)
    {
        for (var index = services.Count - 1; index >= 0; index--)
        {
            var registration = services[index];
            if (registration.ServiceType == typeof(IRecurringBackgroundJob)
                && registration.ImplementationType == typeof(ReportSiteJob))
                services.RemoveAt(index);
        }

        services.RemoveAll<IInstallationService>();
        services.AddSingleton<IInstallationService, DisabledInstallationService>();
        services.RemoveAll<INewsDashboardService>();
        services.AddSingleton<INewsDashboardService, DisabledNewsDashboardService>();
    }
}
