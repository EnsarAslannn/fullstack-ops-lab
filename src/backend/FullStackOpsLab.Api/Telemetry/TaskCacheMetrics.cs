using System.Diagnostics.Metrics;

namespace FullStackOpsLab.Api.Telemetry;

public sealed class TaskCacheMetrics
{
    public const string MeterName = "FullStackOpsLab.Api.Cache";
    private readonly Counter<long> hits;
    private readonly Counter<long> misses;
    private readonly Counter<long> invalidations;

    public TaskCacheMetrics(IMeterFactory meterFactory)
    {
        var meter = meterFactory.Create(MeterName);
        hits = meter.CreateCounter<long>("fullstackops.cache.hits",
            description: "Task list cache reads that returned a deserialized cached response.");
        misses = meter.CreateCounter<long>("fullstackops.cache.misses",
            description: "Successful Task list cache reads with no cached value.");
        invalidations = meter.CreateCounter<long>("fullstackops.cache.invalidations",
            description: "Task list cache removals completed after successful database mutations.");
    }

    public void Hit() => hits.Add(1);
    public void Miss() => misses.Add(1);
    public void Invalidated() => invalidations.Add(1);
}
