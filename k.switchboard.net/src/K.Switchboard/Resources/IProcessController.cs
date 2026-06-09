namespace K.Switchboard.Resources;

/// <summary>Testbare Abstraktion für Prozess-Suche + Prioritäts-Senkung (Maschinen-Schutz).</summary>
public interface IProcessController
{
    /// <summary>PIDs aller laufenden Prozesse mit dem (plattform-normalisierten) Namen.</summary>
    IReadOnlyList<int> FindByName(string processName);

    /// <summary>Setzt die Priorität des Prozesses auf below-normal. true = gesetzt, false = nicht möglich
    /// (Prozess weg / fehlende Rechte). Wirft NICHT.</summary>
    bool TrySetBelowNormal(int pid);
}
