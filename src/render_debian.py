#!/usr/bin/env python3
"""
render_debian.py
────────────────────────────────────────────────────────────────────────────────
Renderer sisi Debian menggunakan Python + Pillow.
Fungsi: membuktikan font Inter & Segoe UI tersedia di sistem Debian
        dengan cara menggambar teks lalu menyimpan sebagai PNG.

Menggunakan fc-match (fontconfig) untuk mencari file path TTF dari nama font.
────────────────────────────────────────────────────────────────────────────────
"""

import os
import sys
import subprocess
from PIL import Image, ImageDraw, ImageFont


def fc_match_path(font_name: str) -> str | None:
    """
    Cari path file TTF dari nama font menggunakan fontconfig (fc-match).
    Contoh: fc_match_path("Inter") → "/usr/share/fonts/truetype/inter/Inter-Regular.ttf"
    """
    try:
        result = subprocess.run(
            ["fc-match", "--format=%{file}", font_name],
            capture_output=True, text=True, timeout=10
        )
        path = result.stdout.strip()
        if path and os.path.isfile(path):
            return path
    except Exception as e:
        print(f"  [WARN] fc-match error: {e}")
    return None


def fc_list_font(font_name: str) -> list[str]:
    """
    List semua file yang terdaftar untuk font tertentu.
    Mengembalikan daftar path.
    """
    try:
        result = subprocess.run(
            ["fc-list", f":family={font_name}", "--format=%{{file}}\n"],
            capture_output=True, text=True, timeout=10
        )
        paths = [p.strip() for p in result.stdout.splitlines() if p.strip()]
        return paths
    except Exception:
        return []


def render_font(font_name: str, output_path: str) -> None:
    """Render teks menggunakan font tertentu dan simpan sebagai PNG."""
    width, height = 960, 280
    bg_color = (255, 255, 255)

    img = Image.new("RGB", (width, height), color=bg_color)
    draw = ImageDraw.Draw(img)

    # ── Cari file font ─────────────────────────────────────────────────────────
    font_path = fc_match_path(font_name)
    font_files = fc_list_font(font_name)
    font_found = False
    actual_font_name = "fallback"

    if font_path:
        actual_font_name = os.path.basename(font_path)
        # Cek apakah fc-match benar-benar mengembalikan font yang diminta
        # (bukan substitusi)
        font_found = any(
            font_name.lower().replace(" ", "") in p.lower().replace("-", "").replace("_", "")
            for p in ([font_path] + font_files)
        )
        # Fallback: cek berdasarkan nama file
        if not font_found and font_files:
            font_found = True  # ada di fc-list, berarti family ditemukan

    try:
        font_large = ImageFont.truetype(font_path, 58) if font_path else ImageFont.load_default()
        font_small = ImageFont.truetype(font_path, 20) if font_path else ImageFont.load_default()
        font_bold  = ImageFont.truetype(font_path, 22) if font_path else ImageFont.load_default()
    except Exception as e:
        print(f"  [WARN] Gagal load font dari {font_path}: {e}")
        font_large = font_small = font_bold = ImageFont.load_default()

    # ── Header bar biru ────────────────────────────────────────────────────────
    header_color = (70, 130, 200)
    draw.rectangle([5, 5, width - 5, 42], fill=header_color)

    # Teks header (Arial/default, putih)
    hdr_text = f"  Debian Pillow Font Test  |  Requested: \"{font_name}\""
    try:
        hdr_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18)
    except Exception:
        hdr_font = font_bold
    draw.text((10, 13), hdr_text, fill=(255, 255, 255), font=hdr_font)

    # ── Border ──────────────────────────────────────────────────────────────────
    draw.rectangle([4, 4, width - 4, height - 4], outline=header_color, width=3)

    # ── Teks utama dengan font yang diminta ──────────────────────────────────────
    draw.text((18, 55), "The quick brown fox  0123456789", fill=(20, 20, 20), font=font_large)

    # ── Info baris 1 ───────────────────────────────────────────────────────────
    info1 = (
        f"Requested: \"{font_name}\"    "
        f"File: \"{actual_font_name}\"    "
        f"Found by fontconfig: {'YES ✓' if font_found else 'NO ✗'}"
    )
    draw.text((18, 130), info1, fill=(60, 60, 60), font=font_small)

    # ── Info baris 2 ───────────────────────────────────────────────────────────
    if font_path:
        info2 = f"Path: {font_path}"
    else:
        info2 = "Path: tidak ditemukan oleh fontconfig"
    draw.text((18, 158), info2, fill=(60, 60, 60), font=font_small)

    # ── Info baris 3 ───────────────────────────────────────────────────────────
    all_files = ", ".join(os.path.basename(p) for p in font_files) if font_files else "(none)"
    info3 = f"fc-list files: {all_files[:100]}"
    draw.text((18, 186), info3, fill=(60, 60, 60), font=font_small)

    # ── Status bar ─────────────────────────────────────────────────────────────
    if font_found:
        status_color = (34, 139, 34)
        status_msg = f"  [OK] Font '{font_name}' FOUND di sistem Debian dan berhasil dirender!"
    else:
        status_color = (180, 30, 30)
        status_msg = f"  [WARN] Font '{font_name}' TIDAK ditemukan → Pillow pakai fallback"

    draw.rectangle([5, height - 48, width - 5, height - 5], fill=status_color)
    try:
        status_font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 18
        )
    except Exception:
        status_font = font_small
    draw.text((10, height - 36), status_msg, fill=(255, 255, 255), font=status_font)

    # ── Simpan ──────────────────────────────────────────────────────────────────
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    img.save(output_path)
    print(f"[Debian Pillow] Font: {font_name:<20s} | File: {actual_font_name:<30s} | "
          f"Found: {'YES' if font_found else 'NO'}")
    print(f"               Output: {output_path}")


def main() -> None:
    print("=" * 60)
    print("  Debian System Font Renderer (Python + Pillow)")
    print("=" * 60)

    fonts = [
        ("Inter",    "/app/output/debian_inter.png"),
        ("Segoe UI", "/app/output/debian_segoeui.png"),
    ]

    for font_name, out_path in fonts:
        print(f"\nRendering: {font_name}")
        render_font(font_name, out_path)

    print("\n[Debian] Rendering selesai!")


if __name__ == "__main__":
    main()
