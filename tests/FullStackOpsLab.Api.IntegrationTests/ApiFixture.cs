using FullStackOpsLab.Api.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging.Abstractions;
using Testcontainers.PostgreSql;
using Testcontainers.Redis;

namespace FullStackOpsLab.Api.IntegrationTests;

public sealed class ApiFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer postgres = new PostgreSqlBuilder("postgres:18-alpine")
        .WithDatabase("integration")
        .WithUsername("integration")
        .WithPassword(Guid.NewGuid().ToString("N"))
        .WithTmpfsMount("/var/lib/postgresql")
        .WithLogger(NullLogger.Instance)
        .WithCreateParameterModifier(parameters =>
        {
            foreach (var binding in parameters.HostConfig!.PortBindings!["5432/tcp"])
                binding.HostIP = "127.0.0.1";
        })
        .Build();

    private readonly RedisContainer redis = new RedisBuilder("redis:8.2.10-alpine")
        .WithTmpfsMount("/data")
        .WithLogger(NullLogger.Instance)
        .WithCreateParameterModifier(parameters =>
        {
            foreach (var binding in parameters.HostConfig!.PortBindings!["6379/tcp"])
                binding.HostIP = "127.0.0.1";
        })
        .Build();

    public TestApiFactory Factory { get; private set; } = null!;
    public HttpClient Client { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        try
        {
            using var timeout = new CancellationTokenSource(TimeSpan.FromMinutes(3));
            await postgres.StartAsync(timeout.Token);
            await redis.StartAsync(timeout.Token);
            Factory = new TestApiFactory(postgres.GetConnectionString(), redis.GetConnectionString());
            Client = Factory.CreateClient();
            Client.Timeout = TimeSpan.FromSeconds(15);
            using var scope = Factory.Services.CreateScope();
            await scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.MigrateAsync(timeout.Token);
        }
        catch
        {
            try { await DisposeAsync(); }
            catch { throw new InvalidOperationException("Isolated integration setup and cleanup failed. Check owned Testcontainers resources."); }
            throw new InvalidOperationException("Isolated integration setup failed. Check Docker Linux engine and image availability.");
        }
    }

    public async Task ResetAsync()
    {
        using var scope = Factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Tasks.ExecuteDeleteAsync();
        await scope.ServiceProvider.GetRequiredService<Microsoft.Extensions.Caching.Distributed.IDistributedCache>()
            .RemoveAsync("fullstack-ops:tasks:all:v1");
    }

    public async Task DisposeAsync()
    {
        Client?.Dispose();
        try
        {
            await Task.WhenAll(Factory is null ? Task.CompletedTask : Factory.DisposeAsync().AsTask(),
                postgres.DisposeAsync().AsTask(), redis.DisposeAsync().AsTask());
        }
        catch
        {
            throw new InvalidOperationException("Isolated integration cleanup failed. Check owned Testcontainers resources.");
        }
    }
}
