FROM --platform=linux/amd64 alpine:3.18

ENV DISPLAY=:1

RUN apk add --no-cache \
    xvfb \
    x11vnc \
    websockify \
    openjdk8-jre \
    bash \
    wget \
    unzip \
    && rm -rf /var/cache/apk/*

# Download MicroEmulator
RUN wget -q -O /tmp/microemu.zip \
https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/microemu/microemulator-2.0.4.zip \
&& unzip /tmp/microemu.zip -d /opt/microemulator \
&& rm /tmp/microemu.zip

RUN wget -q -O /opt/microemulator/avatar.jar \
https://files.catbox.moe/6q19o1.zip

# VNC Password default
RUN mkdir -p /root/.vnc && \
    printf "123456" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Web page sederhana untuk ganti password
RUN mkdir -p /root/web && \
    cat >/root/web/index.html <<'HTML'
<!DOCTYPE html>
<html>
<head><title>Ganti Password VNC</title></head>
<body style="font-family: Arial; text-align: center; padding: 50px;">
    <h2>Ganti Password VNC</h2>
    <form action="/change" method="post">
        <input type="password" name="newpass" placeholder="Password Baru" required><br><br>
        <input type="password" name="confirm" placeholder="Konfirmasi" required><br><br>
        <button type="submit">Ganti Password</button>
    </form>
</body>
</html>
HTML

# Script untuk handle web
RUN cat >/root/web-server.py <<'PYTHON'
#!/usr/bin/env python3
import http.server
import socketserver
import subprocess
import urllib.parse

PORT = 6081

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            with open('/root/web/index.html', 'rb') as f:
                self.wfile.write(f.read())
        else:
            super().do_GET()
    
    def do_POST(self):
        if self.path == '/change':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length).decode()
            params = urllib.parse.parse_qs(post_data)
            
            newpass = params.get('newpass', [''])[0]
            confirm = params.get('confirm', [''])[0]
            
            if newpass != confirm or not newpass:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b'Password tidak sama!')
                return
            
            # Ganti password
            subprocess.run(['pkill', 'x11vnc'])
            subprocess.run(['pkill', 'websockify'])
            subprocess.run(['printf', newpass, '|', 'vncpasswd', '-f'], 
                         stdout=open('/root/.vnc/passwd', 'w'))
            subprocess.Popen(['x11vnc', '-display', ':1', '-forever', 
                            '-passwd', newpass, '-shared', '-rfbport', '5901'])
            subprocess.Popen(['websockify', '--web=/usr/share/novnc', 
                            '6080', 'localhost:5901'])
            
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'Password berhasil diganti!')

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(('', PORT), Handler) as httpd:
    httpd.serve_forever()
PYTHON

# Start script
RUN cat >/root/start.sh <<'EOF'
#!/bin/bash
Xvfb :1 -screen 0 800x600x24 &
export DISPLAY=:1
sleep 2

java -jar /opt/microemulator/microemulator-2.0.4/microemulator.jar \
     /opt/microemulator/avatar.jar &
sleep 3

x11vnc -display :1 -forever -passwd 123456 -shared -rfbport 5901 &
websockify --web=/usr/share/novnc 6080 localhost:5901 &

# Web server untuk ganti password
python3 /root/web-server.py &

tail -f /dev/null
EOF

RUN chmod +x /root/start.sh

EXPOSE 6080 6081
CMD ["/bin/bash","/root/start.sh"]
