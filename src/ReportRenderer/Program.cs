/*
 * Program.cs  —  ReportRenderer
 * ─────────────────────────────────────────────────────────────────────────────
 * Entry point untuk C# Microsoft RDLC Font Renderer.
 *
 * Usage:
 *   ReportRenderer.exe <font_name> <output.pdf>
 *   ReportRenderer.exe                             ← demo mode (Inter + Segoe UI)
 *
 * Build:  dotnet publish -r win-x64 --self-contained
 * Run:    wine /app/rdlc_publish/ReportRenderer.exe "Inter" "Z:\app\output\rdlc_inter.pdf"
 *
 * Mirrors entrypoint production:
 *   Xvfb :99 & DISPLAY=:99 wine64 dotnet Siloam.PaymentSystem.Report.dll
 * ─────────────────────────────────────────────────────────────────────────────
 */

namespace ReportRenderer;

class Program
{
    static int Main(string[] args)
    {
        Console.WriteLine("========================================");
        Console.WriteLine("  C# Microsoft RDLC Font Renderer");
        Console.WriteLine("========================================");

        string outputPath;

        if (args.Length >= 1)
        {
            // Path eksplisit dari CLI / Docker entrypoint
            // Contoh: wine ReportRenderer.exe 'Z:\app\output\rdlc_output.pdf'
            outputPath = args[0];
        }
        else
        {
            

            outputPath = "Reports/demo_report.pdf";
            Console.WriteLine($"  [Demo] Output file: {outputPath}");
        }

        return RenderAndSave(outputPath) ? 0 : 1;
    }

    private static bool RenderAndSave(string outputPath)
    {
        Console.WriteLine($"  → Output: '{outputPath}'");

        var data = ReportService.RenderReport();

        if (data.Length == 0)
        {
            Console.Error.WriteLine("    [FAIL] Render menghasilkan data kosong");
            return false;
        }

        try
        {
            // Jalankan di Wine: outputPath adalah Windows path (Z:\app\output\x.pdf)
            // File.WriteAllBytes di dalam Wine process langsung pakai Windows path
            string? dir = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(dir))
            {
                Console.WriteLine($"    [DBG] CreateDirectory: {dir}");
                Directory.CreateDirectory(dir);
            }

            Console.WriteLine($"    [DBG] Writing {data.Length} bytes to: {outputPath}");
            File.WriteAllBytes(outputPath, data);

            Console.WriteLine($"[RDLC OK] Size: {data.Length:N0} bytes | Output: {outputPath}");
            return true;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"    [FAIL] Gagal menyimpan: {ex.Message}");
            return false;
        }
    }
}
