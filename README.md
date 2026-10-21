# OpenVPN + PKI — Lab ESEO

Mise en place d'une PKI (Easy-RSA) et d'un serveur OpenVPN sur une passerelle **Secure**, pour protéger les échanges vers une VM **Serveur** isolée. Projet réalisé dans le cadre du cours Sécurité des échanges (ESEO).

Ce dépôt sert de mémo réutilisable : scripts, modèles de configuration et déroulé de démo, pour pouvoir remonter le lab rapidement (nouvelle VM, nouvelle séance, ou révision avant l'oral).

## Architecture du lab

```
   Client (Debian 12)                Secure                      Serveur
  ┌──────────────────┐   réseau   ┌───────────────┐   réseau   ┌──────────────┐
  │                   │  bridge    │ passerelle NAT │  privé     │ mariadb      │
  │  tunnel OpenVPN ──┼───────────▶│ + serveur      │───────────▶│ telnet       │
  │  (tun0, 10.8.0.x) │            │ OpenVPN (CA)   │            │ apache2      │
  └──────────────────┘            └───────────────┘            │ vsftpd       │
                                                                  └──────────────┘
```

- **Secure** héberge la CA Easy-RSA, le serveur OpenVPN (`10.8.0.0/24`) et fait la passerelle NAT vers le réseau privé de Serveur.
- **Serveur** n'a pas d'accès direct depuis l'extérieur : tout passe par Secure.
- **Client** est une VM Debian 12 en mode bridge, qui rejoint Secure par le tunnel.

## Contenu du dépôt

| Fichier | Rôle |
|---|---|
| `scripts/generate_ovpn.sh` | À lancer **sur le client** : génère le fichier `.ovpn` à partir des certificats déjà présents dans le dossier courant. |
| `scripts/generate_and_send.sh` | À lancer **sur Secure**, après signature d'un client : génère le `.ovpn` et envoie par `scp` tout ce qui peut circuler (`ca.crt`, le certificat client, `vpn.key`, le `.ovpn`) — **jamais la clé privée du client**, qui ne quitte jamais sa machine. |
| `config-templates/server.conf.example` | Modèle de configuration serveur OpenVPN. |
| `config-templates/client.ovpn.example` | Modèle de fichier client, pour référence. |
| `docs/demo-sequencement.md` | Déroulé complet de la démo attendue (nouveau client → attaque sans VPN → activation du VPN → attaque non protégée par le VPN). |
| `docs/pki-notes.md` | Rappels sur la PKI, les commandes Easy-RSA, et les pièges rencontrés pendant ce lab. |

Les vraies clés, certificats et fichiers `.ovpn` du lab **ne sont pas dans ce dépôt** (voir `.gitignore`) : ce sont des secrets propres à chaque instance du lab, à ne jamais publier.

## Mise en place rapide

### 1. Sur Secure : créer la PKI et le serveur

```bash
apt install openvpn easy-rsa
make-cadir ~/pki && cd ~/pki
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa gen-req server nopass
./easyrsa sign-req server server
openvpn --genkey secret vpn.key

cp pki/ca.crt pki/issued/server.crt pki/private/server.key vpn.key /etc/openvpn/server/
```

Adapter `config-templates/server.conf.example` à son réseau (voir les commentaires dans le fichier), le copier dans `/etc/openvpn/server/server.conf`, puis :

```bash
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf && sysctl -p
systemctl enable --now openvpn-server@server
```

### 2. Sur le client : générer sa clé et sa demande

```bash
apt install openvpn easy-rsa
make-cadir ~/pki && cd ~/pki
./easyrsa init-pki
./easyrsa gen-req client1 nopass
scp pki/reqs/client1.req root@<IP_Secure>:/root/
```

La clé privée (`pki/private/client1.key`) **reste sur le client**.

### 3. Sur Secure : signer et envoyer

```bash
cd ~/pki
./easyrsa import-req /root/client1.req client1
./easyrsa sign-req client client1

./scripts/generate_and_send.sh client1 <user@IP_client> <IP_Secure>
```

### 4. Sur le client : finaliser et se connecter

```bash
cp ~/pki/pki/private/client1.key ~/client-vpn/
chmod 600 ~/client-vpn/client1.key ~/client-vpn/vpn.key
openvpn --config ~/client-vpn/client1.ovpn
```

Voir `docs/demo-sequencement.md` pour la suite (démonstration des attaques, avec et sans VPN).

## Sécurité — à retenir

- La **clé privée de la CA** (`pki/private/ca.key`) ne quitte jamais Secure.
- La **clé privée de chaque client** ne quitte jamais ce client : seule la demande de certificat (`.req`) circule.
- Les attaques de démonstration (brute-force, injection, capture réseau) sont réalisées uniquement sur des VMs et des comptes de test créés pour ce lab.
