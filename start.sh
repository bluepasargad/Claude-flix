#!/bin/sh

# --- Edit these two lines after checking the Network page ---
PUBLIC_PORT="${PUBLIC_PORT:-443}"     # direct-port mode: put the real port here, e.g. 20541
SECURITY="${SECURITY:-tls}"          # direct-port mode: use none
# ------------------------------------------------------------

if [ -z "$UUID" ]; then
  mkdir -p /home/container 2>/dev/null
  UF=/home/container/uuid
  [ -w /home/container ] || UF=/tmp/uuid
  [ -f "$UF" ] || cat /proc/sys/kernel/random/uuid > "$UF"
  UUID=$(cat "$UF")
fi
export UUID

export DOMAIN="${DOMAIN:-${RAILWAY_PUBLIC_DOMAIN:-app222.falixsrv.me}}"
export PORT="${PORT:-8080}"
export WS_PATH="${WS_PATH:-/ws}"
export SUB_PATH="${SUB_PATH:-/sub}"
NAME="${NAME_PREFIX:-node}"

ENC=$(printf %s "$WS_PATH" | sed 's#/#%2F#g')
if [ "$SECURITY" = "tls" ]; then
  LINK="vless://${UUID}@${DOMAIN}:${PUBLIC_PORT}?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=${ENC}#${NAME}"
else
  LINK="vless://${UUID}@${DOMAIN}:${PUBLIC_PORT}?encryption=none&security=none&type=ws&host=${DOMAIN}&path=${ENC}#${NAME}"
fi
export SUB_B64=$(printf %s "$LINK" | base64 -w0)

echo "PORT env = $PORT"
echo "=== LINK ==="
echo "$LINK"
echo "============"

cat > /tmp/x.json <<EOF
{
"log": {"loglevel": "none"},
"inbounds": [{
"listen": "127.0.0.1", "port": 10000, "protocol": "vless",
"settings": {"clients": [{"id": "${UUID}"}], "decryption": "none"},
"streamSettings": {"network": "ws", "wsSettings": {"path": "${WS_PATH}"}}
}],
"outbounds": [{"protocol": "freedom"}]
}
EOF

xray run -c /tmp/x.json &
sh ./hy2.sh &
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
