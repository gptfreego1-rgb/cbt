FROM --platform=linux/amd64 debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV HOME=/root

# Install packages minimal yang diperlukan
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    websockify \
    openjdk-17-jre \
    wget \
    unzip \
    bash \
    xterm \
    jwm \
    rox-filer \
    yad \
    sudo \
    procps \
    fontconfig \
    fonts-dejavu-core \
    imagemagick \
    libx11-dev \
    libxfixes-dev \
    x11-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Download noVNC dari GitHub
RUN wget -q -O /tmp/novnc.tar.gz \
    https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz \
    && tar -xzf /tmp/novnc.tar.gz -C /opt/ \
    && mv /opt/noVNC-1.4.0 /opt/novnc \
    && rm /tmp/novnc.tar.gz

# Setup directories
RUN mkdir -p /root/.jwm /root/Desktop /root/.config/rox.sourceforge.net/ROX-Filer /usr/share/pixmaps

# Download MicroEmulator
RUN wget -q -O /tmp/microemu.zip \
    https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/microemu/microemulator-2.0.4.zip \
    && unzip /tmp/microemu.zip -d /opt/microemulator \
    && rm /tmp/microemu.zip

# Download Avatar
RUN wget -q -O /opt/microemulator/avatar.jar \
    https://files.catbox.moe/6q19o1.zip

# === BUAT ICON 48x48 PNG ===
# Avatar icon (game controller)
RUN convert -size 48x48 xc:transparent \
    -font DejaVu-Sans -pointsize 28 -fill "#4CAF50" -gravity center -annotate 0 "🎮" \
    /usr/share/pixmaps/avatar.png

# Password icon (key)
RUN convert -size 48x48 xc:transparent \
    -font DejaVu-Sans -pointsize 28 -fill "#FFC107" -gravity center -annotate 0 "🔑" \
    /usr/share/pixmaps/password.png

# Terminal icon (computer)
RUN convert -size 48x48 xc:transparent \
    -font DejaVu-Sans -pointsize 28 -fill "#2196F3" -gravity center -annotate 0 "💻" \
    /usr/share/pixmaps/terminal.png

# Logout icon (door)
RUN convert -size 48x48 xc:transparent \
    -font DejaVu-Sans -pointsize 28 -fill "#F44336" -gravity center -annotate 0 "🚪" \
    /usr/share/pixmaps/logout.png

# Menu icon
RUN convert -size 24x24 xc:transparent \
    -font DejaVu-Sans -pointsize 16 -fill "#ffffff" -gravity center -annotate 0 "☰" \
    /usr/share/pixmaps/menu.png

# Create solid color background image
RUN mkdir -p /usr/share/backgrounds && \
    convert -size 800x600 xc:'#1a1a2e' /usr/share/backgrounds/default.png

# === SCRIPTS ===

# 1. start.sh - OPTIMIZED
RUN cat >/usr/local/bin/start.sh <<'EOF'
#!/bin/bash
echo "====================================="
echo "  Debian JWM + ROX-Filer Desktop"
echo "  MicroEmulator Avatar - Optimized"
echo "====================================="

# Cleanup
pkill Xvfb 2>/dev/null
pkill x11vnc 2>/dev/null
pkill websockify 2>/dev/null
rm -f /tmp/.X1-lock
rm -rf /tmp/.X11-unix/X1

# Start Xvfb dengan resolusi rendah & 16-bit
Xvfb :1 -screen 0 800x600x16 -ac -nolisten tcp -noreset &
export DISPLAY=:1
sleep 2

# Start x11vnc dengan optimasi bandwidth
x11vnc -display :1 \
       -forever \
       -passwd 123456 \
       -shared \
       -rfbport 5901 \
       -auth /root/.Xauthority \
       -nowf \
       -noxdamage \
       -xkb \
       -defer 50 \
       -wait 30 \
       -speeds modem \
       -tightfilexfer \
       -norepeat &
sleep 2

# Start websockify
websockify --web=/opt/novnc 6080 localhost:5901 &
sleep 2

# Start JWM
jwm &
sleep 2

# Start ROX-Filer pinboard
rox -p /root/.config/rox.sourceforge.net/ROX-Filer/pinboard &

