using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using FullStackOpsLab.Api.Data;
using Microsoft.Extensions.DependencyInjection;

namespace FullStackOpsLab.Api.IntegrationTests;

// xUnit runs one class's cases serially. Every case resets only this fixture's isolated data.
public sealed class TasksApiTests(ApiFixture fixture) : IClassFixture<ApiFixture>, IAsyncLifetime
{
    public Task InitializeAsync() => fixture.ResetAsync();
    public Task DisposeAsync() => Task.CompletedTask;

    [Fact]
    public async Task Crud_preserves_contract_location_and_persisted_changes()
    {
        var client = fixture.Client;
        using var empty = await client.GetAsync("/api/tasks");
        Assert.Equal(HttpStatusCode.OK, empty.StatusCode);
        Assert.Empty(await empty.Content.ReadFromJsonAsync<JsonElement[]>() ?? throw new InvalidOperationException());

        using var post = await client.PostAsJsonAsync("/api/tasks", new { title = "  Integration task  ", description = (string?)null });
        Assert.Equal(HttpStatusCode.Created, post.StatusCode);
        var created = await post.Content.ReadFromJsonAsync<JsonElement>();
        AssertTaskContract(created);
        var id = created.GetProperty("id").GetInt32();
        Assert.True(id > 0);
        Assert.Equal($"/api/tasks/{id}", post.Headers.Location?.OriginalString);
        Assert.Equal("Integration task", created.GetProperty("title").GetString());
        Assert.Equal(JsonValueKind.Null, created.GetProperty("description").ValueKind);
        Assert.False(created.GetProperty("isCompleted").GetBoolean());
        Assert.Equal(created.GetProperty("createdAt").GetDateTimeOffset(), created.GetProperty("updatedAt").GetDateTimeOffset());

        using var get = await client.GetAsync($"/api/tasks/{id}");
        Assert.Equal(HttpStatusCode.OK, get.StatusCode);
        Assert.Equal(created.GetRawText(), (await get.Content.ReadFromJsonAsync<JsonElement>()).GetRawText());

        using var populated = await client.GetAsync("/api/tasks");
        Assert.Equal(HttpStatusCode.OK, populated.StatusCode);
        var list = await populated.Content.ReadFromJsonAsync<JsonElement[]>();
        Assert.Equal(id, Assert.Single(list!).GetProperty("id").GetInt32());

        using var put = await client.PutAsJsonAsync($"/api/tasks/{id}", new { title = "  Updated task  ", description = "Details", isCompleted = true });
        Assert.Equal(HttpStatusCode.OK, put.StatusCode);
        var updated = await put.Content.ReadFromJsonAsync<JsonElement>();
        AssertTaskContract(updated);
        Assert.Equal(id, updated.GetProperty("id").GetInt32());
        Assert.Equal("Updated task", updated.GetProperty("title").GetString());
        Assert.Equal("Details", updated.GetProperty("description").GetString());
        Assert.True(updated.GetProperty("isCompleted").GetBoolean());
        Assert.Equal(created.GetProperty("createdAt").GetDateTimeOffset(), updated.GetProperty("createdAt").GetDateTimeOffset());
        Assert.True(updated.GetProperty("updatedAt").GetDateTimeOffset() >= created.GetProperty("updatedAt").GetDateTimeOffset());

        using var updatedList = await client.GetAsync("/api/tasks");
        Assert.Equal(HttpStatusCode.OK, updatedList.StatusCode);
        Assert.Equal(updated.GetRawText(), Assert.Single((await updatedList.Content.ReadFromJsonAsync<JsonElement[]>())!).GetRawText());

        using var reread = await client.GetAsync($"/api/tasks/{id}");
        Assert.Equal(HttpStatusCode.OK, reread.StatusCode);
        Assert.Equal(updated.GetRawText(), (await reread.Content.ReadFromJsonAsync<JsonElement>()).GetRawText());

        using var delete = await client.DeleteAsync($"/api/tasks/{id}");
        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);
        Assert.Empty(await delete.Content.ReadAsByteArrayAsync());
        using var gone = await client.GetAsync($"/api/tasks/{id}");
        Assert.Equal(HttpStatusCode.NotFound, gone.StatusCode);
        using var finalList = await client.GetAsync("/api/tasks");
        Assert.Equal(HttpStatusCode.OK, finalList.StatusCode);
        Assert.Empty((await finalList.Content.ReadFromJsonAsync<JsonElement[]>())!);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("Details")]
    public async Task Create_preserves_nullable_or_empty_description(string? description)
    {
        using var response = await fixture.Client.PostAsJsonAsync("/api/tasks", new { title = "Task", description });
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var item = await response.Content.ReadFromJsonAsync<JsonElement>();
        AssertTaskContract(item);
        Assert.Equal(description, item.GetProperty("description").GetString());
        using var get = await fixture.Client.GetAsync(response.Headers.Location);
        Assert.Equal(HttpStatusCode.OK, get.StatusCode);
        Assert.Equal(description, (await get.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("description").GetString());
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData(" \t ")]
    public async Task Blank_title_is_rejected_without_creating_or_changing_task(string? title)
    {
        using var created = await fixture.Client.PostAsJsonAsync("/api/tasks", new { title = "Original", description = "Keep" });
        Assert.Equal(HttpStatusCode.Created, created.StatusCode);
        var location = created.Headers.Location;
        using var invalidPost = await fixture.Client.PostAsJsonAsync("/api/tasks", new { title });
        using var invalidPut = await fixture.Client.PutAsJsonAsync(location, new { title, description = (string?)null, isCompleted = true });
        foreach (var response in new[] { invalidPost, invalidPut })
        {
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
            var problem = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal("Title is required.", problem.GetProperty("errors").GetProperty("title")[0].GetString());
        }
        using var get = await fixture.Client.GetAsync(location);
        Assert.Equal(HttpStatusCode.OK, get.StatusCode);
        var unchanged = await get.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("Original", unchanged.GetProperty("title").GetString());
        Assert.Equal("Keep", unchanged.GetProperty("description").GetString());
        Assert.False(unchanged.GetProperty("isCompleted").GetBoolean());
        using var list = await fixture.Client.GetAsync("/api/tasks");
        Assert.Equal(HttpStatusCode.OK, list.StatusCode);
        Assert.Single((await list.Content.ReadFromJsonAsync<JsonElement[]>())!);
    }

    [Theory]
    [InlineData("GET")]
    [InlineData("PUT")]
    [InlineData("DELETE")]
    public async Task Missing_task_returns_404(string method)
    {
        using var request = new HttpRequestMessage(new HttpMethod(method), "/api/tasks/2147483647");
        if (method == "PUT") request.Content = JsonContent.Create(new { title = "Missing", description = (string?)null, isCompleted = true });
        using var response = await fixture.Client.SendAsync(request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Malformed_json_returns_400_without_writing_a_task()
    {
        using var response = await fixture.Client.PostAsync("/api/tasks", new StringContent("{", Encoding.UTF8, "application/json"));
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        using var list = await fixture.Client.GetAsync("/api/tasks");
        Assert.Equal(HttpStatusCode.OK, list.StatusCode);
        Assert.Empty((await list.Content.ReadFromJsonAsync<JsonElement[]>())!);
    }

    [Fact]
    public async Task Legacy_nullable_updated_at_falls_back_to_created_at()
    {
        var createdAt = new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);
        var entity = new TaskEntity { Title = "Legacy", CreatedAt = createdAt, UpdatedAt = null };
        using (var scope = fixture.Factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Tasks.Add(entity);
            await db.SaveChangesAsync();
        }
        using var response = await fixture.Client.GetAsync($"/api/tasks/{entity.Id}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var item = await response.Content.ReadFromJsonAsync<JsonElement>();
        AssertTaskContract(item);
        Assert.Equal(createdAt, item.GetProperty("updatedAt").GetDateTimeOffset());
    }

    private static void AssertTaskContract(JsonElement item)
    {
        Assert.Equal(new[] { "createdAt", "description", "id", "isCompleted", "title", "updatedAt" },
            item.EnumerateObject().Select(property => property.Name).Order().ToArray());
        Assert.Equal(JsonValueKind.Number, item.GetProperty("id").ValueKind);
        Assert.Equal(JsonValueKind.String, item.GetProperty("title").ValueKind);
        Assert.True(item.GetProperty("isCompleted").ValueKind is JsonValueKind.True or JsonValueKind.False);
        Assert.True(item.GetProperty("description").ValueKind is JsonValueKind.String or JsonValueKind.Null);
        Assert.Equal(TimeSpan.Zero, item.GetProperty("createdAt").GetDateTimeOffset().Offset);
        Assert.Equal(TimeSpan.Zero, item.GetProperty("updatedAt").GetDateTimeOffset().Offset);
    }
}
