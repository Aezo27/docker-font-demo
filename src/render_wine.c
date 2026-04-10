/*
 * render_wine.c
 * ─────────────────────────────────────────────────────────────────────────────
 * Win32 GDI renderer yang dijalankan di bawah Wine di Debian.
 * Program ini:
 *   1. Meminta font tertentu (misal: "Inter" atau "Segoe UI") ke GDI
 *   2. Menggambar teks ke bitmap memori (DIB Section)
 *   3. Melaporkan font yang BENAR-BENAR digunakan (GetTextFace)
 *      → Jika font ditemukan: "Got: Inter"
 *      → Jika tidak ada: GDI substitusi dengan font lain, ketahuan di sini
 *   4. Menyimpan hasil sebagai file BMP
 *
 * Dikompilasi dengan: x86_64-w64-mingw32-gcc
 * Dijalankan dengan:  wine render_wine.exe "Inter" "Z:\app\output\wine_inter.bmp"
 * ─────────────────────────────────────────────────────────────────────────────
 */

#include <windows.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* ── BMP Writer ────────────────────────────────────────────────────────────── */
/* Menulis 32-bit BGRA (top-down) ke file BMP 24-bit (bottom-up).              */
static int write_bmp(const char *path, int width, int height,
                     const unsigned char *pixels_bgra)
{
    int row_stride = (width * 3 + 3) & ~3;
    int img_size   = row_stride * height;
    int file_size  = 14 + 40 + img_size;

    FILE *f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "[Wine] ERROR: Cannot create file: %s\n", path);
        return 0;
    }

    /* File Header: 14 bytes, manual write to avoid struct alignment issues */
    unsigned char fh[14] = {
        'B', 'M',
        (unsigned char)(file_size),        (unsigned char)(file_size >> 8),
        (unsigned char)(file_size >> 16),  (unsigned char)(file_size >> 24),
        0, 0, 0, 0,   /* reserved */
        54, 0, 0, 0   /* pixel data offset = 14 + 40 */
    };
    fwrite(fh, 14, 1, f);

    /* Info Header: 40 bytes (BITMAPINFOHEADER) */
    unsigned char ih[40] = {0};
    ih[0] = 40;   /* biSize */
    ih[4]  = (unsigned char)(width);        ih[5]  = (unsigned char)(width >> 8);
    ih[6]  = (unsigned char)(width >> 16);  ih[7]  = (unsigned char)(width >> 24);
    /* biHeight positif = bottom-up BMP */
    ih[8]  = (unsigned char)(height);       ih[9]  = (unsigned char)(height >> 8);
    ih[10] = (unsigned char)(height >> 16); ih[11] = (unsigned char)(height >> 24);
    ih[12] = 1;   /* biPlanes */
    ih[14] = 24;  /* biBitCount */
    ih[20] = (unsigned char)(img_size);       ih[21] = (unsigned char)(img_size >> 8);
    ih[22] = (unsigned char)(img_size >> 16); ih[23] = (unsigned char)(img_size >> 24);
    fwrite(ih, 40, 1, f);

    /* Pixel data: konversi 32-bit → 24-bit, tulis bottom-up */
    unsigned char *row = (unsigned char *)malloc(row_stride);
    if (!row) { fclose(f); return 0; }
    memset(row, 0, row_stride);

    for (int y = height - 1; y >= 0; y--) {
        const unsigned char *src = pixels_bgra + y * width * 4;
        for (int x = 0; x < width; x++) {
            row[x * 3 + 0] = src[x * 4 + 0]; /* B */
            row[x * 3 + 1] = src[x * 4 + 1]; /* G */
            row[x * 3 + 2] = src[x * 4 + 2]; /* R */
        }
        fwrite(row, row_stride, 1, f);
    }

    free(row);
    fclose(f);
    return 1;
}

