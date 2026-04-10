#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  setup_wine_fonts.sh                                                        ║
# ║  Menyalin font dari sistem Debian ke Wine dan mendaftarkannya               ║
# ║  di Windows Registry agar GDI+ bisa menemukan font tersebut.               ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

WINE_FONTS_DIR="${WINEPREFIX:-/root/.wine}/drive_c/windows/Fonts"
REG_FILE="/tmp/wine_font_registration.reg"
COPIED=0

echo "──────────────────────────────────────────────────────────"
echo "  Setup Wine Fonts"
echo "  Source: /usr/share/fonts/truetype/"
echo "  Target: $WINE_FONTS_DIR"
echo "──────────────────────────────────────────────────────────"

mkdir -p "$WINE_FONTS_DIR"

# ── Buat file registry ─────────────────────────────────────────────────────────
# Format: "Windows Registry Editor Version 5.00"
# Key: HKLM\Software\Microsoft\Windows NT\CurrentVersion\Fonts
# Value: "Nama Font (TrueType)" = "filename.ttf"
#
# Setelah import ini, GDI akan menemukan font lewat nama family-nya.
cat > "$REG_FILE" << 'REG_EOF'
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\Fonts]
REG_EOF

# ── Fungsi: copy TTF dari satu direktori ke Wine ───────────────────────────────
copy_fonts_from_dir() {
    local src_dir="$1"
    local label="$2"

    if [ ! -d "$src_dir" ]; then
        echo "  [SKIP] $label: direktori tidak ada ($src_dir)"
        return 0
    fi

    local count=0
    for ttf_file in "$src_dir"/*.ttf "$src_dir"/*.TTF; do
        [ -f "$ttf_file" ] || continue

        local basename
        basename=$(basename "$ttf_file")

        # Copy ke Wine/Fonts
        cp "$ttf_file" "$WINE_FONTS_DIR/$basename"

        # Buat registry entry:
        # Contoh: "Inter Regular (TrueType)"="Inter-Regular.ttf"
        local font_display
        font_display=$(echo "${basename%.*}" | sed 's/[-_]/ /g')
        printf '"%s (TrueType)"="%s"\n' "$font_display" "$basename" >> "$REG_FILE"

        echo "  [COPY] $basename"
        count=$((count + 1))
        COPIED=$((COPIED + 1))
    done

    if [ "$count" -eq 0 ]; then
        echo "  [EMPTY] $label: tidak ada .ttf di $src_dir"
    else
        echo "  [OK]   $label: $count file disalin"
    fi
}

# ── Copy Inter fonts ───────────────────────────────────────────────────────────
echo ""
echo "Inter Font:"
copy_fonts_from_dir "/usr/share/fonts/truetype/inter" "Inter"

# ── Copy Segoe UI fonts ─────────────────────────────────────────────────────────
echo ""
echo "Segoe UI Font:"
copy_fonts_from_dir "/usr/share/fonts/truetype/segoe" "Segoe UI"

# ── Tambahkan newline di akhir reg file ────────────────────────────────────────
echo "" >> "$REG_FILE"

# ── Tampilkan isi reg file ─────────────────────────────────────────────────────
echo ""
echo "Registry entries yang akan diimport:"
echo "──────────────────────────────────────────────────────────"
cat "$REG_FILE"
echo "──────────────────────────────────────────────────────────"

# ── Import ke Wine registry ────────────────────────────────────────────────────
if [ "$COPIED" -gt 0 ]; then
    echo ""
    echo "Mengimport $COPIED font ke Wine registry..."
    WINEDEBUG=-all wine regedit "$REG_FILE" 2>/dev/null
    echo "[OK] Registry berhasil diupdate"
else
    echo ""
    echo "[WARN] Tidak ada font yang disalin, registry tidak diupdate"
fi

# ── Verifikasi ─────────────────────────────────────────────────────────────────
echo ""
echo "Verifikasi Wine Fonts directory:"
find "$WINE_FONTS_DIR" \( -iname "*inter*" -o -iname "*segoe*" \) 2>/dev/null \
    | while read -r f; do
        size=$(du -k "$f" | cut -f1)
        echo "  ✓  $(basename "$f")  (${size} KB)"
    done || echo "  (tidak ada yang matching)"

echo ""
echo "[Done] setup_wine_fonts.sh selesai"
