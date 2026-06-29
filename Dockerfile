FROM alpine:latest

# Set environment variables
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NOVNC_PORT=6080 \
    VNC_RESOLUTION=800x600 \
    VNC_DEPTH=16 \
    JAVA_OPTS="-Xms16m -Xmx64m -XX:+UseSerialGC -XX:MaxRAM=64m" \
    HOME=/root

# Install only essential packages
RUN apk add --no-cache \
    openjdk17-jre \
    firefox \
    tigervnc \
    jwm \
    xterm \
    wget \
    unzip \
    dbus-x11 \
    ttf-dejavu \
    mesa-dri-gallium \
    python3 \
    py3-pip \
    && pip3 install --break-system-packages --no-cache-dir websockify \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Setup noVNC
RUN wget -q https://github.com/novnc/noVNC/archive/refs/tags/v1.4.0.tar.gz -O /tmp/novnc.tar.gz \
    && mkdir -p /opt/novnc \
    && tar -xzf /tmp/novnc.tar.gz -C /opt/novnc --strip-components=1 \
    && rm /tmp/novnc.tar.gz \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# Setup MicroEmulator
RUN mkdir -p /opt/microemulator \
    && wget -q https://github.com/microemu/microemu/releases/download/v2.0.4/microemulator-2.0.4.zip -O /tmp/microemulator.zip \
    && unzip -q /tmp/microemulator.zip -d /opt/microemulator \
    && rm /tmp/microemulator.zip \
    && chmod +x /opt/microemulator/microemulator.jar

# Download Avatar JAR
RUN wget -q https://github.com/microemu/microemu/releases/download/v2.0.4/avatar.jar -O /opt/microemulator/avatar.jar

# Create minimal JWM configuration
RUN mkdir -p /root/.jwm \
    && echo '<?xml version="1.0"?>' > /root/.jwm/jwmrc \
    && echo '<JWM>' >> /root/.jwm/jwmrc \
    && echo '  <RootMenu onroot="12"/>' >> /root/.jwm/jwmrc \
    && echo '  <Tray x="0" y="-1" autohide="off">' >> /root/.jwm/jwmrc \
    && echo '    <TrayButton label="Menu">root:1</TrayButton>' >> /root/.jwm/jwmrc \
    && echo '    <Spacer width="2"/>' >> /root/.jwm/jwmrc \
    && echo '    <TrayButton label="Firefox">exec:firefox</TrayButton>' >> /root/.jwm/jwmrc \
    && echo '    <TrayButton label="MicroEmulator">exec:xterm -e java -jar /opt/microemulator/microemulator.jar /opt/microemulator/avatar.jar</TrayButton>' >> /root/.jwm/jwmrc \
    && echo '    <Spacer/>' >> /root/.jwm/jwmrc \
    && echo '    <Clock/>' >> /root/.jwm/jwmrc \
    && echo '  </Tray>' >> /root/.jwm/jwmrc \
    && echo '  <Menu label="Applications" icon="folder.png">' >> /root/.jwm/jwmrc \
    && echo '    <Program label="Firefox">firefox</Program>' >> /root/.jwm/jwmrc \
    && echo '    <Program label="MicroEmulator">xterm -e java -jar /opt/microemulator/microemulator.jar /opt/microemulator/avatar.jar</Program>' >> /root/.jwm/jwmrc \
    && echo '    <Program label="Terminal">xterm</Program>' >> /root/.jwm/jwmrc \
    && echo '  </Menu>' >> /root/.jwm/jwmrc \
    && echo '</JWM>' >> /root/.jwm/jwmrc

# Create minimal VNC startup script
RUN echo '#!/bin/sh' > /startup.sh \
    && echo 'export DISPLAY=:1' >> /startup.sh \
    && echo 'mkdir -p /root/.vnc' >> /startup.sh \
    && echo 'echo "#!/bin/sh" > /root/.vnc/xstartup' >> /startup.sh \
    && echo 'echo "jwm &" >> /root/.vnc/xstartup' >> /startup.sh \
    && echo 'chmod +x /root/.vnc/xstartup' >> /startup.sh \
    && echo '' >> /startup.sh \
    && echo '# Start VNC server' >> /startup.sh \
    && echo 'vncserver :1 -geometry 800x600 -depth 16 -localhost -SecurityTypes None' >> /startup.sh \
    && echo '' >> /startup.sh \
    && echo '# Start noVNC with websockify' >> /startup.sh \
    && echo 'websockify --web /opt/novnc 6080 localhost:5901' >> /startup.sh \
    && chmod +x /startup.sh

# Clean up unnecessary files
RUN rm -rf /var/cache/apk/* /tmp/* /var/tmp/* /root/.cache/* \
    && find /usr/share -type d -name doc -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/share -type d -name man -exec rm -rf {} + 2>/dev/null || true \
    && find /usr/share -type d -name locale -exec rm -rf {} + 2>/dev/null || true

EXPOSE 6080

WORKDIR /root

CMD ["/startup.sh"]
