using Microsoft.Playwright;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using Umbraco.Cms.Api.Management.Services.NewsDashboard;
using Umbraco.Cms.Core;
using Umbraco.Cms.Core.Cache;
using Umbraco.Cms.Core.IO;
using Umbraco.Cms.Core.Media;
using Umbraco.Cms.Core.Models;
using Umbraco.Cms.Core.Models.TemporaryFile;
using Umbraco.Cms.Core.Scoping;
using Umbraco.Cms.Core.Services;
using Umbraco.Cms.Core.Services.OperationStatus;
using Umbraco.Cms.Core.Telemetry;
using Umbraco.Cms.Infrastructure.BackgroundJobs;
using Umbraco.Cms.Infrastructure.BackgroundJobs.Jobs;
using static Microsoft.Playwright.Assertions;

namespace AurorisNet.Umbraco.DisableTelemetry.Tests;

/// <summary>Verifies real composition, startup, reporting suppression, dashboard news and user/avatar operations.</summary>
public sealed class SiteTests(ITestOutputHelper output)
{
    /// <summary>The package removes the scheduled beacon while the site's users and local avatars continue to work.</summary>
    [Fact]
    public async Task Site_starts_without_telemetry_and_manages_hundreds_of_users()
    {
        await using var site = await TestSite.StartAsync(TestContext.Current.CancellationToken);
        output.WriteLine("Site started; checking jobs and user population.");
        var jobs = site.Services.GetServices<IRecurringBackgroundJob>().ToArray();
        Assert.DoesNotContain(jobs, job => job is ReportSiteJob);
        Assert.Contains(jobs, job => job is TempFileCleanupJob);
        // A valid report still exists: suppression must come from job removal, not a damaged site ID or consent.
        Assert.NotNull(await site.Services.GetRequiredService<ITelemetryService>().GetTelemetryReportDataAsync());

        var installation = Assert.IsType<DisabledInstallationService>(site.Services.GetRequiredService<IInstallationService>());
        foreach (var isUpgrade in new[] { false, true })
            await installation.LogInstall(new InstallLog(Guid.NewGuid(), isUpgrade, true, DateTime.UtcNow,
                17, 0, 0, string.Empty, string.Empty, "Offline compatibility test", "Microsoft.Data.Sqlite"));
        var news = Assert.IsType<DisabledNewsDashboardService>(site.Services.GetRequiredService<INewsDashboardService>());
        Assert.Empty((await news.GetItemsAsync()).Items);
        Assert.Empty((await news.GetItemsAsync()).Items);

        var users = site.Services.GetRequiredService<IUserService>();
        // Seed the fixture in one transaction so background housekeeping cannot interleave 200 SQLite commits.
        using (var scope = site.Services.GetRequiredService<ICoreScopeProvider>().CreateCoreScope())
        {
            for (var index = 0; index < 200; index++)
                users.CreateUserWithIdentity($"offline-{index:D3}@example.test", $"offline-{index:D3}@example.test");
            scope.Complete();
        }
        var all = users.GetAll(0, 250, out var total).ToArray();
        output.WriteLine($"Created {total} users; checking avatar upload and downloads.");
        Assert.Equal(201, total);
        var cache = site.Services.GetRequiredService<AppCaches>().RuntimeCache;
        var media = site.Services.GetRequiredService<MediaFileManager>();
        var images = site.Services.GetRequiredService<IImageUrlGenerator>();
        foreach (var user in all)
            Assert.Empty(user.GetUserAvatarUrls(cache, media, images));

        var admin = users.GetByEmail(TestSite.Email)!;
        using var avatar = new Image<Rgba32>(32, 32, new Rgba32(40, 130, 190));
        using var png = new MemoryStream();
        avatar.SaveAsPng(png);
        var bytes = png.ToArray();
        var temporaryFiles = site.Services.GetRequiredService<ITemporaryFileService>();
        var upload = await temporaryFiles.CreateAsync(new CreateTemporaryFileModel
        {
            FileName = "avatar.png",
            OpenReadStream = () => new MemoryStream(bytes),
        });
        Assert.True(upload.Success, upload.Status.ToString());
        Assert.Equal(UserOperationStatus.Success, await users.SetAvatarAsync(admin.Key, upload.Result!.Key));
        admin = users.GetByEmail(TestSite.Email)!;
        var urls = admin.GetUserAvatarUrls(cache, media, images);
        Assert.Equal(5, urls.Length);
        using var http = new HttpClient(new HttpClientHandler
        {
            ServerCertificateCustomValidationCallback = (request, _, _, _) => request.RequestUri?.Authority == site.Address.Authority,
        }) { BaseAddress = site.Address };
        foreach (var url in urls)
        {
            var uri = new Uri(site.Address, url);
            Assert.Equal(site.Address.Authority, uri.Authority);
            using var response = await http.GetAsync(uri, TestContext.Current.CancellationToken);
            Assert.True(response.IsSuccessStatusCode, $"{uri}: {response.StatusCode}");
            Assert.StartsWith("image/", response.Content.Headers.ContentType!.MediaType!);
        }
        // Prove that the recorder sees a directly constructed HttpClient, not only factory clients.
        Assert.Contains(site.Requests.Attempted, uri => uri.Authority == site.Address.Authority);

        if (Environment.GetEnvironmentVariable("DISABLE_TELEMETRY_BROWSER") == "1")
        {
            output.WriteLine("Avatars passed; checking backoffice login, dashboard fallback and the user collection.");
            await CheckBackOfficeAsync(site);
        }

        Assert.Equal(UserOperationStatus.Success, await users.ClearAvatarAsync(admin.Key));
        Assert.Empty(users.GetByEmail(TestSite.Email)!.GetUserAvatarUrls(cache, media, images));
        Assert.DoesNotContain(site.Requests.Attempted, ExternalRequests.IsSuppressedRequest);
        output.WriteLine($"Verified {total} users, five uploaded avatar sizes, and {jobs.Length} remaining recurring jobs.");
    }

