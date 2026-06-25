FROM --platform=linux/amd64 alpine:3.19

ENV DISPLAY=:1

# Install packages
RUN apk add --no-cache \
    bash \
    xvfb \
    x11vnc \
    websockify \
    openjdk17-jre \
    wget \
    unzip \
    findutils

# Download MicroEmulator
RUN mkdir -p /opt && \
    wget -q -O /tmp/microemu.zip \
    https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/microemu/microemulator-2.0.4.zip && \
    unzip -q /tmp/microemu.zip -d /opt && \
    rm -f /tmp/microemu.zip

# Download Avatar
RUN mkdir -p /opt/avatar && \
    wget -q -O /tmp/avatar.zip \
    https://files.catbox.moe/6q19o1.zip && \
    unzip -q /tmp/avatar.zip -d /opt/avatar && \
    rm -f /tmp/avatar.zip

# Password VNC default
RUN mkdir -p /root/.vnc && \
    x11vnc -storepasswd 123456 /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Script ganti password
RUN cat >/usr/local/bin/password <<'EOF'
#!/bin/sh

echo
echo "=== GANTI PASSWORD VNC ==="
echo

printf "Password baru: "
stty -echo
read NEWPASS
stty echo
echo

printf "Konfirmasi: "
stty -echo
read CONFIRM
stty echo
echo

if [ "$NEWPASS" != "$CONFIRM" ]; then
    echo "Password tidak sama."
    exit 1
fi

if [ -z "$NEWPASS" ]; then
    echo "Password kosong."
    exit 1
fi

pkill x11vnc 2>/dev/null

x11vnc -storepasswd "$NEWPASS" /root/.vnc/passwd

x11vnc \
-display :1 \
-rfbauth /root/.vnc/passwd \
-forever \
-shared \
-rfbport 5901 &

echo
echo "Password berhasil diganti."
EOF

RUN chmod +x /usr/local/bin/ganti-password

# Script start
RUN cat >/root/start.sh <<'EOF'
#!/bin/sh

export DISPLAY=:1

Xvfb :1 -screen 0 800x600x24 &
sleep 2

EMU=$(find /opt -name "microemulator.jar" | head -n1)
GAME=$(find /opt/avatar -name "*.jar" | head -n1)

echo "MicroEmulator : $EMU"
echo "Game           : $GAME"

java -jar "$EMU" "$GAME" &
sleep 5

x11vnc \
-display :1 \
-rfbauth /root/.vnc/passwd \
-forever \
-shared \
-rfbport 5901 &

websockify 6080 localhost:5901 &

echo
echo "=================================="
echo "Container berjalan."
echo "Port VNC : 6080"
echo "Password : 123456"
echo "=================================="

tail -f /dev/null
EOF

RUN chmod +x /root/start.sh

EXPOSE 6080

CMD ["/bin/sh","/root/start.sh"]
