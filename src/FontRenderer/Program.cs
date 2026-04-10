/*
 * Program.cs
 * ─────────────────────────────────────────────────────────────────────────────
 * Entry point untuk C# GDI+ Font Renderer.
 *
 * Usage:
 *   FontRenderer.exe <font_name> <output.bmp>
 *   FontRenderer.exe                             ← demo mode (Inter + Segoe UI)
 *
 * Dikompilasi dengan: dotnet publish -r win-x64 --self-contained
 * Dijalankan dengan:  wine FontRenderer.exe "Inter" "Z:\app\output\cs_inter.bmp"
 * ─────────────────────────────────────────────────────────────────────────────
 */

namespace FontRenderer;

class Program
{
    static int Main(string[] args)
    {
        Console.WriteLine("========================================");
        Console.WriteLine("  C# GDI+ Font Renderer (System.Drawing)");
        Console.WriteLine("========================================");

        if (args.Length == 2)
        {
            // Mode: <font_name> <output_path>
            return BitmapRenderer.RenderFontToBmp(args[0], args[1]) ? 0 : 1;
        }

        if (args.Length != 0)
        {
            Console.Error.WriteLine("Usage: FontRenderer.exe <font_name> <output.bmp>");
            return 1;
        }

        // Demo mode — render Inter dan Segoe UI (mirror demo mode di render_wine.c)
        Console.WriteLine("Usage: FontRenderer.exe <font_name> <output.bmp>");
        Console.WriteLine();
        Console.WriteLine("Demo mode: render Inter dan Segoe UI...");
        Console.WriteLine();

        BitmapRenderer.RenderFontToBmp("Inter",    @"Z:\app\output\cs_inter.bmp");
        BitmapRenderer.RenderFontToBmp("Segoe UI", @"Z:\app\output\cs_segoeui.bmp");

        return 0;
    }
}