echo ""
echo "====================================="
echo "✅ SEMUA SUDAH JALAN!"
echo "====================================="
echo "🌐 Web VNC: http://localhost:6080/vnc.html"
echo "🔑 Password: 123456"
echo "📌 Desktop: Avatar | Ganti Password | Terminal | Logout"
echo "====================================="

tail -f /dev/null
EOF

# 2. password.sh - FIXED (variabel tidak tertimpa)
RUN cat >/usr/local/bin/password.sh <<'EOF'
#!/bin/bash

# Gunakan nama variabel berbeda agar tidak tertimpa
PASS1=$(yad --title="Ganti Password VNC" \
    --width=350 \
    --height=140 \
    --form \
    --field="Password Baru":H \
    --field="Konfirmasi Password":H \
    --button="Batal:1" \
    --button="Ganti Password:0" \
    --center \
    --window-icon="system-lock-screen" \
    --text="Masukkan password baru untuk VNC" \
    --image="dialog-password")

if [ $? -ne 0 ]; then exit 0; fi

PASS_BARU=$(echo "$PASS1" | cut -d'|' -f1)
PASS_KONFIRMASI=$(echo "$PASS1" | cut -d'|' -f2)

if [ -z "$PASS_BARU" ] || [ -z "$PASS_KONFIRMASI" ]; then
    yad --title="Error" --width=300 --height=100 --text="❌ Password tidak boleh kosong!" --button="OK:0" --image="dialog-error"
    exit 1
fi

if [ "$PASS_BARU" != "$PASS_KONFIRMASI" ]; then
    yad --title="Error" --width=300 --height=100 --text="❌ Password tidak sama!" --button="OK:0" --image="dialog-error"
    exit 1
fi

