/*
 * BitmapRenderer.cs
 * ─────────────────────────────────────────────────────────────────────────────
 * C# equivalent dari render_wine.c — menggunakan SkiaSharp untuk:
 *   1. Meminta font tertentu (misal: "Inter" atau "Segoe UI")
 *   2. Menggambar teks ke Bitmap memori (SKBitmap / SKCanvas)
 *   3. Melaporkan font yang BENAR-BENAR digunakan via SKTypeface.FamilyName
 *      → Mirror persis GetTextFaceA di render_wine.c:
 *        - font ditemukan  → actual == requested
 *        - tidak ditemukan → Skia substitusi, actual != requested
 *   4. Menyimpan hasil sebagai file BMP
 *
 * Berjalan NATIVE di Linux (tidak perlu Wine) — jauh lebih cepat.
 * Font diambil dari system fontconfig (sama seperti Pillow di render_debian.py).
 * ─────────────────────────────────────────────────────────────────────────────
 */

using SkiaSharp;

namespace FontRenderer;

public static class BitmapRenderer
{
    // ── Konstanta dimensi (sama seperti render_wine.c) ───────────────────────
    private const int W = 960;
    private const int H = 280;

    // ── Warna tema (identik dengan C code) ───────────────────────────────────
    private static readonly SKColor AccentBlue  = new(70,  130, 200);
    private static readonly SKColor StatusGreen = new(34,  139, 34);
    private static readonly SKColor StatusRed   = new(180, 30,  30);

    // ─────────────────────────────────────────────────────────────────────────
    /// <summary>
    /// Render <paramref name="fontName"/> ke file BMP di <paramref name="outputPath"/>.
    /// </summary>
    public static bool RenderFontToBmp(string fontName, string outputPath)
    {
        // ── Resolusi font (mirror GetTextFaceA) ──────────────────────────────
        // SKTypeface.FromFamilyName melakukan substitusi sama seperti GDI:
        // kalau font tidak ada, Skia pakai fallback dan FamilyName berubah.
        using var typeface  = SKTypeface.FromFamilyName(fontName) ?? SKTypeface.Default;
        string    actualFace = typeface.FamilyName;
        bool      matched    = string.Equals(fontName, actualFace,
                                    StringComparison.OrdinalIgnoreCase);

        using var bitmap = new SKBitmap(W, H, SKColorType.Bgra8888, SKAlphaType.Premul);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.White);

        DrawBorder(canvas);
        DrawHeaderBar(canvas, fontName);
        DrawMainText(canvas, typeface);
        DrawInfoLines(canvas, typeface, fontName, actualFace, matched, outputPath);
        DrawStatusBar(canvas, fontName, actualFace, matched);

