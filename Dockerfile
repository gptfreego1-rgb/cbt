FROM --platform=linux/amd64 alpine:3.19

ENV DISPLAY=:1

RUN apk add --no-cache \
    bash \
    xvfb \
    x11vnc \
    websockify \
    openjdk17-jre \
    wget \
    unzip \
    findutils \
    fontconfig \
    ttf-dejavu

# Download MicroEmulator
RUN wget -q -O /tmp/microemu.zip \
https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/microemu/microemulator-2.0.4.zip && \
unzip -q /tmp/microemu.zip -d /opt && \
rm -f /tmp/microemu.zip

# Download Avatar (sebenarnya JAR)
RUN mkdir -p /opt/avatar && \
wget -q -O /opt/avatar/avatar.jar \
https://files.catbox.moe/6q19o1.zip

# Password VNC
RUN mkdir -p /root/.vnc && \
x11vnc -storepasswd 123456 /root/.vnc/passwd && \
chmod 600 /root/.vnc/passwd

# Ganti password
RUN cat >/usr/local/bin/password <<'EOF'
#!/bin/sh

printf "Password baru: "
stty -echo
read PASS
stty echo
echo

[ -z "$PASS" ] && exit 1

pkill x11vnc 2>/dev/null

x11vnc -storepasswd "$PASS" /root/.vnc/passwd

x11vnc \
-display :1 \
-rfbauth /root/.vnc/passwd \
-forever \
-shared \
-rfbport 5901 &

echo "Password berhasil diganti."
EOF

RUN chmod +x /usr/local/bin/password

# Start
RUN cat >/root/start.sh <<'EOF'
#!/bin/sh

export DISPLAY=:1

Xvfb :1 -screen 0 800x600x24 &
sleep 2

EMU=/opt/microemulator-2.0.4/microemulator.jar
GAME=/opt/avatar/avatar.jar

echo "MicroEmulator : $EMU"
echo "Game : $GAME"

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
echo "Container berjalan"
echo "VNC : http://localhost:6080"
echo "Password : 123456"
echo "=================================="

tail -f /dev/null
EOF

RUN chmod +x /root/start.sh

EXPOSE 6080

CMD ["/bin/sh","/root/start.sh"]
