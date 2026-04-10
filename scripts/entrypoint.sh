#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  entrypoint.sh  — Main entry point container                                ║
# ║                                                                              ║
# ║  Alur:                                                                       ║
# ║  1. Start Xvfb (virtual display untuk Wine)                                 ║
# ║  2. Init Wine                                                                ║
# ║  3. Setup fonts Debian → Wine (copy + registry)                             ║
# ║  4. Render dengan Debian/Pillow                                              ║
# ║  5. Render dengan Wine/GDI (EXE yang dikompilasi MinGW)                    ║
# ║  6. Verifikasi & convert BMP → PNG                                          ║
# ║  7. Cetak summary                                                            ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── Banner ─────────────────────────────────────────────────────────────────────
banner() {
    local msg="$1"
    local len=${#msg}
    local border
    border=$(printf '═%.0s' $(seq 1 $((len + 4))))
    echo ""
    echo "╔${border}╗"
    echo "║  ${msg}  ║"
    echo "╚${border}╝"
}

step() { echo ""; echo "── $1"; }

banner "Docker Font Demo: Debian + Wine GDI+"
echo "  Tujuan: Membuktikan font Inter & Segoe UI yang diinstall"
echo "  di Debian tersedia juga di Wine untuk GDI+ printing."
echo ""
echo "  WINEPREFIX : $WINEPREFIX"
echo "  WINEARCH   : $WINEARCH"
echo "  Output dir : /app/output"

# ── 1. Virtual Display (Xvfb) ─────────────────────────────────────────────────
banner "Step 1: Start Virtual Display (Xvfb)"
Xvfb :99 -screen 0 1920x1080x24 -ac +extension GLX 2>/dev/null &
XVFB_PID=$!
export DISPLAY=:99
sleep 1

if kill -0 "$XVFB_PID" 2>/dev/null; then
    echo "[OK] Xvfb berjalan (PID=$XVFB_PID, DISPLAY=$DISPLAY)"
else
    echo "[FAIL] Xvfb gagal start — Wine GDI mungkin tidak bekerja"
fi

# Cleanup saat container exit
cleanup() {
    echo ""
    echo "[Cleanup] Menghentikan Xvfb..."
    kill "$XVFB_PID" 2>/dev/null || true
}
trap cleanup EXIT

# ── 2. Wine Initialization ─────────────────────────────────────────────────────
banner "Step 2: Inisialisasi Wine"
echo "Menjalankan wineboot --init (pertama kali bisa butuh waktu)..."
# WINEDLLOVERRIDES: suppress popup Mono/Gecko installer
WINEDLLOVERRIDES="mscoree,mshtml=" \
WINEDEBUG=-all \
wine wineboot --init 2>/dev/null
sleep 3
echo "[OK] Wine diinisialisasi"
echo "     Wine version: $(WINEDEBUG=-all wine --version 2>/dev/null || echo 'unknown')"

# ── Install gdiplus asli Microsoft via winetricks ─────────────────────────────
# Wine built-in gdiplus.dll tidak stabil untuk GDI+ rendering (SEHException).
# winetricks mendownload dan menginstall gdiplus.dll resmi dari Microsoft.
echo "Menginstall gdiplus via winetricks (diperlukan untuk font rendering)..."
WINEDEBUG=-all DISPLAY=:99 winetricks -q gdiplus 2>/dev/null \
    && echo "[OK] gdiplus diinstall" \
    || echo "[WARN] winetricks gdiplus gagal — lanjut tanpa override"

# ── 3. Font Setup: Debian → Wine ──────────────────────────────────────────────
banner "Step 3: Sinkronisasi Font Debian → Wine"
echo "Menyalin font dari /usr/share/fonts/ ke Wine dan mendaftarkannya..."
/app/scripts/setup_wine_fonts.sh

# ── Info: Font di sistem Debian ────────────────────────────────────────────────
step "Font di sistem Debian (fc-list, filter inter|segoe):"
fc-list | grep -i -E "inter|segoe" | sort | while read -r line; do
    echo "  $line"
done
[[ $(fc-list | grep -i -E "inter|segoe" | wc -l) -eq 0 ]] && echo "  (tidak ada)" || true

# ── Info: Wine Fonts directory ──────────────────────────────────────────────────
step "File di Wine Fonts directory (filter inter|segoe):"
WINE_FONTS_DIR="${WINEPREFIX}/drive_c/windows/Fonts"
find "$WINE_FONTS_DIR" \( -iname "*inter*" -o -iname "*segoe*" \) 2>/dev/null \
    | sort | while read -r f; do echo "  $(basename "$f")"; done
[[ $(find "$WINE_FONTS_DIR" \( -iname "*inter*" -o -iname "*segoe*" \) 2>/dev/null | wc -l) -eq 0 ]] \
    && echo "  (tidak ada)" || true

# ── 4. Render Debian (Python + Pillow) ─────────────────────────────────────────
banner "Step 4: Render Teks — Debian (Python + Pillow)"
echo "Menggunakan fontconfig untuk mencari TTF dan merender dengan Pillow..."
python3 /app/src/render_debian.py

# ── 5. Render Wine (Win32 GDI EXE) ─────────────────────────────────────────────
banner "Step 5: Render Teks — Wine (Win32 GDI via .exe)"
echo "Menjalankan render_wine.exe di bawah Wine..."
echo "  EXE ini dikompilasi dengan MinGW (x86_64-w64-mingw32-gcc)"
echo "  Menggunakan GDI: CreateFont, TextOut, GetTextFace"
echo ""

run_wine() {
    local font="$1"
    local out_win="$2"  # Windows-style path (Z:\ = /)
    echo "  → Font: '$font'"
    if WINEDEBUG=-all wine /app/render_wine.exe "$font" "$out_win" 2>/dev/null; then
        echo "    [OK]"
    else
        echo "    [WARN] Wine process error (font mungkin tidak ditemukan)"
    fi
}

# Z:\ di Wine = / di Linux, jadi Z:\app\output\ = /app/output/
run_wine "Inter"    'Z:\app\output\wine_inter.bmp'
run_wine "Segoe UI" 'Z:\app\output\wine_segoeui.bmp'

# ── 5b. Render C# RDLC / Microsoft.Reporting.NETCore (via wine64 dotnet.exe) ─
banner "Step 5b: Render Teks — C# RDLC (Microsoft.Reporting.NETCore via wine64)"
echo "Menjalankan ReportRenderer.dll via wine64 + Windows .NET runtime..."
echo "  Mirrors production: DISPLAY=:99 wine64 dotnet Siloam.PaymentSystem.Report.dll"
echo "  Windows .NET runtime: C:\\dotnet\\dotnet.exe (di Wine prefix)"
echo "  Menggunakan: Microsoft.Reporting.NETCore | LocalReport.Render(\"PDF\")"
echo "  Wine menyediakan usp10.dll (Uniscribe) untuk text layout PDF ✓"
echo "  RDL: Reports/testing.rdl (embedded resource)"
echo ""

# wine (WINEARCH=win64) + Windows .NET = usp10.dll tersedia dari Wine Uniscribe (Wine >= 5.0)
# Catatan: Debian bookworm tidak punya binary 'wine64'; 'wine' dengan WINEARCH=win64 adalah ekuivalennya
if DISPLAY=:99 WINEDEBUG=-all \
   wine 'C:\dotnet\dotnet.exe' \
          'Z:\app\rdlc_win\ReportRenderer.dll' \
          'Z:\app\output\rdlc_output.pdf'; then
    echo "  [OK]"
else
    echo "  [WARN] ReportRenderer exited non-zero"
fi

# ── 6. Verifikasi & Convert BMP → PNG ─────────────────────────────────────────
banner "Step 6: Verifikasi & Konversi Output"
python3 /app/src/verify_fonts.py

# ── 7. Final Summary ────────────────────────────────────────────────────────────
banner "SELESAI"
echo "File output tersedia di /app/output/ :"
echo ""
ls -lh /app/output/ 2>/dev/null | tail -n +2 || echo "  (kosong)"
echo ""
echo "  Render dari Debian (Pillow):"
echo "    debian_inter.png     ← Inter dirender oleh Pillow di Linux"
echo "    debian_segoeui.png   ← Segoe UI dirender oleh Pillow di Linux"
echo ""
echo "  Render dari Wine (C GDI via MinGW EXE):"
echo "    wine_inter.bmp/png   ← Inter dirender oleh Wine GDI (C)"
echo "    wine_segoeui.bmp/png ← Segoe UI dirender oleh Wine GDI (C)"
echo ""
  echo "  Render dari C# RDLC (Microsoft.Reporting via wine64 dotnet.exe):"

  echo "    rdlc_output.pdf      ← testing.rdl dirender menjadi PDF"
  echo ""
echo "    (buka PDF langsung dari ./output/ — font aktual tampak di dalam PDF)"
echo ""
echo "  Buka file PNG untuk melihat:"
echo "    • Status bar HIJAU  = font ditemukan dan digunakan dengan benar"
echo "    • Status bar MERAH  = font tidak ditemukan, GDI pakai substitusi"
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Untuk mengambil output ke Windows host:                ║"
echo "║  docker-compose up  (pastikan volume ./output mounted)  ║"
echo "╚══════════════════════════════════════════════════════════╝"