/* ── Render satu font ke file BMP ─────────────────────────────────────────── */
static int render_font_to_bmp(const char *font_name, const char *output_path)
{
    int width = 960, height = 280;

    /* ── Buat DIB Section (bitmap di memori, tidak perlu display fisik) ─────── */
    BITMAPINFO bi;
    ZeroMemory(&bi, sizeof(bi));
    bi.bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth       = width;
    bi.bmiHeader.biHeight      = -height; /* negatif = top-down */
    bi.bmiHeader.biPlanes      = 1;
    bi.bmiHeader.biBitCount    = 32;
    bi.bmiHeader.biCompression = BI_RGB;

    void *pBits = NULL;
    HBITMAP hBitmap = CreateDIBSection(NULL, &bi, DIB_RGB_COLORS, &pBits, NULL, 0);
    if (!hBitmap) {
        fprintf(stderr, "[Wine] ERROR: CreateDIBSection gagal (err=%lu)\n",
                GetLastError());
        return 0;
    }

    HDC hDC = CreateCompatibleDC(NULL);
    if (!hDC) {
        fprintf(stderr, "[Wine] ERROR: CreateCompatibleDC gagal\n");
        DeleteObject(hBitmap);
        return 0;
    }

    HBITMAP hOldBmp = (HBITMAP)SelectObject(hDC, hBitmap);

    /* ── Background putih ─────────────────────────────────────────────────── */
    RECT rc = {0, 0, width, height};
    HBRUSH hWhite = CreateSolidBrush(RGB(255, 255, 255));
    FillRect(hDC, &rc, hWhite);
    DeleteObject(hWhite);

    /* ── Border berwarna ─────────────────────────────────────────────────── */
    HPEN hPen = CreatePen(PS_SOLID, 3, RGB(70, 130, 200));
    HPEN hOldPen = (HPEN)SelectObject(hDC, hPen);
    HBRUSH hNull = (HBRUSH)GetStockObject(NULL_BRUSH);
    HBRUSH hOldBrush = (HBRUSH)SelectObject(hDC, hNull);
    Rectangle(hDC, 4, 4, width - 4, height - 4);
    SelectObject(hDC, hOldPen);
    SelectObject(hDC, hOldBrush);
    DeleteObject(hPen);

    /* ── Header bar ──────────────────────────────────────────────────────── */
    RECT header = {5, 5, width - 5, 42};
    HBRUSH hHeaderBrush = CreateSolidBrush(RGB(70, 130, 200));
    FillRect(hDC, &header, hHeaderBrush);
    DeleteObject(hHeaderBrush);

    /* ── Buat font besar dengan nama font yang diminta ─────────────────────── */
    HFONT hFontLarge = CreateFontA(
        58, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
        ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        font_name   /* <── Nama font yang diminta */
    );

    /* ── Font kecil untuk info ─────────────────────────────────────────────── */
    HFONT hFontSmall = CreateFontA(
        20, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
        ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
        font_name
    );

    SetBkMode(hDC, TRANSPARENT);

    /* ── Teks header (putih di atas bar biru) ────────────────────────────── */
    {
        HFONT hFontHeader = CreateFontA(
            22, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
            ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE, "Arial"
        );
        SelectObject(hDC, hFontHeader);
        SetTextColor(hDC, RGB(255, 255, 255));
        char hdr[128];
        snprintf(hdr, sizeof(hdr), "  Wine GDI+ Font Test  |  Requested: \"%s\"", font_name);
        TextOutA(hDC, 10, 12, hdr, (int)strlen(hdr));
        DeleteObject(hFontHeader);
    }

    /* ── Teks utama dengan font yang diminta ────────────────────────────────── */
    SelectObject(hDC, hFontLarge);
    SetTextColor(hDC, RGB(20, 20, 20));
    char main_text[256];
    snprintf(main_text, sizeof(main_text),
             "The quick brown fox  0123456789");
    TextOutA(hDC, 18, 55, main_text, (int)strlen(main_text));

    /* ── Ambil info font yang BENAR-BENAR digunakan GDI ─────────────────────── */
    TEXTMETRICA tm;
    GetTextMetricsA(hDC, &tm);

    char actual_face[LF_FACESIZE] = {0};
    GetTextFaceA(hDC, sizeof(actual_face), actual_face);

    /* ── Apakah font yang diminta == font yang dipakai? ──────────────────────── */
    int font_matched = (lstrcmpiA(font_name, actual_face) == 0);

    /* ── Info baris 1 ─────────────────────────────────────────────────────── */
    SelectObject(hDC, hFontSmall);
    SetTextColor(hDC, RGB(60, 60, 60));

    char info1[256];
    snprintf(info1, sizeof(info1),
             "Requested: \"%s\"    Actual (GetTextFace): \"%s\"    Match: %s",
             font_name, actual_face, font_matched ? "YES ✓" : "NO  ✗ (substituted)");
    TextOutA(hDC, 18, 130, info1, (int)strlen(info1));

    /* ── Info baris 2 ─────────────────────────────────────────────────────── */
    char info2[256];
    snprintf(info2, sizeof(info2),
             "tmHeight=%d  tmWeight=%d  tmItalic=%d  tmCharSet=%d  tmPitchFamily=0x%02X",
             (int)tm.tmHeight, (int)tm.tmWeight,
             (int)tm.tmItalic, (int)tm.tmCharSet, (int)tm.tmPitchAndFamily);
    TextOutA(hDC, 18, 158, info2, (int)strlen(info2));

    /* ── Info baris 3 ─────────────────────────────────────────────────────── */
    char info3[256];
    snprintf(info3, sizeof(info3),
             "Rendered via Wine GDI on Debian Linux  |  Output: %s", output_path);
    TextOutA(hDC, 18, 186, info3, (int)strlen(info3));

    /* ── Status bar berwarna (hijau = OK, merah = font tidak ditemukan) ──────── */
    RECT status_rc = {5, height - 48, width - 5, height - 5};
    COLORREF status_bg = font_matched ? RGB(34, 139, 34) : RGB(180, 30, 30);
    HBRUSH hStatusBrush = CreateSolidBrush(status_bg);
    FillRect(hDC, &status_rc, hStatusBrush);
    DeleteObject(hStatusBrush);

    {
        HFONT hFontStatus = CreateFontA(
            22, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
            ANTIALIASED_QUALITY, DEFAULT_PITCH | FF_DONTCARE, "Arial"
        );
        SelectObject(hDC, hFontStatus);
        SetTextColor(hDC, RGB(255, 255, 255));
        char status_msg[256];
        if (font_matched) {
            snprintf(status_msg, sizeof(status_msg),
                     "  [OK] Font '%s' FOUND dan digunakan oleh Wine GDI!",
                     font_name);
        } else {
            snprintf(status_msg, sizeof(status_msg),
                     "  [WARN] Font '%s' TIDAK ditemukan → GDI substitusi dengan '%s'",
                     font_name, actual_face);
        }
        TextOutA(hDC, 10, height - 38, status_msg, (int)strlen(status_msg));
        DeleteObject(hFontStatus);
    }

    /* ── Selesai menggambar, cleanup DC ──────────────────────────────────── */
    SelectObject(hDC, hOldBmp);
    DeleteObject(hFontLarge);
    DeleteObject(hFontSmall);
    DeleteDC(hDC);

    /* ── Tulis ke file BMP ────────────────────────────────────────────────── */
    int ok = write_bmp(output_path, width, height, (const unsigned char *)pBits);
    DeleteObject(hBitmap);

    if (ok) {
        printf("[Wine GDI] Font: %-20s | Actual: %-20s | Match: %s\n",
               font_name, actual_face, font_matched ? "YES" : "NO (substituted)");
        printf("           Output: %s\n", output_path);
    }

    return ok;
}

/* ── Main ──────────────────────────────────────────────────────────────────── */
int main(int argc, char *argv[])
{
    printf("========================================\n");
    printf("  Wine GDI Font Renderer\n");
    printf("========================================\n");

    if (argc == 3) {
        /* Mode: font_name output_path */
        return render_font_to_bmp(argv[1], argv[2]) ? 0 : 1;
    }

    /* Mode default: render kedua font sekaligus */
    printf("Usage: render_wine.exe <font_name> <output.bmp>\n\n");
    printf("Demo mode: render Inter dan Segoe UI...\n\n");

    render_font_to_bmp("Inter",    "Z:\\app\\output\\wine_inter.bmp");
    render_font_to_bmp("Segoe UI", "Z:\\app\\output\\wine_segoeui.bmp");

    return 0;
}
