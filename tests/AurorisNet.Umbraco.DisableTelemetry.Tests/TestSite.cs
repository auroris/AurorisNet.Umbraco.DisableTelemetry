using System.Collections.Concurrent;
using System.Diagnostics.Tracing;
using System.Net;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.Extensions.Http;
using Umbraco.Cms.Api.Management.Services.NewsDashboard;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Infrastructure.BackgroundJobs;
using Umbraco.Cms.Infrastructure.BackgroundJobs.Jobs;
using Umbraco.Extensions;

namespace AurorisNet.Umbraco.DisableTelemetry.Tests;

/// <summary>A disposable, normally composed Umbraco site with SQLite and Kestrel.</summary>
internal sealed class TestSite(WebApplication app, string root, ExternalRequests requests) : IAsyncDisposable
{
    public const string Email = "offline@example.test";
    public const string Password = "Offline!Test5278";
    public IServiceProvider Services => app.Services;
    public Uri Address { get; } = new(app.Services.GetRequiredService<IServer>()
        .Features.Get<IServerAddressesFeature>()!.Addresses.Single());
    public ExternalRequests Requests => requests;

    public static async Task<TestSite> StartAsync(CancellationToken cancellationToken)
    {
        var root = Directory.CreateTempSubdirectory("disable-telemetry-test-").FullName;
        Directory.CreateDirectory(Path.Combine(root, "wwwroot"));
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions
        {
            ApplicationName = typeof(TestSite).Assembly.GetName().Name,
            ContentRootPath = root,
            EnvironmentName = "Development",
        });
        builder.WebHost.UseSetting(WebHostDefaults.StaticWebAssetsKey,
                Path.Combine(AppContext.BaseDirectory, typeof(TestSite).Assembly.GetName().Name + ".staticwebassets.runtime.json"))
            .UseStaticWebAssets();
        using var rsa = RSA.Create(2048);
        var certificateRequest = new CertificateRequest("CN=localhost", rsa, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        var names = new SubjectAlternativeNameBuilder();
        names.AddIpAddress(IPAddress.Loopback);
        certificateRequest.CertificateExtensions.Add(names.Build());
        using var generated = certificateRequest.CreateSelfSigned(DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(1));
        // Import a disposable key for Windows TLS; nothing is installed in the certificate store.
        var certificate = X509CertificateLoader.LoadPkcs12(generated.Export(X509ContentType.Pfx), null);
        builder.WebHost.ConfigureKestrel(server => server.Listen(IPAddress.Loopback, 0, listen => listen.UseHttps(certificate)));
        builder.Logging.ClearProviders();
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["ConnectionStrings:umbracoDbDSN"] = $"Data Source={Path.Combine(root, "umbraco.db")};Pooling=False",
            ["ConnectionStrings:umbracoDbDSN_ProviderName"] = "Microsoft.Data.Sqlite",
            ["Umbraco:CMS:Global:Id"] = Guid.NewGuid().ToString(),
            ["Umbraco:CMS:Global:UseHttps"] = "true",
            // Update checks are a separate, opt-out feature in 17.0.x; keep this fixture offline.
            ["Umbraco:CMS:Global:VersionCheckPeriod"] = "0",
            ["Umbraco:CMS:WebRouting:ApplicationUrlDetection"] = "FirstRequest",
            // Avoid unrelated concurrent SQLite writes while creating the test's user population.
            ["Umbraco:CMS:DistributedJobs:Delay"] = "01:00:00",
            ["Umbraco:CMS:Global:DatabaseServerMessenger:TimeBetweenSyncOperations"] = "01:00:00",
            ["Umbraco:CMS:Global:DatabaseServerRegistrar:WaitTimeBetweenCalls"] = "01:00:00",
            ["Umbraco:CMS:TypeFinder:AdditionalAssemblyExclusionEntries:0"] = "xunit.",
            ["Umbraco:CMS:Unattended:InstallUnattended"] = "true",
            ["Umbraco:CMS:Unattended:UpgradeUnattended"] = "true",
            ["Umbraco:CMS:Unattended:UnattendedUserName"] = "Offline test administrator",
            ["Umbraco:CMS:Unattended:UnattendedUserEmail"] = Email,
            ["Umbraco:CMS:Unattended:UnattendedUserPassword"] = Password,
            ["Umbraco:CMS:Unattended:UnattendedTelemetryLevel"] = "Detailed",
        });
        // Use the real discovery path; never call this package's composer directly here.
        var umbraco = builder.CreateUmbracoBuilder().AddBackOffice().AddWebsite().AddComposers();
        Assert.Contains(builder.Services, descriptor => descriptor.ImplementationType == typeof(ReportSiteJob));
        var otherJobs = builder.Services.Where(descriptor => descriptor.ServiceType == typeof(IRecurringBackgroundJob)
            && descriptor.ImplementationType != typeof(ReportSiteJob)).ToArray();
        umbraco.Build();
        Assert.DoesNotContain(builder.Services, descriptor => descriptor.ImplementationType == typeof(ReportSiteJob));
        Assert.Equal(otherJobs, builder.Services.Where(descriptor => descriptor.ServiceType == typeof(IRecurringBackgroundJob)));
        Assert.Equal(typeof(DisabledInstallationService), Assert.Single(builder.Services,
            descriptor => descriptor.ServiceType == typeof(IInstallationService)).ImplementationType);
        Assert.Equal(typeof(DisabledNewsDashboardService), Assert.Single(builder.Services,
            descriptor => descriptor.ServiceType == typeof(INewsDashboardService)).ImplementationType);

        var requests = new ExternalRequests();
        builder.Services.AddSingleton<IHttpMessageHandlerBuilderFilter>(requests);
        var app = builder.Build();
        app.Lifetime.ApplicationStopped.Register(certificate.Dispose);
        try
        {
            await app.BootUmbracoAsync();
            app.UseUmbraco().WithMiddleware(u => { u.UseBackOffice(); u.UseWebsite(); })
                .WithEndpoints(u => { u.UseBackOfficeEndpoints(); u.UseWebsiteEndpoints(); });
            await app.StartAsync(cancellationToken);
            // Early Umbraco 17 installs during boot; later releases move it to a hosted service.
            var installer = app.Services.GetServices<IHostedService>().OfType<BackgroundService>()
                .SingleOrDefault(service => service.GetType().Name == "UnattendedUpgradeBackgroundService");
            if (installer?.ExecuteTask is { } installation)
                await installation.WaitAsync(TimeSpan.FromMinutes(3), cancellationToken);
            var runtime = app.Services.GetRequiredService<IRuntimeState>();
            Assert.True(runtime.Level == RuntimeLevel.Run, runtime.BootFailedException?.ToString() ?? runtime.Level.ToString());
            return new TestSite(app, root, requests);
        }
        catch
        {
            await app.StopAsync(CancellationToken.None);
            await app.DisposeAsync();
            certificate.Dispose();
            await Serilog.Log.CloseAndFlushAsync();
            requests.Dispose();
            DeleteRoot(root);
            throw;
        }
    }

    public async ValueTask DisposeAsync()
    {
        await app.StopAsync(CancellationToken.None);
        await app.DisposeAsync();
        await Serilog.Log.CloseAndFlushAsync();
        requests.Dispose();
        DeleteRoot(root);
    }

    private static void DeleteRoot(string root)
    {
        // Delete only the uniquely named temporary site created above.
        var fullRoot = Path.GetFullPath(root);
        var temp = Path.TrimEndingDirectorySeparator(Path.GetFullPath(Path.GetTempPath())) + Path.DirectorySeparatorChar;
        if (!fullRoot.StartsWith(temp, StringComparison.OrdinalIgnoreCase)
            || !Path.GetFileName(fullRoot).StartsWith("disable-telemetry-test-", StringComparison.Ordinal))
            throw new InvalidOperationException($"Unexpected test directory: {fullRoot}");
        Directory.Delete(fullRoot, recursive: true);
    }
}

