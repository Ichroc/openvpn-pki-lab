#!/bin/bash
# Génère un fichier .ovpn pour un client OpenVPN, à lancer depuis ~/client-vpn
# Usage : ./generate_ovpn.sh <nom_client> <IP_secure> [port]

set -e

CLIENT_NAME="$1"
REMOTE_IP="$2"
REMOTE_PORT="${3:-1194}"

if [ -z "$CLIENT_NAME" ] || [ -z "$REMOTE_IP" ]; then
    echo "Usage : $0 <nom_client> <IP_secure> [port]"
    echo "Exemple : $0 client3 192.168.4.147"
    exit 1
fi

OVPN_FILE="${CLIENT_NAME}.ovpn"

# Vérifie que les fichiers nécessaires sont présents dans le dossier courant
for f in "ca.crt" "${CLIENT_NAME}.crt" "${CLIENT_NAME}.key" "vpn.key"; do
    if [ ! -f "$f" ]; then
        echo "Fichier manquant : $f (attendu dans le dossier courant)"
        exit 1
    fi
done

cat > "$OVPN_FILE" <<EOF
client
dev tun
proto udp
remote ${REMOTE_IP} ${REMOTE_PORT}
remote-cert-tls server
tls-crypt vpn.key
data-ciphers AES-256-GCM
nobind
persist-key
persist-tun
ca ca.crt
cert ${CLIENT_NAME}.crt
key ${CLIENT_NAME}.key
EOF

chmod 600 "${CLIENT_NAME}.key" vpn.key

echo "Fichier créé : ${OVPN_FILE}"
echo "Lancement : openvpn --config ${OVPN_FILE}"
