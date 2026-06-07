namespace K.Switchboard.Resources;

/// <summary>Resultat-Aktion des ResourceGate.</summary>
public enum RoutingAction
{
    /// <summary>Mit <see cref="RoutingDecision.EffectiveModel"/> weiter an FallbackService.</summary>
    Proceed,

    /// <summary>Hart abbrechen mit <see cref="RoutingDecision.FailStatusCode"/>.</summary>
    Fail
}

/// <summary>Strukturierte Routing-Entscheidung (Spec §3.7). Speist Log + Response-Header.</summary>
public sealed record RoutingDecision
{
    /// <summary>Proceed oder Fail.</summary>
    public RoutingAction Action { get; init; }

    /// <summary>Modell, mit dem FallbackService startet (leer bei Fail).</summary>
    public string EffectiveModel { get; init; } = string.Empty;

    /// <summary>Menschlich lesbarer Grund (Log).</summary>
    public string Reason { get; init; } = string.Empty;

    /// <summary>Wert für den Header <c>X-K-Switchboard-Substitution</c>; null = kein Header.</summary>
    public string? SubstitutionHeader { get; init; }

    /// <summary>HTTP-Status bei <see cref="RoutingAction.Fail"/>.</summary>
    public int FailStatusCode { get; init; } = 503;
}
