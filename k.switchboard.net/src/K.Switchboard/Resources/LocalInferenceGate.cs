namespace K.Switchboard.Resources;

/// <summary>Serialisiert lokale Inferenz: nie zwei gleichzeitige Ollama-Läufe (Spec §3.6.2).</summary>
public sealed class LocalInferenceGate : IDisposable
{
    private readonly SemaphoreSlim _semaphore = new(1, 1);

    /// <summary>Belegt den Slot; das zurückgegebene <see cref="IDisposable"/> gibt ihn frei.</summary>
    public async Task<IDisposable> AcquireAsync(CancellationToken ct)
    {
        await _semaphore.WaitAsync(ct);
        return new Releaser(_semaphore);
    }

    public void Dispose() => _semaphore.Dispose();

    private sealed class Releaser(SemaphoreSlim sem) : IDisposable
    {
        private int _released;
        public void Dispose()
        {
            if (Interlocked.Exchange(ref _released, 1) == 0)
                sem.Release();
        }
    }
}
