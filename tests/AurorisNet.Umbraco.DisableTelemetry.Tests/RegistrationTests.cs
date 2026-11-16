using Umbraco.Cms.Api.Management.Services.NewsDashboard;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.BackgroundJobs;
using Umbraco.Cms.Infrastructure.BackgroundJobs.Jobs;
using Umbraco.Cms.Infrastructure.BackgroundJobs.Jobs.ServerRegistration;
using Umbraco.Extensions;

namespace AurorisNet.Umbraco.DisableTelemetry.Tests;

/// <summary>Checks removal against Umbraco's own registration extension.</summary>
public sealed class RegistrationTests
{
    /// <summary>Repeated registration and removal preserve unrelated services, factories and lifetimes.</summary>
    [Fact]
    public void Reporting_and_news_are_disabled_without_changing_unrelated_services()
    {
        var services = new ServiceCollection();
        services.AddRecurringBackgroundJob<TempFileCleanupJob>();
        services.AddRecurringBackgroundJob<TouchServerJob>();
        services.AddSingleton<IRecurringBackgroundJob>(_ => throw new InvalidOperationException("Must not resolve services during composition."));
        services.AddSingleton(new object());
        var original = services.ToArray();
        services.AddRecurringBackgroundJob<ReportSiteJob>();
        services.AddRecurringBackgroundJob<ReportSiteJob>();
        services.AddSingleton<IInstallationService>(_ => throw new InvalidOperationException("Original installer reporter must not resolve."));
        services.AddSingleton<IInstallationService>(_ => throw new InvalidOperationException("Duplicate installer reporter must not resolve."));
        services.AddSingleton<INewsDashboardService>(_ => throw new InvalidOperationException("Original news service must not resolve."));
        services.AddSingleton<INewsDashboardService>(_ => throw new InvalidOperationException("Duplicate news service must not resolve."));

        var registration = new DisableTelemetryRegistration();
        registration.RegisterWith(services);
        registration.RegisterWith(services);

        Assert.Equal(original, services.Where(descriptor => descriptor.ServiceType != typeof(IInstallationService)
            && descriptor.ServiceType != typeof(INewsDashboardService)));
        using var provider = services.BuildServiceProvider();
        Assert.IsType<DisabledInstallationService>(Assert.Single(provider.GetServices<IInstallationService>()));
        Assert.IsType<DisabledNewsDashboardService>(Assert.Single(provider.GetServices<INewsDashboardService>()));
    }
}
