FROM --platform=linux/amd64 alpine:3.19

ENV DISPLAY=:1

# Install SUPER MINIMAL (cuma yang bener-bener perlu)
RUN apk add --no-cache \
    xvfb \
    x11vnc \
    websockify \
    openjdk17-jre \
    wget \
    unzip \
    bash \
    && rm -rf /var/cache/apk/*

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

# Script ganti password (via terminal doang, tanpa xterm)
RUN cat >/usr/local/bin/ganti-password <<'EOF'
#!/bin/bash
echo ""
echo "=== GANTI PASSWORD VNC ==="
echo ""
read -p "Password baru: " -s NEWPASS
echo ""
read -p "Konfirmasi: " -s CONFIRM
echo ""

if [ "$NEWPASS" != "$CONFIRM" ]; then
    echo "❌ Tidak sama!"
    exit 1
fi

if [ -z "$NEWPASS" ]; then
    echo "❌ Kosong!"
    exit 1
fi

pkill x11vnc 2>/dev/null
pkill websockify 2>/dev/null
sleep 1

echo "$NEWPASS" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

export DISPLAY=:1
x11vnc -display :1 -forever -passwd "$NEWPASS" -shared -rfbport 5901 &
websockify --web=/usr/share/novnc 6080 localhost:5901 &

echo "✅ Password: $NEWPASS"
EOF

RUN chmod +x /usr/local/bin/ganti-password

# Start script paling simpel
RUN cat >/root/start.sh <<'EOF'
#!/bin/bash
Xvfb :1 -screen 0 800x600x24 &
export DISPLAY=:1
sleep 2
java -jar /opt/microemulator/microemulator-2.0.4/microemulator.jar /opt/microemulator/avatar.jar &
sleep 3
x11vnc -display :1 -forever -passwd 123456 -shared -rfbport 5901 &
websockify --web=/usr/share/novnc 6080 localhost:5901 &

echo "✅ RUNNING"
echo "VNC: http://localhost:6080/vnc.html"
echo "Pass: 123456"
echo "Ganti pass: docker exec -it <container> ganti-password"
tail -f /dev/null
EOF

RUN chmod +x /root/start.sh

EXPOSE 6080
CMD ["/bin/bash","/root/start.sh"]
