# Docker Font Demo — Debian + Wine GDI+

Membuktikan bahwa font **Inter** dan **Segoe UI** yang diinstall di sistem Debian
tersedia juga di Wine untuk GDI+ printing.

## Masalah yang Dipecahkan

> Font Inter tidak tersedia di Wine, sehingga `new Font("Inter", 12)` (GDI+)
> menggunakan font substitusi, bukan Inter yang sebenarnya.

## Cara Kerja

```
Debian OS
  └─ /usr/share/fonts/truetype/inter/Inter-Regular.ttf   (diinstall via wget)
  └─ /usr/share/fonts/truetype/segoe/segoeui.ttf         (diinstall via wget)
         │
         │  setup_wine_fonts.sh: cp + wine regedit
         ▼
Wine (~/.wine/drive_c/windows/Fonts/)
  └─ Inter-Regular.ttf   ← tersedia untuk GDI/GDI+
  └─ segoeui.ttf          ← tersedia untuk GDI/GDI+
         │
         │  Wine GDI: CreateFont("Inter", ...) → FOUND ✓
         ▼
  render_wine.exe (dikompilasi dengan MinGW, dijalankan via wine)
  → Menggambar teks "Inter" menggunakan font Inter yang sebenarnya
  → GetTextFace() mengembalikan "Inter" → MATCH
```

## Struktur Project

```
docker-font-demo/
├── Dockerfile                  # Debian + Wine + MinGW + font install
├── docker-compose.yml
├── src/
│   ├── render_wine.c           # Win32 GDI renderer (dikompilasi jadi .exe, jalan di Wine)
│   ├── render_debian.py        # Python Pillow renderer (jalan langsung di Debian)
│   └── verify_fonts.py         # Verifikasi + convert BMP→PNG + summary
├── scripts/
│   ├── entrypoint.sh           # Orkestrasi semua langkah
│   └── setup_wine_fonts.sh     # Sinkronisasi font Debian → Wine registry
└── output/                     # Hasil render (mount dari host)
    ├── debian_inter.png        ← Inter dirender Pillow di Debian
    ├── debian_segoeui.png      ← Segoe UI dirender Pillow di Debian
    ├── wine_inter.bmp/png      ← Inter dirender Wine GDI
    └── wine_segoeui.bmp/png    ← Segoe UI dirender Wine GDI
```

## Cara Menjalankan

### Build + Run (sekali jalan)
```bash
docker-compose up --build
```

### Hanya Build
```bash
docker build -t font-demo .
```

### Run dengan volume
```bash
docker run --rm -v "$(pwd)/output:/app/output" font-demo
```

## Output

Setelah container selesai, folder `./output/` berisi gambar PNG yang menampilkan:

| File | Keterangan |
|------|------------|
| `debian_inter.png` | Inter dirender oleh Python Pillow di Debian |
| `debian_segoeui.png` | Segoe UI dirender oleh Python Pillow di Debian |
| `wine_inter.png` | Inter dirender oleh Wine GDI+ (EXE Windows) |
| `wine_segoeui.png` | Segoe UI dirender oleh Wine GDI+ (EXE Windows) |

**Status bar hijau** = font ditemukan dan digunakan dengan benar  
**Status bar merah** = font tidak ditemukan, GDI pakai substitusi

## Untuk Kode GDI+ C# di Wine

Setelah font disinkronisasi (langkah yang dilakukan `setup_wine_fonts.sh`):

```csharp
// Ini akan bekerja karena Inter sudah ada di C:\Windows\Fonts
using var font = new Font("Inter", 12, FontStyle.Regular);
using var g = Graphics.FromImage(bitmap);
g.DrawString("Hello World", font, Brushes.Black, 10, 10);
```

## Catatan Lisensi Font

- **Inter**: Open Source (SIL OFL 1.1) — bebas digunakan
- **Segoe UI**: Milik Microsoft — hanya boleh digunakan di mesin berlisensi Windows
