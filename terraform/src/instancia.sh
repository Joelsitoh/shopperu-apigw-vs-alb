#!/bin/bash
# Servicio de catalogo en cada instancia EC2 (puerto 8080)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
INSTANCIA=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
ZONA=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /opt/catalogo.py <<EOF
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PRODUCTOS = [
    {"id": 1, "nombre": "Polo de algodon", "precio": 39.9, "stock": 25},
    {"id": 2, "nombre": "Zapatillas urbanas", "precio": 189.0, "stock": 8},
]

class Catalogo(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/salud":
            cuerpo = {"estado": "ok"}
        elif self.path == "/productos":
            cuerpo = {"origen": "alb-ec2", "atendidoPor": "$INSTANCIA", "zona": "$ZONA", "productos": PRODUCTOS}
        else:
            self.send_response(404)
            self.end_headers()
            return
        datos = json.dumps(cuerpo).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(datos)))
        self.end_headers()
        self.wfile.write(datos)

    def log_message(self, *args):
        pass

ThreadingHTTPServer(("0.0.0.0", 8080), Catalogo).serve_forever()
EOF

cat > /etc/systemd/system/catalogo.service <<EOF
[Unit]
Description=Catalogo ShopPeru
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/catalogo.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now catalogo
