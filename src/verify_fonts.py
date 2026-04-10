#!/usr/bin/env python3
"""
verify_fonts.py
────────────────────────────────────────────────────────────────────────────────
Verifikasi dan laporan ketersediaan font di:
  1. Sistem Debian (via fontconfig / /usr/share/fonts/)
  2. Wine fonts directory (~/.wine/drive_c/windows/Fonts/)
  3. Konversi output BMP dari Wine ke PNG (agar mudah dibuka di semua OS)
  4. Cetak summary: apakah font terbukti ada di keduanya

TUJUAN: Membuktikan bahwa font yang diinstall di Debian
        tersedia juga di Wine untuk GDI+ printing.
────────────────────────────────────────────────────────────────────────────────
"""

import os
import sys
import glob
import subprocess

# PIL untuk konversi BMP -> PNG
try:
    from PIL import Image
    PIL_AVAILABLE = True
except ImportError:
    PIL_AVAILABLE = False

# ── Konfigurasi ────────────────────────────────────────────────────────────────
WINE_PREFIX   = os.environ.get("WINEPREFIX", "/root/.wine")
WINE_FONTS    = os.path.join(WINE_PREFIX, "drive_c", "windows", "Fonts")
OUTPUT_DIR    = "/app/output"
TARGET_FONTS  = ["inter", "segoe"]


# ── Helper ─────────────────────────────────────────────────────────────────────
def sep(title="", char="─", width=70):
    if title:
        side = (width - len(title) - 2) // 2
        print(f"\n{'─' * side} {title} {'─' * (width - side - len(title) - 2)}")
    else:
        print(char * width)


def check_system_fonts() -> dict:
    """Cek font di Debian via fontconfig (fc-list)."""
    sep("1. Font di Sistem Debian (fontconfig)")
    found = {}

    try:
        result = subprocess.run(
            ["fc-list", "--format=%{family}:%{file}\n"],
            capture_output=True, text=True, timeout=15
        )
        for line in result.stdout.splitlines():
            if ":" not in line:
                continue
            family, path = line.split(":", 1)
            for kw in TARGET_FONTS:
                if kw in family.lower() or kw in path.lower():
                    key = family.strip()
                    if key not in found:
                        found[key] = path.strip()

        if found:
            for family, path in sorted(found.items()):
                size_kb = os.path.getsize(path) // 1024 if os.path.isfile(path) else 0
                print(f"  ✓  {family:<35s}  {size_kb:>5d} KB  →  {path}")
        else:
            print("  ✗  Tidak ada font Inter/Segoe UI di sistem Debian")

    except Exception as e:
        print(f"  ERROR: {e}")

    return found


def check_wine_fonts() -> dict:
    """Cek font di Wine fonts directory."""
    sep("2. Font di Wine Fonts Directory")
    print(f"  Path: {WINE_FONTS}")
    found = {}

    if not os.path.isdir(WINE_FONTS):
        print("  ✗  Directory tidak ada!")
        return found

    all_files = os.listdir(WINE_FONTS)
    print(f"  Total file di Wine Fonts: {len(all_files)}")
    print()

    for fname in sorted(all_files):
        for kw in TARGET_FONTS:
            if kw in fname.lower():
                fpath = os.path.join(WINE_FONTS, fname)
                size_kb = os.path.getsize(fpath) // 1024
                found[fname] = fpath
                print(f"  ✓  {fname:<40s}  {size_kb:>5d} KB")

    if not found:
        print("  ✗  Tidak ada font Inter/Segoe UI di Wine")

    return found


def cross_check(sys_fonts: dict, wine_fonts: dict) -> None:
    """Bandingkan: font di Debian vs font di Wine."""
    sep("3. Cross-Check: Debian vs Wine")

    checks = [
        ("Inter",    ["inter"]),
        ("Segoe UI", ["segoe"]),
    ]

    all_ok = True
    for font_name, keywords in checks:
        in_debian = any(
            any(kw in k.lower() for kw in keywords)
            for k in sys_fonts.keys()
        )
        in_wine = any(
            any(kw in k.lower() for kw in keywords)
            for k in wine_fonts.keys()
        )

        d_mark = "✓ OK   " if in_debian else "✗ MISS "
        w_mark = "✓ OK   " if in_wine   else "✗ MISS "

        status = "✓ SYNCED" if (in_debian and in_wine) else \
                 "⚠ DEBIAN ONLY" if in_debian else \
                 "⚠ WINE ONLY"  if in_wine   else \
                 "✗ NOT FOUND"

        if not (in_debian and in_wine):
            all_ok = False

        print(f"  {font_name:<12s}  Debian: {d_mark}  Wine: {w_mark}  → {status}")

    sep()
    if all_ok:
        print("  ✓ TERBUKTI: Semua font yang diinstall di Debian")
        print("    tersedia juga di Wine untuk GDI+ printing!")
    else:
        print("  ⚠ Beberapa font belum ter-sync. Cek logs setup_wine_fonts.sh")


