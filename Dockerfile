FROM --platform=linux/amd64 debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV HOME=/root

# Install semua packages
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    novnc \
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Setup directories
RUN mkdir -p /root/.jwm /root/Desktop /root/.config/rox.sourceforge.net/ROX-Filer

# Download MicroEmulator
RUN wget -q -O /tmp/microemu.zip \
https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/microemu/microemulator-2.0.4.zip \
&& unzip /tmp/microemu.zip -d /opt/microemulator \
&& rm /tmp/microemu.zip

# Download Avatar
RUN wget -q -O /opt/microemulator/avatar.jar \
https://files.catbox.moe/6q19o1.zip

# VNC Password default
RUN mkdir -p /root/.vnc && \
    echo "123456" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# === BUAT SEMUA SCRIPT ===

# 1. start.sh
RUN cat >/usr/local/bin/start.sh <<'EOF'
#!/bin/bash
echo "====================================="
echo "  Debian JWM + ROX-Filer Desktop"
echo "  MicroEmulator Avatar"
echo "====================================="

# Cleanup
pkill Xvfb 2>/dev/null
pkill x11vnc 2>/dev/null
pkill websockify 2>/dev/null
rm -f /tmp/.X1-lock
rm -rf /tmp/.X11-unix/X1

# Start Xvfb
Xvfb :1 -screen 0 1024x768x24 -ac &
export DISPLAY=:1
sleep 2

# Start x11vnc
x11vnc -display :1 \
       -forever \
       -passwd 123456 \
       -shared \
       -rfbport 5901 \
       -nevershared \
       -nowf \
       -auth /root/.Xauthority &
sleep 2

# Start websockify (noVNC)
websockify --web=/usr/share/novnc 6080 localhost:5901 &
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
echo ""
echo "📌 Desktop: Avatar | Ganti Password | Terminal | Logout"
echo "====================================="

tail -f /dev/null
EOF

# 2. password.sh
RUN cat >/usr/local/bin/password.sh <<'EOF'
#!/bin/bash
PASS_FILE="/root/.vnc/passwd"

