namespace K.Switchboard.Tests;

/// <summary>Fake-Implementierung von <see cref="IOptionsMonitor{T}"/> für Unit-Tests.</summary>
internal sealed class FakeOptionsMonitor<T>(T value) : IOptionsMonitor<T>
{
    public T CurrentValue => value;
    public T Get(string? name) => value;
    public IDisposable? OnChange(Action<T, string?> listener) => null;
}

/// <summary>Mock-<see cref="HttpMessageHandler"/> für Unit-Tests.</summary>
internal sealed class MockHttpHandler(
    Action<HttpRequestMessage>? onRequest = null,
    HttpStatusCode statusCode = HttpStatusCode.OK,
    string responseBody = "{}",
    string responseContentType = "application/json") : HttpMessageHandler
{
    protected override async Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        if (onRequest is not null)
            await Task.Run(() => onRequest(request), cancellationToken);

        return new HttpResponseMessage(statusCode)
        {
            Content = new StringContent(responseBody, Encoding.UTF8, responseContentType)
        };
    }
}

/// <summary>
/// Vereinfachte <see cref="IHttpClientFactory"/>-Implementierung für Unit-Tests —
/// gibt denselben <see cref="HttpClient"/> für jeden Namen zurück.
/// </summary>
internal sealed class SingleClientFactory(HttpClient client) : IHttpClientFactory
{
    public HttpClient CreateClient(string name) => client;
}
