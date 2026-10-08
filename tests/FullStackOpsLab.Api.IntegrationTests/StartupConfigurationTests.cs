namespace FullStackOpsLab.Api.IntegrationTests;

public sealed class StartupConfigurationTests
{
    [Theory]
    [InlineData("postgres", "", "ConnectionStrings:Postgres")]
    [InlineData("postgres", " ", "ConnectionStrings:Postgres")]
    [InlineData("postgres", "malformed", "ConnectionStrings:Postgres")]
    [InlineData("redis", "", "ConnectionStrings:Redis")]
    [InlineData("redis", "malformed", "ConnectionStrings:Redis")]
    [InlineData("ttl", "0", "Cache:TasksTtlSeconds")]
    [InlineData("ttl", "-1", "Cache:TasksTtlSeconds")]
    [InlineData("ttl", "not-a-number", "Cache:TasksTtlSeconds")]
    public void Invalid_configuration_refuses_startup_with_safe_key_only_error(string setting, string value, string errorKey)
    {
        var canary = Guid.NewGuid().ToString("N");
        var connection = new Npgsql.NpgsqlConnectionStringBuilder("Host=127.0.0.1;Port=1;Database=integration;Username=integration");
        connection["Password"] = canary;
        var postgres = connection.ConnectionString;
        var redis = "127.0.0.1:1,password=" + canary;
        var ttl = "60";
        if (setting == "postgres") postgres = value == "malformed" ? postgres + ";InvalidOption=" + canary : value;
        if (setting == "redis") redis = value == "malformed" ? redis + ",InvalidOption=" + canary : value;
        if (setting == "ttl") ttl = value;
        using var factory = new TestApiFactory(postgres, redis, ttl);
        var exception = Record.Exception(() => factory.CreateClient());
        Assert.True(exception is not null, "Invalid configuration must refuse startup.");
        var output = exception!.ToString();
        Assert.True(output.Contains(errorKey, StringComparison.Ordinal), "Expected safe configuration key was missing.");
        Assert.False(output.Contains(canary, StringComparison.Ordinal), "Startup exception exposed the generated canary.");
        if (!string.IsNullOrWhiteSpace(postgres))
            Assert.False(output.Contains(postgres, StringComparison.Ordinal), "Startup exception exposed the test connection string.");
    }

    [Fact]
    public async Task Valid_configuration_starts_without_connecting_to_dependencies()
    {
        using var factory = new TestApiFactory("Host=127.0.0.1;Port=1;Database=integration;Username=integration", "127.0.0.1:1,abortConnect=false");
        using var client = factory.CreateClient();
        using var response = await client.GetAsync("/health/live");
        Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
    }
}
