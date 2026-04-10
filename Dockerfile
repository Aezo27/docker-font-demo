# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  Docker Font Demo: Debian + Wine                                            ║
# ║  Tujuan: Membuktikan font Inter & Segoe UI yang diinstall di Debian         ║
# ║          tersedia juga di Wine untuk printing via GDI+                      ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

FROM debian:bookworm

LABEL description="Font Demo: Debian system fonts shared with Wine for GDI+ printing"

ENV DEBIAN_FRONTEND=noninteractive
ENV WINEARCH=win64
ENV WINEPREFIX=/root/.wine

# ── System packages ────────────────────────────────────────────────────────────
# wine64     : Wine untuk menjalankan EXE Windows
# gcc-mingw  : Cross-compiler untuk membuat EXE Windows dari Linux
# fontconfig : Tool manajemen font di Linux (fc-list, fc-match)
# xvfb       : Virtual display, diperlukan Wine untuk GDI
# python3    : Untuk rendering Debian-side
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        wine wine64 \
        gcc-mingw-w64-x86-64 \
        fontconfig \
        python3 python3-pip \
        wget curl unzip xvfb \
        ca-certificates file \
    && rm -rf /var/lib/apt/lists/*

# ── Python dependencies ────────────────────────────────────────────────────────
RUN pip3 install Pillow --break-system-packages

# ── Install Inter Font (Open Source, by Rasmus Andersson) ─────────────────────
# Diinstall ke /usr/share/fonts/truetype/inter (Debian system font directory)
RUN mkdir -p /usr/share/fonts/truetype/inter && \
    wget -q "https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip" \
         -O /tmp/inter.zip && \
    unzip -q /tmp/inter.zip -d /tmp/inter_extract && \
    # Cari semua TTF dalam zip dan copy yang penting
    find /tmp/inter_extract -name "Inter-Regular.ttf" \
         -exec cp {} /usr/share/fonts/truetype/inter/ \; && \
    find /tmp/inter_extract -name "Inter-Bold.ttf" \
         -exec cp {} /usr/share/fonts/truetype/inter/ \; && \
    find /tmp/inter_extract -name "Inter-SemiBold.ttf" \
         -exec cp {} /usr/share/fonts/truetype/inter/ \; && \
    find /tmp/inter_extract -name "Inter-Medium.ttf" \
         -exec cp {} /usr/share/fonts/truetype/inter/ \; && \
    ls -la /usr/share/fonts/truetype/inter/ && \
    rm -rf /tmp/inter.zip /tmp/inter_extract

# ── Install Segoe UI Font ──────────────────────────────────────────────────────
# Segoe UI adalah font Microsoft. Download dari mirror publik.
# Catatan: Font ini milik Microsoft; gunakan hanya di mesin berlisensi Windows.
RUN mkdir -p /usr/share/fonts/truetype/segoe && \
    wget -q --timeout=30 \
         "https://github.com/mrbvrz/segoe-ui-linux/raw/master/font/segoeui.ttf" \
         -O /usr/share/fonts/truetype/segoe/segoeui.ttf 2>/dev/null && \
    wget -q --timeout=30 \
         "https://github.com/mrbvrz/segoe-ui-linux/raw/master/font/segoeuib.ttf" \
         -O /usr/share/fonts/truetype/segoe/segoeuib.ttf 2>/dev/null && \
    wget -q --timeout=30 \
         "https://github.com/mrbvrz/segoe-ui-linux/raw/master/font/segoeuii.ttf" \
         -O /usr/share/fonts/truetype/segoe/segoeuii.ttf 2>/dev/null && \
    (ls /usr/share/fonts/truetype/segoe/*.ttf 2>/dev/null && echo "Segoe UI berhasil didownload" || \
     echo "WARN: Segoe UI gagal didownload, demo tetap jalan dengan Inter saja")

# ── Rebuild font cache (agar fontconfig mengenali font baru) ───────────────────
RUN fc-cache -fv && \
    echo "=== Verifikasi font terinstall ===" && \
    fc-list | grep -i -E "inter|segoe" | sort

# ── Copy source files ──────────────────────────────────────────────────────────
WORKDIR /app
COPY src/   /app/src/
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# ── Compile Win32 GDI application (berjalan di Wine) ───────────────────────────
# Menggunakan MinGW cross-compiler untuk membuat EXE Windows
# -lgdi32: Windows GDI library (untuk CreateFont, TextOut, dsb)
# -luser32: Windows User library (untuk GetDC, FillRect, dsb)
# -static: Link semua runtime statically, tidak perlu DLL tambahan
RUN x86_64-w64-mingw32-gcc \
        -std=c99 \
        -D__USE_MINGW_ANSI_STDIO=1 \
        -o /app/render_wine.exe \
        /app/src/render_wine.c \
        -lgdi32 -luser32 \
        -static && \
    echo "EXE berhasil dikompilasi:" && \
    file /app/render_wine.exe

RUN mkdir -p /app/output

ENTRYPOINT ["/bin/bash", "/app/scripts/entrypoint.sh"]