if [ ${#PASS_BARU} -lt 4 ]; then
    yad --title="Error" --width=300 --height=100 --text="❌ Password minimal 4 karakter!" --button="OK:0" --image="dialog-error"
    exit 1
fi

yad --title="Ganti Password" --width=300 --height=100 --text="⏳ Mengganti password..." --progress --pulsate --auto-close --no-buttons &
PROGRESS_PID=$!

pkill x11vnc 2>/dev/null
pkill websockify 2>/dev/null
sleep 1

export DISPLAY=:1
x11vnc -display :1 -forever -passwd "$PASS_BARU" -shared -rfbport 5901 \
    -nowf -noxdamage -defer 50 -wait 30 -speeds modem -tightfilexfer -norepeat &

websockify --web=/opt/novnc 6080 localhost:5901 &

kill $PROGRESS_PID 2>/dev/null

yad --title="Sukses" --width=350 --height=120 --text="✅ Password berhasil diganti!\n\n🔑 Password baru: $PASS_BARU" --button="OK:0" --image="dialog-information"
EOF

# 3. avatar.sh - Optimized JVM
RUN cat >/usr/local/bin/avatar.sh <<'EOF'
#!/bin/bash
export DISPLAY=:1

if pgrep -f "microemulator.jar" > /dev/null; then
    yad --title="Info" --width=300 --height=100 --text="⚠️ MicroEmulator sudah berjalan!" --button="OK:0" --image="dialog-info"
    exit 0
fi

# JVM optimized for low memory
java -Xms32m -Xmx64m -XX:+UseSerialGC -XX:+DisableExplicitGC \
    -Dawt.toolkit=sun.awt.X11.XToolkit \
    -Djava.awt.headless=false \
    -Dawt.useSystemAAFontSettings=false \
    -Dswing.defaultlaf=javax.swing.plaf.metal.MetalLookAndFeel \
    -jar -noverify \
    /opt/microemulator/microemulator-2.0.4/microemulator.jar \
    /opt/microemulator/avatar.jar &

yad --title="Info" --width=300 --height=100 --text="✅ MicroEmulator Avatar sedang berjalan!" --button="OK:0" --timeout=2 --image="dialog-information" &
exit 0
EOF

RUN chmod +x /usr/local/bin/*.sh

# === DESKTOP LAUNCHERS dengan icon lokal ===
RUN cat >/root/Desktop/Avatar.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Avatar
Comment=Jalankan MicroEmulator Avatar
Exec=/usr/local/bin/avatar.sh
Icon=/usr/share/pixmaps/avatar.png
Terminal=false
Categories=Game;
EOF

RUN cat >/root/Desktop/Ganti-Password.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Ganti Password
Comment=Ubah password VNC
Exec=/usr/local/bin/password.sh
Icon=/usr/share/pixmaps/password.png
Terminal=false
Categories=System;
EOF

RUN cat >/root/Desktop/Terminal.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Terminal
Comment=Buka terminal
Exec=xterm
Icon=/usr/share/pixmaps/terminal.png
Terminal=false
Categories=System;
EOF

RUN cat >/root/Desktop/Logout.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Logout
Comment=Keluar dari sesi
Exec=pkill -KILL -u root
Icon=/usr/share/pixmaps/logout.png
Terminal=false
Categories=System;
EOF

RUN chmod +x /root/Desktop/*.desktop

# === JWM CONFIG ===
RUN cat >/root/.jwmrc <<'EOF'
<?xml version="1.0"?>
<JWM>
    <RootMenu label="Menu" height="20">
        <Program label="Terminal" icon="/usr/share/pixmaps/terminal.png">xterm</Program>
        <Program label="Avatar" icon="/usr/share/pixmaps/avatar.png">/usr/local/bin/avatar.sh</Program>
        <Program label="Ganti Password" icon="/usr/share/pixmaps/password.png">/usr/local/bin/password.sh</Program>
        <Separator/>
        <Program label="Logout" icon="/usr/share/pixmaps/logout.png">pkill -KILL -u root</Program>
        <Separator/>
        <Restart label="Restart JWM" icon="system-restart"/>
        <Exit label="Exit JWM" icon="system-shutdown" confirm="true"/>
    </RootMenu>

    <TaskList>
        <Font>DejaVu Sans-9</Font>
    </TaskList>

    <Tray x="0" y="-1" height="24" autohide="off">
        <TrayButton icon="/usr/share/pixmaps/menu.png">root:3</TrayButton>
        <Spacer width="3"/>
        <TaskList/>
        <Dock/>
        <Clock format="%H:%M"/>
    </Tray>

    <WindowStyle>
        <Font>DejaVu Sans-9</Font>
        <Width>2</Width>
        <Height>18</Height>
        <Active>
            <Foreground>#ffffff</Foreground>
            <Background>#2d5a88</Background>
        </Active>
        <Inactive>
            <Foreground>#888888</Foreground>
            <Background>#d3d3d3</Background>
        </Inactive>
    </WindowStyle>

    <Desktop>
        <Background type="solid">#1a1a2e</Background>
    </Desktop>

    <Key key="Up">up</Key>
    <Key key="Down">down</Key>
    <Key key="Left">left</Key>
    <Key key="Right">right</Key>
    <Key key="Return">select</Key>
    <Key key="Escape">escape</Key>
    <Key key="F12">root:3</Key>

    <StartupCommand>rox -p /root/.config/rox.sourceforge.net/ROX-Filer/pinboard</StartupCommand>
</JWM>
EOF

# === ROX-Filer PINBOARD ===
RUN cat >/root/.config/rox.sourceforge.net/ROX-Filer/pinboard <<'EOF'
<?xml version="1.0"?>
<pinboard>
  <backdrop style="Scaled">/usr/share/backgrounds/default.png</backdrop>
  <icon x="20" y="20" label="Avatar">/root/Desktop/Avatar.desktop</icon>
  <icon x="20" y="80" label="Ganti Password">/root/Desktop/Ganti-Password.desktop</icon>
  <icon x="20" y="140" label="Terminal">/root/Desktop/Terminal.desktop</icon>
  <icon x="20" y="200" label="Logout">/root/Desktop/Logout.desktop</icon>
</pinboard>
EOF

# Hapus Options file yang error, ROX-Filer akan buat sendiri
RUN rm -f /root/.config/rox.sourceforge.net/ROX-Filer/Options

EXPOSE 6080
CMD ["/usr/local/bin/start.sh"]