/// <summary>Blocks factory requests and observes all .NET HTTP requests, including directly constructed clients.</summary>
internal sealed class ExternalRequests : EventListener, IHttpMessageHandlerBuilderFilter
{
    public ConcurrentQueue<Uri> Attempted { get; } = new();

    protected override void OnEventSourceCreated(EventSource eventSource)
    {
        if (eventSource.Name == "System.Net.Http")
            EnableEvents(eventSource, EventLevel.Informational);
    }

    protected override void OnEventWritten(EventWrittenEventArgs eventData)
    {
        if (eventData.EventName != "RequestStart" || eventData.Payload is not { Count: >= 4 } payload)
            return;

        // .NET's RequestStart payload is scheme, host, port, pathAndQuery, then protocol details.
        var origin = new UriBuilder((string)payload[0]!, (string)payload[1]!, (int)payload[2]!);
        Attempted.Enqueue(new Uri(origin.Uri, (string)payload[3]!));
    }

    public Action<HttpMessageHandlerBuilder> Configure(Action<HttpMessageHandlerBuilder> next) => builder =>
    {
        next(builder);
        builder.AdditionalHandlers.Insert(0, new Handler(Attempted));
    };

    public static bool IsSuppressedRequest(Uri uri) => uri.Host is "telemetry.umbraco.com" or "telemetry.rainbowsrock.net"
        or "news-dashboard.umbraco.com" or "gravatar.com"
        || uri.Host.EndsWith(".gravatar.com", StringComparison.OrdinalIgnoreCase)
        || uri.Host == "our.umbraco.com" && uri.AbsolutePath.Equals("/umbraco/api/Installation/Install", StringComparison.OrdinalIgnoreCase);

    private sealed class Handler(ConcurrentQueue<Uri> attempted) : DelegatingHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            attempted.Enqueue(request.RequestUri!);
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.ServiceUnavailable));
        }
    }
}
