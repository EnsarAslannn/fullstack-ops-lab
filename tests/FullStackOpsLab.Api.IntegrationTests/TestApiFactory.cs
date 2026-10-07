using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Logging;

namespace FullStackOpsLab.Api.IntegrationTests;

public sealed class TestApiFactory(string postgres, string redis, string ttl = "60")
    : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        // Host settings are available before the top-level startup validation runs.
        // Production prevents this test host from loading development user-secrets.
        builder.UseEnvironment("Production");
        builder.UseSetting("ConnectionStrings:Postgres", postgres);
        builder.UseSetting("ConnectionStrings:Redis", redis);
        builder.UseSetting("Cache:TasksTtlSeconds", ttl);
        builder.ConfigureLogging(logging => logging.ClearProviders());
    }
}
