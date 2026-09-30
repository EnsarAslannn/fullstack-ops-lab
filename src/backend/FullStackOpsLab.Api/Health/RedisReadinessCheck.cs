using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace FullStackOpsLab.Api.Health;

public sealed class RedisReadinessCheck(IDistributedCache cache) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            // A missing key is enough: the read still requires a working Redis connection.
            await cache.GetAsync("fullstack-ops:health:readiness", cancellationToken);
            return HealthCheckResult.Healthy();
        }
        catch (Exception)
        {
            return HealthCheckResult.Unhealthy("Redis unavailable");
        }
    }
}
