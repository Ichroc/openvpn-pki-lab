#!/bin/bash
# À lancer sur Secure, depuis ~/pki, APRÈS avoir signé le client.
# Génère le .ovpn du client et envoie les fichiers nécessaires (sauf la clé
# privée, qui reste exclusivement sur le client).
#
# Usage : ./generate_and_send.sh <nom_client> <user@IP_client> <IP_secure> [port] [chemin_distant]

set -e

CLIENT_NAME="$1"
CLIENT_DEST="$2"           # ex: etudiant@192.168.4.85
REMOTE_IP="$3"             # IP de Secure, côté réseau externe
REMOTE_PORT="${4:-1194}"
REMOTE_PATH="${5:-/home/etudiant/client-vpn}"

if [ -z "$CLIENT_NAME" ] || [ -z "$CLIENT_DEST" ] || [ -z "$REMOTE_IP" ]; then
    echo "Usage : $0 <nom_client> <user@IP_client> <IP_secure> [port] [chemin_distant]"
    echo "Exemple : $0 client3 etudiant@192.168.4.85 192.168.4.147"
    exit 1
fi

CA_CRT="pki/ca.crt"
CLIENT_CRT="pki/issued/${CLIENT_NAME}.crt"
TLS_KEY="vpn.key"

for f in "$CA_CRT" "$CLIENT_CRT" "$TLS_KEY"; do
    if [ ! -f "$f" ]; then
        echo "Fichier manquant : $f"
        echo "As-tu bien lancé ./easyrsa sign-req client ${CLIENT_NAME} avant ?"
        exit 1
    fi
done

WORKDIR=$(mktemp -d)
OVPN_FILE="${WORKDIR}/${CLIENT_NAME}.ovpn"

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

echo "Fichier .ovpn généré : $OVPN_FILE"

echo "Création du dossier distant si besoin..."
ssh "${CLIENT_DEST%:*}" "mkdir -p ${REMOTE_PATH}"

echo "Envoi des fichiers vers ${CLIENT_DEST}:${REMOTE_PATH}/ ..."
scp "$CA_CRT" "$CLIENT_CRT" "$TLS_KEY" "$OVPN_FILE" "${CLIENT_DEST}:${REMOTE_PATH}/"

echo ""
echo "Envoyé : ca.crt, ${CLIENT_NAME}.crt, vpn.key, ${CLIENT_NAME}.ovpn"
echo ""
echo "RAPPEL : ${CLIENT_NAME}.key n'a PAS été envoyée (elle ne quitte jamais le client)."
echo "Sur le client, vérifie qu'elle est bien présente dans ${REMOTE_PATH}/ :"
echo "  cp ~/pki/pki/private/${CLIENT_NAME}.key ${REMOTE_PATH}/"
echo "  chmod 600 ${REMOTE_PATH}/${CLIENT_NAME}.key ${REMOTE_PATH}/vpn.key"

rm -rf "$WORKDIR"
