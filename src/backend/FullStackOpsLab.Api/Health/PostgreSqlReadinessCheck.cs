using Microsoft.Extensions.Diagnostics.HealthChecks;
using Npgsql;

namespace FullStackOpsLab.Api.Health;

public sealed class PostgreSqlReadinessCheck(IConfiguration configuration) : IHealthCheck
{
    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            await using var connection = new NpgsqlConnection(configuration.GetConnectionString("Postgres"));
            await connection.OpenAsync(cancellationToken);
            await using var command = new NpgsqlCommand("SELECT 1", connection) { CommandTimeout = 2 };
            var result = await command.ExecuteScalarAsync(cancellationToken);
            return result is int value && value == 1
                ? HealthCheckResult.Healthy()
                : HealthCheckResult.Unhealthy("PostgreSQL unavailable");
        }
        catch (Exception)
        {
            return HealthCheckResult.Unhealthy("PostgreSQL unavailable");
        }
    }
}
