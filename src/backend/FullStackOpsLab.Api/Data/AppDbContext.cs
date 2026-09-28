using Microsoft.EntityFrameworkCore;

namespace FullStackOpsLab.Api.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<TaskEntity> Tasks => Set<TaskEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        var task = modelBuilder.Entity<TaskEntity>();

        task.ToTable("tasks");
        task.HasKey(item => item.Id);

        task.Property(item => item.Id)
            .HasColumnName("id")
            .ValueGeneratedOnAdd()
            .UseIdentityByDefaultColumn();

        task.Property(item => item.Title)
            .HasColumnName("title")
            .HasColumnType("text")
            .IsRequired();

        task.Property(item => item.Description)
            .HasColumnName("description")
            .HasColumnType("text");

        task.Property(item => item.IsCompleted)
            .HasColumnName("is_completed")
            .HasDefaultValue(false)
            .IsRequired();

        task.Property(item => item.CreatedAt)
            .HasColumnName("created_at")
            .HasColumnType("timestamp with time zone")
            .IsRequired();

        task.Property(item => item.UpdatedAt)
            .HasColumnName("updated_at")
            .HasColumnType("timestamp with time zone");
    }
}
