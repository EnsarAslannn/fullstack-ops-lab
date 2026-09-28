using FullStackOpsLab.Api.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddHealthChecks();

var postgresConnectionString = builder.Configuration.GetConnectionString("Postgres");
if (string.IsNullOrWhiteSpace(postgresConnectionString))
{
    throw new InvalidOperationException(
        "Missing ConnectionStrings:Postgres configuration. Set it through user-secrets or an environment variable.");
}

builder.Services.AddDbContext<AppDbContext>(options => options.UseNpgsql(postgresConnectionString));

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapHealthChecks("/health");

var taskRoutes = app.MapGroup("/api/tasks");

taskRoutes.MapGet("", async (AppDbContext db, CancellationToken cancellationToken) =>
{
    var tasks = await db.Tasks.AsNoTracking().OrderBy(task => task.Id).ToListAsync(cancellationToken);
    return Results.Ok(tasks.Select(ToTaskItem));
});

taskRoutes.MapGet("/{id:int}", async (int id, AppDbContext db, CancellationToken cancellationToken) =>
{
    var task = await db.Tasks.AsNoTracking()
        .SingleOrDefaultAsync(item => item.Id == id, cancellationToken);

    return task is null ? (IResult)Results.NotFound() : Results.Ok(ToTaskItem(task));
});

taskRoutes.MapPost("", async Task<IResult> (CreateTaskRequest request, AppDbContext db,
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

    return Results.Created($"/api/tasks/{task.Id}", ToTaskItem(task));
});

taskRoutes.MapPut("/{id:int}", async Task<IResult> (int id, UpdateTaskRequest request,
    AppDbContext db, CancellationToken cancellationToken) =>
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

    return Results.Ok(ToTaskItem(task));
});

taskRoutes.MapDelete("/{id:int}", async Task<IResult> (int id, AppDbContext db,
    CancellationToken cancellationToken) =>
{
    var task = await db.Tasks.SingleOrDefaultAsync(item => item.Id == id, cancellationToken);
    if (task is null)
    {
        return Results.NotFound();
    }

    db.Tasks.Remove(task);
    await db.SaveChangesAsync(cancellationToken);
    return Results.NoContent();
});

app.Run();

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
