FROM alpine:latest

ENV DISPLAY=:1 \
    HOME=/root

# Install packages
RUN apk add --no-cache \
    openjdk17-jre \
    firefox \
    xvfb \
    x11vnc \
    jwm \
    wget \
    unzip \
    ttf-dejavu \
    fontconfig \
    xterm \
    mesa-dri-gallium

# Download MicroEmulator
RUN mkdir -p /opt/microemulator \
    && wget -q https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/microemu/microemulator-2.0.4.zip \
       -O /tmp/microemulator.zip \
    && unzip -q /tmp/microemulator.zip -d /opt/microemulator \
    && rm -f /tmp/microemulator.zip

# Download Avatar
RUN wget -q https://files.catbox.moe/sllphh.ja \
    -O /opt/microemulator/avatar.jar

# MicroEmulator launcher
RUN cat >/usr/local/bin/microemu <<'EOF'
#!/bin/sh
exec java \
-noverify \
-Xms16m \
-Xmx64m \
-XX:+UseSerialGC \
-XX:MaxRAM=64m \
-jar /opt/microemulator/microemulator-2.0.4/microemulator.jar \
/opt/microemulator/avatar.jar
EOF

RUN chmod +x /usr/local/bin/microemu

# Change VNC Password
RUN cat >/usr/local/bin/change-vnc-password <<'EOF'
#!/bin/sh

mkdir -p /root/.vnc

xterm -title "Change VNC Password" -e sh -c '

echo
echo "=== Change VNC Password ==="
echo

x11vnc -storepasswd /root/.vnc/passwd

echo
echo "Restarting VNC..."

killall x11vnc

sleep 1

x11vnc \
-display :1 \
-rfbport 5901 \
-rfbauth /root/.vnc/passwd \
-forever \
-shared &

echo
echo "Done."
sleep 2
'
EOF

RUN chmod +x /usr/local/bin/change-vnc-password

# JWM
RUN cat >/root/.jwmrc <<'EOF'
<?xml version="1.0"?>

<JWM>

<StartupCommand>xsetroot -solid black</StartupCommand>

<RootMenu onroot="12">

    <Program label="Firefox">
        firefox
    </Program>

    <Program label="MicroEmulator">
        microemu
    </Program>

    <Program label="Terminal">
        xterm
    </Program>

    <Program label="Change VNC Password">
        change-vnc-password
    </Program>

    <Separator/>

    <Exit label="Exit"/>

</RootMenu>

<Tray x="0" y="-1" height="28">

    <TrayButton label="Menu">
        root:1
    </TrayButton>

    <TrayButton label="Firefox">
        exec:firefox
    </TrayButton>

    <TrayButton label="MicroEmulator">
        exec:microemu
    </TrayButton>

    <Spacer/>

    <Clock format="%H:%M"/>

</Tray>

<Desktops width="1" height="1"/>

</JWM>
EOF

# Startup
RUN cat >/startup.sh <<'EOF'
#!/bin/sh

export DISPLAY=:1

mkdir -p /root/.vnc

# Buat password default jika belum ada
if [ ! -f /root/.vnc/passwd ]; then
    x11vnc -storepasswd 123456 /root/.vnc/passwd >/dev/null
fi

Xvfb :1 -screen 0 800x600x16 &

sleep 2

jwm &

exec x11vnc \
-display :1 \
-rfbport 5901 \
-rfbauth /root/.vnc/passwd \
-forever \
-shared
EOF

RUN chmod +x /startup.sh

# Cleanup
RUN rm -rf \
    /var/cache/apk/* \
    /tmp/* \
    /root/.cache

EXPOSE 5901

WORKDIR /root

CMD ["/startup.sh"]
