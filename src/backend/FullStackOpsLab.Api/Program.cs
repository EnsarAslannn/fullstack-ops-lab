using FullStackOpsLab.Api.Data;
using FullStackOpsLab.Api.Health;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.Caching.Distributed;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy(), tags: ["live"])
    .AddCheck<PostgreSqlReadinessCheck>("postgres", tags: ["ready"], timeout: TimeSpan.FromSeconds(2))
    .AddCheck<RedisReadinessCheck>("redis", tags: ["ready"], timeout: TimeSpan.FromSeconds(2));

const string taskListCacheKey = "fullstack-ops:tasks:all:v1";
var taskListCacheTtlSeconds = builder.Configuration.GetValue<int?>("Cache:TasksTtlSeconds") ?? 60;
if (taskListCacheTtlSeconds <= 0)
{
    throw new InvalidOperationException("Cache:TasksTtlSeconds must be greater than zero.");
}

var postgresConnectionString = builder.Configuration.GetConnectionString("Postgres");
if (string.IsNullOrWhiteSpace(postgresConnectionString))
{
    throw new InvalidOperationException(
        "Missing ConnectionStrings:Postgres configuration. Set it through user-secrets or an environment variable.");
}

builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(postgresConnectionString));

var redisConnectionString = builder.Configuration.GetConnectionString("Redis");
if (string.IsNullOrWhiteSpace(redisConnectionString))
{
    throw new InvalidOperationException(
        "Missing ConnectionStrings:Redis configuration. Set it through user-secrets or an environment variable.");
}

builder.Services.AddStackExchangeRedisCache(options => options.Configuration = redisConnectionString);

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapHealthChecks("/health", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("live")
});
app.MapHealthChecks("/health/live", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("live")
});
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});

var taskRoutes = app.MapGroup("/api/tasks");

taskRoutes.MapGet("", async (AppDbContext db, IDistributedCache cache, ILogger<Program> logger,
    CancellationToken cancellationToken) =>
{
    var cachedTasks = await cache.GetStringAsync(taskListCacheKey, cancellationToken);
    if (cachedTasks is not null)
    {
        logger.LogInformation("[CACHE HIT] {CacheKey}", taskListCacheKey);
        return Results.Ok(JsonSerializer.Deserialize<TaskItem[]>(cachedTasks));
    }

    logger.LogInformation("[CACHE MISS] {CacheKey}", taskListCacheKey);
    var tasks = await db.Tasks.AsNoTracking().OrderBy(task => task.Id).ToListAsync(cancellationToken);
    var response = tasks.Select(ToTaskItem).ToArray();
    await cache.SetStringAsync(taskListCacheKey, JsonSerializer.Serialize(response),
        new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(taskListCacheTtlSeconds)
        }, cancellationToken);
    return Results.Ok(response);
});

taskRoutes.MapGet("/{id:int}", async (int id, AppDbContext db, CancellationToken cancellationToken) =>
{
    var task = await db.Tasks.AsNoTracking()
        .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);

    return task is null ? (IResult)Results.NotFound() : Results.Ok(ToTaskItem(task));
});

taskRoutes.MapPost("", async Task<IResult> (CreateTaskRequest request, AppDbContext db,
    IDistributedCache cache, ILogger<Program> logger,
    CancellationToken cancellationToken) =>
{
    if (string.IsNullOrWhiteSpace(request.Title))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["title"] = ["Title is required."]
        });
    }

    var now = UtcNowForPostgres();
    var task = new TaskEntity
    {
        Title = request.Title.Trim(),
        Description = request.Description,
        IsCompleted = false,
        CreatedAt = now,
        UpdatedAt = now
    };
    await db.Tasks.AddAsync(task, cancellationToken);
    await db.SaveChangesAsync(cancellationToken);
    await InvalidateTaskListCacheAsync(cache, logger, taskListCacheKey, cancellationToken);

    return Results.Created($"/api/tasks/{task.Id}", ToTaskItem(task));
});

taskRoutes.MapPut("/{id:int}", async Task<IResult> (int id, UpdateTaskRequest request,
    AppDbContext db, IDistributedCache cache, ILogger<Program> logger, CancellationToken cancellationToken) =>
{
    if (string.IsNullOrWhiteSpace(request.Title))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["title"] = ["Title is required."]
        });
    }

    var task = await db.Tasks.SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
    if (task is null)
    {
        return Results.NotFound();
    }

    task.Title = request.Title.Trim();
    task.Description = request.Description;
    task.IsCompleted = request.IsCompleted;
    task.UpdatedAt = UtcNowForPostgres();
    await db.SaveChangesAsync(cancellationToken);
    await InvalidateTaskListCacheAsync(cache, logger, taskListCacheKey, cancellationToken);

    return Results.Ok(ToTaskItem(task));
});

taskRoutes.MapDelete("/{id:int}", async Task<IResult> (int id, AppDbContext db,
    IDistributedCache cache, ILogger<Program> logger, CancellationToken cancellationToken) =>
{
    var task = await db.Tasks.SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
    if (task is null)
    {
        return Results.NotFound();
    }

    db.Tasks.Remove(task);
    await db.SaveChangesAsync(cancellationToken);
    await InvalidateTaskListCacheAsync(cache, logger, taskListCacheKey, cancellationToken);
    return Results.NoContent();
});

app.Run();

static async Task InvalidateTaskListCacheAsync(IDistributedCache cache, ILogger logger,
    string cacheKey, CancellationToken cancellationToken)
{
    try
    {
        await cache.RemoveAsync(cacheKey, cancellationToken);
        logger.LogInformation("[CACHE INVALIDATED] {CacheKey}", cacheKey);
    }
    catch (Exception exception) when (exception is not OperationCanceledException)
    {
        // The PostgreSQL write has succeeded; a cache failure must not report that write as failed.
        logger.LogWarning(exception, "Could not invalidate task list cache {CacheKey}", cacheKey);
    }
}

static DateTimeOffset UtcNowForPostgres()
{
    var now = DateTimeOffset.UtcNow;
    return now.AddTicks(-(now.Ticks % 10));
}

static TaskItem ToTaskItem(TaskEntity task) => new(task.Id, task.Title, task.Description,
    task.IsCompleted, task.CreatedAt, task.UpdatedAt ?? task.CreatedAt);

record TaskItem(int Id, string Title, string? Description, bool IsCompleted,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);

record CreateTaskRequest(string? Title, string? Description);

record UpdateTaskRequest(string? Title, string? Description, bool IsCompleted);