    private static async Task CheckBackOfficeAsync(TestSite site)
    {
        using var playwright = await Playwright.CreateAsync();
        await using var browser = await playwright.Chromium.LaunchAsync(new() { Headless = true });
        var context = await browser.NewContextAsync(new() { IgnoreHTTPSErrors = true });
        var external = new List<Uri>();
        await context.RouteAsync("**/*", async route =>
        {
            var uri = new Uri(route.Request.Url);
            if (uri.Authority == site.Address.Authority)
                await route.ContinueAsync();
            else
            {
                external.Add(uri);
                await route.AbortAsync();
            }
        });
        var page = await context.NewPageAsync();
        page.SetDefaultTimeout(60000);
        await page.GotoAsync(new Uri(site.Address, "/umbraco").ToString());
        await page.Locator("#username-input").FillAsync(TestSite.Email);
        await page.Locator("#password-input").FillAsync(TestSite.Password);
        await page.Locator("#umb-login-button").ClickAsync();
        await Expect(page.Locator("umb-backoffice")).ToBeVisibleAsync(new() { Timeout = 60000 });
        await Expect(page.Locator("umb-umbraco-news-dashboard #info-links")).ToBeVisibleAsync(new() { Timeout = 15000 });
        await Expect(page.Locator("umb-umbraco-news-dashboard uui-loader")).ToHaveCountAsync(0);
        // A second visit must also finish locally; there is no remote feed or failure cache to await.
        await page.ReloadAsync();
        await Expect(page.Locator("umb-umbraco-news-dashboard #info-links")).ToBeVisibleAsync(new() { Timeout = 15000 });
        await page.GotoAsync(new Uri(site.Address, "/umbraco/section/user-management/workspace/user-root").ToString());
        await Expect(page.Locator("umb-user-collection")).ToBeVisibleAsync(new() { Timeout = 60000 });
        await Expect(page.GetByText("Offline test administrator", new() { Exact = true }).First).ToBeVisibleAsync(new() { Timeout = 60000 });
        Assert.DoesNotContain(external, ExternalRequests.IsSuppressedRequest);
        await context.CloseAsync();
    }
}
