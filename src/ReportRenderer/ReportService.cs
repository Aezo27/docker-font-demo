using System.Reflection;
using Microsoft.Reporting.NETCore;

namespace ReportRenderer;

public static class ReportService
{
    private const string ResourceName = "ReportRenderer.Reports.testing.rdl";

    public static byte[] RenderReport()
    {
        byte[]?     reportData = null;
        LocalReport report     = new();

        try
        {
            var asm    = Assembly.GetExecutingAssembly();
            var stream = asm.GetManifestResourceStream(ResourceName);

            if (stream is null)
            {
                Console.Error.WriteLine("[RDLC] Embedded resources tersedia:");
                foreach (var name in asm.GetManifestResourceNames())
                    Console.Error.WriteLine($"  {name}");
                throw new FileNotFoundException($"Embedded resource tidak ditemukan: {ResourceName}");
            }

            using var fs = stream;
            report.LoadReportDefinition(fs);
            report.EnableExternalImages = true;

            reportData = report.Render("PDF");
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[RDLC ERROR] {ex.GetType().Name}: {ex.Message}");
            if (ex.InnerException != null)
                Console.Error.WriteLine($"  Inner: {ex.InnerException.Message}");
        }
        finally
        {
            try { report.Dispose(); } catch { }
        }

        return reportData ?? Array.Empty<byte>();
    }
}
