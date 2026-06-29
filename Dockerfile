FROM alpine:latest

ENV DISPLAY=:1 \
    HOME=/root \
    JAVA_OPTS="-Xms16m -Xmx64m -XX:+UseSerialGC -XX:MaxRAM=64m"

# Install packages
RUN apk add --no-cache \
    openjdk17-jre \
    firefox \
    xvfb \
    x11vnc \
    jwm \
    xterm \
    wget \
    unzip \
    ttf-dejavu \
    fontconfig \
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

# Launcher
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

# JWM
RUN cat >/root/.jwmrc <<'EOF'
<?xml version="1.0"?>

<JWM>

<RootMenu onroot="12">

    <Program label="Firefox">
        firefox
    </Program>

    <Program label="MicroEmulator">
        xterm -e microemu
    </Program>

    <Program label="Terminal">
        xterm
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
        exec:xterm -e microemu
    </TrayButton>

    <Spacer/>

    <Clock/>

</Tray>

</JWM>
EOF

# Startup
RUN cat >/startup.sh <<'EOF'
#!/bin/sh

export DISPLAY=:1

Xvfb :1 -screen 0 800x600x16 &

sleep 2

jwm &

exec x11vnc \
    -display :1 \
    -rfbport 5901 \
    -forever \
    -shared \
    -nopw
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
