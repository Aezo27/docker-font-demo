using Microsoft.Reporting.NETCore;

namespace ReportRenderer;

/// <summary>
/// Helper static — mirror pola ReportUtils di production:
///   - ObjToParameter : konversi DTO → List&lt;ReportParameter&gt;
///   - ReportError    : log exception + parameter saat render gagal
/// </summary>
public static class ReportUtils
{
    // ── Mirror ObjToParameter dari screenshot ───────────────────────────────
    public static List<ReportParameter> ObjToParameter(FontReportParameter param)
    {
        return new List<ReportParameter>
        {
            new ReportParameter("FontName",   param.FontName),
            new ReportParameter("OutputPath", param.OutputPath),
        };
    }

    // ── Mirror ReportError dari screenshot ──────────────────────────────────
    public static void ReportError(
        Exception            ex,
        LocalReport          report,
        List<ReportParameter> parameters)
    {
        Console.Error.WriteLine($"[RDLC ERROR] {ex.GetType().Name}: {ex.Message}");

        if (parameters.Count > 0)
        {
            Console.Error.WriteLine("  Parameters saat error:");
            foreach (var p in parameters)
                Console.Error.WriteLine($"    {p.Name} = {string.Join(", ", p.Values)}");
        }

        if (ex.InnerException is not null)
            Console.Error.WriteLine($"  → Inner: {ex.InnerException.Message}");
    }
}
