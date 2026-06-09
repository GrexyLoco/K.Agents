namespace K.Switchboard.Resources;

using System.Diagnostics;

/// <summary>Produktive <see cref="IProcessController"/>-Implementierung über System.Diagnostics.Process.
/// <c>PriorityClass = BelowNormal</c> ist cross-platform (Windows: BELOW_NORMAL; Linux: positiver nice-Wert,
/// Senken braucht keine root-Rechte). Alle Operationen sind best-effort (schlucken Exceptions).</summary>
public sealed class ProcessController : IProcessController
{
    public IReadOnlyList<int> FindByName(string processName)
    {
        try
        {
            return Process.GetProcessesByName(processName).Select(p => p.Id).ToArray();
        }
        catch
        {
            return [];
        }
    }

    public bool TrySetBelowNormal(int pid)
    {
        try
        {
            using var proc = Process.GetProcessById(pid);
            proc.PriorityClass = ProcessPriorityClass.BelowNormal;
            return true;
        }
        catch
        {
            return false;
        }
    }
}