        return SaveBmp(bitmap, outputPath, fontName, actualFace, matched);
    }

    // ── Drawing helpers ──────────────────────────────────────────────────────

    private static void DrawBorder(SKCanvas canvas)
    {
        using var paint = new SKPaint
        {
            Style       = SKPaintStyle.Stroke,
            Color       = AccentBlue,
            StrokeWidth = 3,
            IsAntialias = true,
        };
        canvas.DrawRect(SKRect.Create(4, 4, W - 8, H - 8), paint);
    }

    private static void DrawHeaderBar(SKCanvas canvas, string fontName)
    {
        using var barPaint = new SKPaint { Color = AccentBlue, Style = SKPaintStyle.Fill };
        canvas.DrawRect(SKRect.Create(5, 5, W - 10, 37), barPaint);

        using var tf   = SKTypeface.FromFamilyName("Arial", SKFontStyle.Bold);
        using var font = new SKFont(tf, 14);
        using var txt  = new SKPaint { Color = SKColors.White, IsAntialias = true };
        canvas.DrawText(
            $"  C# SkiaSharp Font Test  |  Requested: \"{fontName}\"",
            10, 26, font, txt);
    }

    private static void DrawMainText(SKCanvas canvas, SKTypeface typeface)
    {
        using var font = new SKFont(typeface, 36);
        using var txt  = new SKPaint { Color = new SKColor(20, 20, 20), IsAntialias = true };
        canvas.DrawText("The quick brown fox  0123456789", 18, 95, font, txt);
    }

    private static void DrawInfoLines(
        SKCanvas  canvas,
        SKTypeface typeface,
        string    fontName,
        string    actualFace,
        bool      matched,
        string    outputPath)
    {
        using var font = new SKFont(typeface, 11);
        using var txt  = new SKPaint { Color = new SKColor(60, 60, 60), IsAntialias = true };

        string matchStr = matched ? "YES ✓" : "NO  ✗ (substituted)";

        canvas.DrawText(
            $"Requested: \"{fontName}\"    Actual (FamilyName): \"{actualFace}\"    Match: {matchStr}",
            18, 148, font, txt);

        canvas.DrawText(
            $"Metrics — Ascent: {font.Metrics.Ascent:F0}  Descent: {font.Metrics.Descent:F0}" +
            $"  Leading: {font.Metrics.Leading:F0}  Size: {font.Size}",
            18, 170, font, txt);

        canvas.DrawText(
            $"Rendered via C# SkiaSharp on Debian Linux  |  Output: {outputPath}",
            18, 192, font, txt);
    }

    private static void DrawStatusBar(
        SKCanvas canvas,
        string   fontName,
        string   actualFace,
        bool     matched)
    {
        using var barPaint = new SKPaint
        {
            Color = matched ? StatusGreen : StatusRed,
            Style = SKPaintStyle.Fill,
        };
        canvas.DrawRect(SKRect.Create(5, H - 48, W - 10, 43), barPaint);

        using var tf   = SKTypeface.FromFamilyName("Arial", SKFontStyle.Bold);
        using var font = new SKFont(tf, 14);
        using var txt  = new SKPaint { Color = SKColors.White, IsAntialias = true };

        string msg = matched
            ? $"  [OK] Font '{fontName}' FOUND dan digunakan oleh SkiaSharp!"
            : $"  [WARN] Font '{fontName}' TIDAK ditemukan → Skia substitusi dengan '{actualFace}'";
        canvas.DrawText(msg, 10, H - 22, font, txt);
    }

    // ── Simpan sebagai BMP & cetak summary ───────────────────────────────────
    private static bool SaveBmp(
        SKBitmap bitmap,
        string   outputPath,
        string   fontName,
        string   actualFace,
        bool     matched)
    {
        try
        {
            string? dir = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            using var data   = bitmap.Encode(SKEncodedImageFormat.Bmp, 100);
            using var stream = File.OpenWrite(outputPath);
            data.SaveTo(stream);

            Console.WriteLine(
                $"[C# Skia]  Font: {fontName,-20} | Actual: {actualFace,-20} | Match: " +
                (matched ? "YES" : "NO (substituted)"));
            Console.WriteLine($"           Output: {outputPath}");
            return true;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[C# Skia]  ERROR: Cannot save '{outputPath}': {ex.Message}");
            return false;
        }
    }
}


    [DllImport("gdi32.dll", EntryPoint = "SelectObject")]
    private static extern nint SelectObject(nint hdc, nint hgdiobj);

    [DllImport("gdi32.dll", EntryPoint = "DeleteObject")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DeleteObject(nint hObject);

    // ── Konstanta dimensi bitmap (sama seperti di render_wine.c) ────────────
    private const int W = 960;
    private const int H = 280;

    // ── Warna tema (sama persis dengan C code) ───────────────────────────────
    private static readonly Color AccentBlue  = Color.FromArgb(70, 130, 200);
    private static readonly Color StatusGreen = Color.FromArgb(34, 139, 34);
    private static readonly Color StatusRed   = Color.FromArgb(180, 30, 30);

    // ─────────────────────────────────────────────────────────────────────────
    /// <summary>
    /// Render <paramref name="fontName"/> ke file BMP di <paramref name="outputPath"/>.
    /// </summary>
    /// <returns><c>true</c> jika berhasil.</returns>
    public static bool RenderFontToBmp(string fontName, string outputPath)
    {
        using var bmp = new Bitmap(W, H, PixelFormat.Format32bppArgb);
        using var gfx = Graphics.FromImage(bmp);

        gfx.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;
        gfx.Clear(Color.White);

        DrawBorder(gfx);
        DrawHeaderBar(gfx, fontName);

        // ── Resolusi font via GetTextFace (P/Invoke, sama dengan C code) ────
        string actualFace = ResolveActualFace(fontName);
        bool   matched    = string.Equals(fontName, actualFace,
                                StringComparison.OrdinalIgnoreCase);

        DrawMainText(gfx, fontName);
        DrawInfoLines(gfx, fontName, actualFace, matched, outputPath);
        DrawStatusBar(gfx, fontName, actualFace, matched);

        return SaveBmp(bmp, outputPath, fontName, actualFace, matched);
    }

    // ── Drawing helpers ──────────────────────────────────────────────────────

    private static void DrawBorder(Graphics gfx)
    {
        using var pen = new Pen(AccentBlue, 3);
        gfx.DrawRectangle(pen, 4, 4, W - 8, H - 8);
    }

    private static void DrawHeaderBar(Graphics gfx, string fontName)
    {
        // Bar biru
        using var barBrush = new SolidBrush(AccentBlue);
        gfx.FillRectangle(barBrush, 5, 5, W - 10, 37);

        // Teks header (putih, bold, Arial — sama seperti di C)
        using var font  = new Font("Arial", 14, FontStyle.Bold);
        using var brush = new SolidBrush(Color.White);
        gfx.DrawString(
            $"  C# System.Drawing / GDI+ Font Test  |  Requested: \"{fontName}\"",
            font, brush, 10f, 12f);
    }

    private static void DrawMainText(Graphics gfx, string fontName)
    {
        // GDI+ akan substitusi font secara otomatis kalau tidak ada
        // (sama dengan CreateFont + TextOut di C — tidak throw exception)
        using var font  = new Font(fontName, 36, FontStyle.Regular);
        using var brush = new SolidBrush(Color.FromArgb(20, 20, 20));
        gfx.DrawString("The quick brown fox  0123456789", font, brush, 18f, 55f);
    }

    private static void DrawInfoLines(
        Graphics gfx,
        string fontName,
        string actualFace,
        bool   matched,
        string outputPath)
    {
        using var font  = new Font(fontName, 11, FontStyle.Regular);
        using var brush = new SolidBrush(Color.FromArgb(60, 60, 60));

        string matchStr = matched ? "YES ✓" : "NO  ✗ (substituted)";
        bool   avail    = IsFontAvailable(fontName);

        gfx.DrawString(
            $"Requested: \"{fontName}\"    Actual (GetTextFace): \"{actualFace}\"    Match: {matchStr}",
            font, brush, 18f, 130f);

        gfx.DrawString(
            $"FontFamily available: {avail}    Renderer: C# System.Drawing / GDI+",
            font, brush, 18f, 158f);

        gfx.DrawString(
            $"Rendered via C# on Wine (Debian Linux)  |  Output: {outputPath}",
            font, brush, 18f, 186f);
    }

    private static void DrawStatusBar(
        Graphics gfx,
        string fontName,
        string actualFace,
        bool   matched)
    {
        using var barBrush = new SolidBrush(matched ? StatusGreen : StatusRed);
        gfx.FillRectangle(barBrush, 5, H - 48, W - 10, 43);

        using var font  = new Font("Arial", 14, FontStyle.Bold);
        using var brush = new SolidBrush(Color.White);
        string msg = matched
            ? $"  [OK] Font '{fontName}' FOUND dan digunakan oleh GDI+!"
            : $"  [WARN] Font '{fontName}' TIDAK ditemukan → GDI+ substitusi dengan '{actualFace}'";

        gfx.DrawString(msg, font, brush, 10f, H - 38f);
    }

    // ── GetTextFace via P/Invoke ─────────────────────────────────────────────
    /// <summary>
    /// Mengembalikan nama font yang <em>benar-benar</em> dipakai GDI
    /// setelah SelectObject (mirror persis GetTextFaceA di render_wine.c).
    /// </summary>
    private static string ResolveActualFace(string fontName)
    {
        try
        {
            // Buat DC sementara dari 1×1 bitmap — tidak perlu display fisik
            using var tmpBmp = new Bitmap(1, 1);
            using var tmpGfx = Graphics.FromImage(tmpBmp);
            using var font   = new Font(fontName, 12, FontStyle.Regular);

            nint hFont = font.ToHfont();
            nint hdc   = tmpGfx.GetHdc();
            try
            {
                nint hOld = SelectObject(hdc, hFont);

                var sb = new StringBuilder(64);
                GetTextFace(hdc, sb.Capacity, sb);

                SelectObject(hdc, hOld);     // restore DC
                return sb.Length > 0 ? sb.ToString() : fontName;
            }
            finally
            {
                tmpGfx.ReleaseHdc(hdc);
                DeleteObject(hFont);
            }
        }
        catch
        {
            // Kalau P/Invoke gagal (misal: bukan di Wine), fallback ke nama asli
            return fontName;
        }
    }

    // ── Cek ketersediaan FontFamily ──────────────────────────────────────────
    private static bool IsFontAvailable(string fontName)
    {
        try
        {
            using var _ = new FontFamily(fontName);
            return true;
        }
        catch
        {
            return false;
        }
    }

    // ── Simpan BMP & cetak summary ───────────────────────────────────────────
    private static bool SaveBmp(
        Bitmap bmp,
        string outputPath,
        string fontName,
        string actualFace,
        bool   matched)
    {
        try
        {
            string? dir = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                Directory.CreateDirectory(dir);

            bmp.Save(outputPath, ImageFormat.Bmp);

            Console.WriteLine(
                $"[C# GDI+] Font: {fontName,-20} | Actual: {actualFace,-20} | Match: " +
                (matched ? "YES" : "NO (substituted)"));
            Console.WriteLine($"           Output: {outputPath}");
            return true;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"[C# GDI+] ERROR: Cannot save '{outputPath}': {ex.Message}");
            return false;
        }
    }
}