def convert_bmp_to_png() -> None:
    """Konversi file BMP (output Wine) ke PNG agar mudah dibuka."""
    sep("4. Konversi Output BMP → PNG")

    if not PIL_AVAILABLE:
        print("  SKIP: Pillow tidak tersedia")
        return

    bmps = glob.glob(os.path.join(OUTPUT_DIR, "*.bmp"))
    if not bmps:
        print("  Tidak ada file BMP ditemukan")
        return

    for bmp_path in sorted(bmps):
        png_path = bmp_path.replace(".bmp", ".png")
        try:
            img = Image.open(bmp_path)
            img.save(png_path)
            size = os.path.getsize(png_path) // 1024
            print(f"  ✓  {os.path.basename(bmp_path):<30s} → {os.path.basename(png_path):30s}  ({size} KB)")
        except Exception as e:
            print(f"  ✗  {os.path.basename(bmp_path)}: {e}")


def list_outputs() -> None:
    """Tampilkan semua file output beserta ukurannya."""
    sep("5. Summary Output Files")

    files = sorted(glob.glob(os.path.join(OUTPUT_DIR, "*.*")))
    if not files:
        print(f"  (kosong - tidak ada file di {OUTPUT_DIR})")
        return

    for fpath in files:
        fname = os.path.basename(fpath)
        size_kb = os.path.getsize(fpath) // 1024
        ext = os.path.splitext(fname)[1].upper()

        origin = "Debian" if "debian" in fname else "Wine" if "wine" in fname else "?"
        font   = "Inter"    if "inter"  in fname.lower() else \
                 "Segoe UI" if "segoe"  in fname.lower() else "?"

        print(f"  {fname:<40s}  {size_kb:>5d} KB  [{origin} / {font}]")

    print()
    print(f"  Mount -v ./output:/app/output untuk mengambil file ke host.")


def explain_solution() -> None:
    """Penjelasan bagaimana solusi ini bekerja."""
    sep("Penjelasan Solusi")
    print("""
  Masalah yang dipecahkan:
    Font Inter (dan Segoe UI) diinstall di Debian, tapi Wine tidak
    mengenalinya sehingga GDI+ gagal menemukan font tersebut.

  Solusi (lihat scripts/setup_wine_fonts.sh):
    ┌─────────────────────────────────────────────────────────────┐
    │  1. Install font ke /usr/share/fonts/truetype/inter/        │
    │  2. fc-cache -fv (update fontconfig Debian)                 │
    │  3. cp *.ttf ~/.wine/drive_c/windows/Fonts/                 │
    │  4. wine regedit fonts.reg (daftarkan ke registry Wine)     │
    └─────────────────────────────────────────────────────────────┘

  Setelah langkah ini:
    • Windows API (GDI/GDI+) dalam Wine mencari font di:
        C:\\Windows\\Fonts\\ (= ~/.wine/drive_c/windows/Fonts/)
    • CreateFont("Inter", ...) → GDI menemukan Inter-Regular.ttf
    • GetTextFace() mengembalikan "Inter" → MATCH ✓

  Untuk kode C# GDI+ mu:
    var font = new Font("Inter", 12);  // ← akan bekerja setelah setup ini
""")


def main() -> None:
    print()
    print("=" * 70)
    print("  Font Verification Report: Debian + Wine")
    print("=" * 70)

    sys_fonts  = check_system_fonts()
    wine_fonts = check_wine_fonts()
    cross_check(sys_fonts, wine_fonts)
    convert_bmp_to_png()
    list_outputs()
    explain_solution()


if __name__ == "__main__":
    main()