NEWPASS=$(yad --title="Ganti Password VNC" \
    --width=400 \
    --height=150 \
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

NEWPASS=$(echo "$NEWPASS" | cut -d'|' -f1)
CONFIRM=$(echo "$NEWPASS" | cut -d'|' -f2)

if [ -z "$NEWPASS" ] || [ -z "$CONFIRM" ]; then
    yad --title="Error" --width=300 --height=100 --text="❌ Password tidak boleh kosong!" --button="OK:0" --image="dialog-error"
    exit 1
fi

if [ "$NEWPASS" != "$CONFIRM" ]; then
    yad --title="Error" --width=300 --height=100 --text="❌ Password tidak sama!" --button="OK:0" --image="dialog-error"
    exit 1
fi

if [ ${#NEWPASS} -lt 4 ]; then
    yad --title="Error" --width=300 --height=100 --text="❌ Password minimal 4 karakter!" --button="OK:0" --image="dialog-error"
    exit 1
fi

yad --title="Ganti Password" --width=300 --height=100 --text="⏳ Mengganti password..." --progress --pulsate --auto-close --no-buttons &
PROGRESS_PID=$!

pkill x11vnc 2>/dev/null
pkill websockify 2>/dev/null
sleep 1

echo "$NEWPASS" | vncpasswd -f > "$PASS_FILE"
chmod 600 "$PASS_FILE"

export DISPLAY=:1
x11vnc -display :1 -forever -passwd "$NEWPASS" -shared -rfbport 5901 &
websockify --web=/usr/share/novnc 6080 localhost:5901 &

kill $PROGRESS_PID 2>/dev/null

yad --title="Sukses" --width=350 --height=120 --text="✅ Password berhasil diganti!\n\n🔑 Password baru: $NEWPASS" --button="OK:0" --image="dialog-information"
EOF

# 3. avatar.sh
RUN cat >/usr/local/bin/avatar.sh <<'EOF'
#!/bin/bash
export DISPLAY=:1

if pgrep -f "microemulator.jar" > /dev/null; then
    yad --title="Info" --width=300 --height=100 --text="⚠️ MicroEmulator sudah berjalan!" --button="OK:0" --image="dialog-info"
    exit 0
fi

java -Xms64m -Xmx128m -jar -noverify \
    /opt/microemulator/microemulator-2.0.4/microemulator.jar \
    /opt/microemulator/avatar.jar &

yad --title="Info" --width=300 --height=100 --text="✅ MicroEmulator Avatar sedang berjalan!" --button="OK:0" --timeout=2 --image="dialog-information" &
exit 0
EOF

RUN chmod +x /usr/local/bin/*.sh

# === DESKTOP LAUNCHERS ===
RUN cat >/root/Desktop/Avatar.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Avatar
Comment=Jalankan MicroEmulator Avatar
Exec=/usr/local/bin/avatar.sh
Icon=applications-games
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
Icon=system-lock-screen
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
Icon=terminal
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
Icon=system-log-out
Terminal=false
Categories=System;
EOF

RUN chmod +x /root/Desktop/*.desktop

# === JWM CONFIG ===
RUN cat >/root/.jwmrc <<'EOF'
<?xml version="1.0"?>
<JWM>
    <RootMenu label="Menu" height="24">
        <Program label="Terminal" icon="terminal">xterm</Program>
        <Program label="Avatar" icon="applications-games">/usr/local/bin/avatar.sh</Program>
        <Program label="Ganti Password" icon="system-lock-screen">/usr/local/bin/password.sh</Program>
        <Separator/>
        <Program label="Logout" icon="system-log-out">pkill -KILL -u root</Program>
        <Separator/>
        <Restart label="Restart JWM" icon="system-restart"/>
        <Exit label="Exit JWM" icon="system-shutdown" confirm="true"/>
    </RootMenu>

    <TaskList/>
    <Tray x="0" y="-1" height="28" autohide="off">
        <TrayButton icon="menu">root:3</TrayButton>
        <Spacer width="5"/>
        <TaskList/>
        <Dock/>
        <Clock format="%H:%M">xclock</Clock>
    </Tray>

    <WindowStyle>
        <Font>DejaVu Sans-10</Font>
        <Width>4</Width>
        <Height>20</Height>
        <Active>
            <Foreground>#ffffff</Foreground>
            <Background>#3465a4</Background>
        </Active>
        <Inactive>
            <Foreground>#888888</Foreground>
            <Background>#d3d3d3</Background>
        </Inactive>
    </WindowStyle>

    <Desktop>
        <Background type="solid">#2e3436</Background>
    </Desktop>

    <Key key="Up">up</Key>
    <Key key="Down">down</Key>
    <Key key="Left">left</Key>
    <Key key="Right">right</Key>
    <Key key="h">left</Key>
    <Key key="j">down</Key>
    <Key key="k">up</Key>
    <Key key="l">right</Key>
    <Key key="Return">select</Key>
    <Key key="Escape">escape</Key>
    <Key key="F12">root:3</Key>

    <Program label="xterm" icon="terminal">xterm</Program>
    <Program label="xcalc" icon="accessories-calculator">xcalc</Program>

    <StartupCommand>rox -p /root/.config/rox.sourceforge.net/ROX-Filer/pinboard</StartupCommand>
</JWM>
EOF

# === ROX-Filer PINBOARD ===
RUN cat >/root/.config/rox.sourceforge.net/ROX-Filer/pinboard <<'EOF'
<?xml version="1.0"?>
<pinboard>
  <backdrop style="Scaled">/usr/share/backgrounds/default.png</backdrop>
  <icon x="20" y="20" label="Avatar">/root/Desktop/Avatar.desktop</icon>
  <icon x="20" y="90" label="Ganti Password">/root/Desktop/Ganti-Password.desktop</icon>
  <icon x="20" y="160" label="Terminal">/root/Desktop/Terminal.desktop</icon>
  <icon x="20" y="230" label="Logout">/root/Desktop/Logout.desktop</icon>
</pinboard>
EOF

# === ROX-Filer OPTIONS ===
RUN cat >/root/.config/rox.sourceforge.net/ROX-Filer/Options <<'EOF'
[rox]
show_thumnails=1
pinboard_size=48
pinboard_show_icons=1
pinboard_show_names=1
pinboard_use_symlinks=0
pinboard_warn_rename=1
pinboard_warn_delete=1
EOF

EXPOSE 6080
CMD ["/usr/local/bin/start.sh"]
