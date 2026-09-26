var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOpenApi();
builder.Services.AddHealthChecks();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapHealthChecks("/health");

var tasks = new List<TaskItem>();
var tasksLock = new object();
var nextTaskId = 1;

var taskRoutes = app.MapGroup("/api/tasks");

taskRoutes.MapGet("", () =>
{
    lock (tasksLock)
    {
        return Results.Ok(tasks.ToArray());
    }
});

taskRoutes.MapGet("/{id:int}", (int id) =>
{
    TaskItem? task;
    lock (tasksLock)
    {
        task = tasks.Find(item => item.Id == id);
    }

    return task is null ? (IResult)Results.NotFound() : Results.Ok(task);
});

taskRoutes.MapPost("", IResult (CreateTaskRequest request) =>
{
    if (string.IsNullOrWhiteSpace(request.Title))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["title"] = ["Title is required."]
        });
    }

    TaskItem task;
    lock (tasksLock)
    {
        var now = DateTimeOffset.UtcNow;
        task = new TaskItem(nextTaskId++, request.Title.Trim(), request.Description,
            false, now, now);
        tasks.Add(task);
    }

    return Results.Created($"/api/tasks/{task.Id}", task);
});

taskRoutes.MapPut("/{id:int}", IResult (int id, UpdateTaskRequest request) =>
{
    if (string.IsNullOrWhiteSpace(request.Title))
    {
        return Results.ValidationProblem(new Dictionary<string, string[]>
        {
            ["title"] = ["Title is required."]
        });
    }

    TaskItem updatedTask;
    lock (tasksLock)
    {
        var index = tasks.FindIndex(item => item.Id == id);
        if (index < 0)
        {
            return Results.NotFound();
        }

        updatedTask = tasks[index] with
        {
            Title = request.Title.Trim(),
            Description = request.Description,
            IsCompleted = request.IsCompleted,
            UpdatedAt = DateTimeOffset.UtcNow
        };
        tasks[index] = updatedTask;
    }

    return Results.Ok(updatedTask);
});

taskRoutes.MapDelete("/{id:int}", IResult (int id) =>
{
    lock (tasksLock)
    {
        var index = tasks.FindIndex(item => item.Id == id);
        if (index < 0)
        {
            return Results.NotFound();
        }

        tasks.RemoveAt(index);
    }

    return Results.NoContent();
});

app.Run();

record TaskItem(int Id, string Title, string? Description, bool IsCompleted,
    DateTimeOffset CreatedAt, DateTimeOffset UpdatedAt);

record CreateTaskRequest(string? Title, string? Description);

record UpdateTaskRequest(string? Title, string? Description, bool IsCompleted);
