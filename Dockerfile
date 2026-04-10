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
        wine wine64 wine32:i386 \
        gcc-mingw-w64-x86-64 \
        fontconfig \
        python3 python3-pip \
        wget curl unzip xvfb \
        ca-certificates file \
        libgdiplus \
    && rm -rf /var/lib/apt/lists/*

# ── Install winetricks dari GitHub (tidak tersedia di Debian bookworm apt) ─────
RUN wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
         -O /usr/local/bin/winetricks && \
    chmod +x /usr/local/bin/winetricks

# ── Install .NET SDK 8.0 (untuk kompilasi C# → Windows EXE via dotnet publish) ─
# Diperlukan untuk cross-compile src/FontRenderer/ targeting win-x64
RUN wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb \
         -O /tmp/ms-prod.deb && \
    dpkg -i /tmp/ms-prod.deb && \
    rm /tmp/ms-prod.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends dotnet-sdk-6.0 && \
    rm -rf /var/lib/apt/lists/* && \
    dotnet --version

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

# ── Pre-configure Wine: init prefix + gdiplus + font registration ──────────────
# Dilakukan saat BUILD agar container tidak bergantung pada jaringan untuk gdiplus
# di runtime. gdiplus dari Microsoft wajib ada agar rendering GDI+ tidak crash.
RUN Xvfb :99 -screen 0 1024x768x24 -ac 2>/dev/null & \
    XVFB_PID=$! && \
    sleep 3 && \
    DISPLAY=:99 WINEDLLOVERRIDES="mscoree,mshtml=" WINEDEBUG=-all \
        wine wineboot --init 2>/dev/null && \
    sleep 3 && \
    echo "[Build] Wine prefix diinisialisasi" && \
    DISPLAY=:99 WINEDEBUG=-all winetricks -q gdiplus 2>/dev/null \
        && echo "[Build] gdiplus diinstall" \
        || echo "[Build] WARN: winetricks gdiplus gagal (akan dicoba ulang saat runtime)" && \
    WINE_FONTS="${WINEPREFIX}/drive_c/windows/Fonts" && \
    mkdir -p "$WINE_FONTS" && \
    find /usr/share/fonts/truetype/inter -name "*.ttf" \
         -exec cp {} "$WINE_FONTS/" \; 2>/dev/null || true && \
    find /usr/share/fonts/truetype/segoe -name "*.ttf" \
         -exec cp {} "$WINE_FONTS/" \; 2>/dev/null || true && \
    echo "[Build] Font di Wine/Fonts: $(ls "$WINE_FONTS"/*.ttf 2>/dev/null | wc -l) file" && \
    printf 'Windows Registry Editor Version 5.00\n\n[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]\n"Inter (TrueType)"="Inter-Regular.ttf"\n"Inter Bold (TrueType)"="Inter-Bold.ttf"\n"Inter SemiBold (TrueType)"="Inter-SemiBold.ttf"\n"Inter Medium (TrueType)"="Inter-Medium.ttf"\n"Segoe UI (TrueType)"="segoeui.ttf"\n"Segoe UI Bold (TrueType)"="segoeuib.ttf"\n"Segoe UI Italic (TrueType)"="segoeuii.ttf"\n' \
         > /tmp/fonts_build.reg && \
    DISPLAY=:99 WINEDEBUG=-all wine regedit /tmp/fonts_build.reg 2>/dev/null && \
    wineserver --wait 2>/dev/null || true && \
    echo "[Build] Registry font diupdate ($(grep -c TrueType /tmp/fonts_build.reg) entries)" && \
    wineserver --kill 2>/dev/null || true && \
    kill "$XVFB_PID" 2>/dev/null || true

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

# ── Download Windows .NET 6 Runtime ke Wine prefix ──────────────────────────
# Mirrors production: "wine64 dotnet Siloam.PaymentSystem.Report.dll"
# Wine menyediakan usp10.dll (Uniscribe) yang diperlukan ReportViewerCore.NETCore
# untuk text measurement saat render PDF. Self-contained win-x64 tidak bisa
# dipakai karena Wine's built-in gdiplus crash; framework-dependent + Windows
# .NET runtime adalah satu-satunya workaround resmi (github.com/lkosson/reportviewercore#144)
RUN mkdir -p "${WINEPREFIX}/drive_c/dotnet" && \
    wget -q "https://dotnetcli.azureedge.net/dotnet/Runtime/6.0.36/dotnet-runtime-6.0.36-win-x64.zip" \
         -O /tmp/dotnet-win.zip && \
    unzip -q /tmp/dotnet-win.zip -d "${WINEPREFIX}/drive_c/dotnet" && \
    rm /tmp/dotnet-win.zip && \
    echo "[Build] Windows .NET 6 runtime di Wine:" && \
    ls "${WINEPREFIX}/drive_c/dotnet/dotnet.exe" && echo "  dotnet.exe OK"

# ── Build C# RDLC → framework-dependent DLL (dijalankan via wine64 dotnet.exe) ─
# Framework-dependent: tidak bundel runtime, DLL adalah .NET IL murni.
# Dijalankan: wine64 C:\dotnet\dotnet.exe Z:\app\rdlc_win\ReportRenderer.dll
RUN dotnet publish /app/src/ReportRenderer/ReportRenderer.csproj \
        -c Release \
        --self-contained false \
        -o /app/rdlc_win \
        --nologo \
        -p:DebugType=None \
        -p:DebugSymbols=false && \
    echo "RDLC DLL berhasil dibuild:" && \
    ls -lh /app/rdlc_win/ReportRenderer.dll

RUN mkdir -p /app/output

ENTRYPOINT ["/bin/bash", "/app/scripts/entrypoint.sh"]
