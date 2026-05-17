namespace K.Switchboard.Services;

using System.Threading.Channels;

/// <summary>
/// Hintergrund-Queue für asynchrone Nutzungs-Persistenz mit definiertem Drain beim Shutdown.
/// </summary>
public sealed class UsageRecordingQueue(
    CostingService costing,
    ILogger<UsageRecordingQueue> logger) : BackgroundService
{
    private readonly Channel<UsageRecord> _channel = Channel.CreateUnbounded<UsageRecord>(
        new UnboundedChannelOptions
        {
            SingleReader = true,
            SingleWriter = false,
            AllowSynchronousContinuations = false
        });

    /// <summary>
    /// Legt einen Usage-Eintrag in die Queue.
    /// </summary>
    public bool TryEnqueue(string model, byte[] responseBody)
    {
        if (string.IsNullOrWhiteSpace(model) || responseBody.Length == 0)
            return false;

        // Response-Buffer isolieren, da der Aufrufer den ursprünglichen Array-Inhalt ändern könnte.
        return _channel.Writer.TryWrite(new UsageRecord(model, [.. responseBody]));
    }

    /// <inheritdoc />
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (await _channel.Reader.WaitToReadAsync(CancellationToken.None))
        {
            while (_channel.Reader.TryRead(out var item))
            {
                try
                {
                    await costing.RecordUsageAsync(item.Model, item.ResponseBody);
                }
                catch (Exception ex)
                {
                    logger.LogError(ex,
                        "Nutzungs-Eintrag konnte aus der Queue nicht persistiert werden (Modell: {Model})",
                        item.Model);
                }
            }
        }
    }

    /// <inheritdoc />
    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _channel.Writer.TryComplete();
        await base.StopAsync(cancellationToken);
    }

    private readonly record struct UsageRecord(string Model, byte[] ResponseBody);
}
