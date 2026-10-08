using System.Globalization;
using Npgsql;
using StackExchange.Redis;

namespace FullStackOpsLab.Api.Configuration;

internal sealed record ApiConfiguration(string PostgresConnectionString, string RedisConnectionString,
    int TaskListCacheTtlSeconds)
{
    public static ApiConfiguration Read(IConfiguration configuration)
    {
        var postgres = configuration.GetConnectionString("Postgres");
        if (string.IsNullOrWhiteSpace(postgres))
        {
            throw new InvalidOperationException("ConnectionStrings:Postgres eksik veya geçersiz.");
        }

        try
        {
            var parsed = new NpgsqlConnectionStringBuilder(postgres);
            if (string.IsNullOrWhiteSpace(parsed.Host) || string.IsNullOrWhiteSpace(parsed.Database) ||
                string.IsNullOrWhiteSpace(parsed.Username))
            {
                throw new InvalidOperationException();
            }
        }
        catch (Exception)
        {
            throw new InvalidOperationException("ConnectionStrings:Postgres eksik veya geçersiz.");
        }

        var redis = configuration.GetConnectionString("Redis");
        if (string.IsNullOrWhiteSpace(redis))
        {
            throw new InvalidOperationException("ConnectionStrings:Redis eksik veya geçersiz.");
        }

        try
        {
            if (ConfigurationOptions.Parse(redis).EndPoints.Count == 0)
            {
                throw new InvalidOperationException();
            }
        }
        catch (Exception)
        {
            throw new InvalidOperationException("ConnectionStrings:Redis eksik veya geçersiz.");
        }

        var rawTtl = configuration["Cache:TasksTtlSeconds"];
        var ttl = 60;
        if (rawTtl is not null &&
            (!int.TryParse(rawTtl, NumberStyles.Integer, CultureInfo.InvariantCulture, out ttl) || ttl <= 0))
        {
            throw new InvalidOperationException("Cache:TasksTtlSeconds pozitif bir tamsayı olmalı.");
        }

        return new ApiConfiguration(postgres, redis, ttl);
    }
}
