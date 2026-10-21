# Notes PKI — rappels et pièges rencontrés

## Principe

- La **CA** (Certificate Authority) signe les certificats du serveur et des clients.
- Chaque machine génère **sa propre clé privée** et n'envoie à la CA qu'une **demande de certificat** (`.req`), jamais la clé.
- La CA ne possède donc jamais les clés privées du serveur ou des clients — seulement leurs certificats signés.
- `ca.crt` (la clé **publique** de la CA) doit être présent sur toutes les machines, pour qu'elles vérifient la signature des certificats qu'elles reçoivent.

## Commandes de base (Easy-RSA 3)

```bash
./easyrsa init-pki                      # initialise une PKI vide
./easyrsa build-ca nopass               # crée ca.crt + la clé privée de la CA
./easyrsa gen-req <nom> nopass          # génère une clé privée + une demande
./easyrsa import-req <fichier.req> <nom>  # importe une demande reçue d'ailleurs
./easyrsa sign-req server <nom>         # signe une demande de type "serveur"
./easyrsa sign-req client <nom>         # signe une demande de type "client"
```

## Pièges rencontrés pendant ce lab

- **Mot de passe de la CA refusé (`Could not find CA private key`, `maybe wrong password`)**
  Vérifier la disposition clavier de la console (AZERTY/QWERTY peut changer le mot de passe tapé). En dernier recours sur un lab, refaire la CA avec `build-ca nopass` pour éviter le problème, puis re-signer serveur et clients.

- **`import-req: No request found`**
  Le fichier `.req` n'est pas au bon endroit, ou a déjà été importé/signé une première fois. Vérifier avec `ls pki/issued/` si un certificat du même nom existe déjà.

- **`Conflicting certificate exists`**
  Un certificat avec ce nom a déjà été signé. Soit c'est voulu (pas besoin de re-signer), soit il faut choisir un nouveau nom (`client2`, `client3`, …) plutôt que de réutiliser le même.

- **`tls-crypt unwrap error: packet too short`**
  Le fichier `vpn.key` du client ne correspond pas à celui du serveur. Comparer les empreintes :
  ```bash
  sha256sum vpn.key   # sur le client et sur Secure : doivent être identiques
  ```

- **`private key password verification failed` / `key values mismatch`**
  Le certificat (`.crt`) et la clé privée (`.key`) ne correspondent pas (souvent après avoir régénéré une clé avec `gen-req` sans resigner, ou mélangé les fichiers de deux clients différents). Vérifier :
  ```bash
  openssl x509 -in <nom>.crt -noout -pubkey | sha256sum
  openssl pkey -in <nom>.key -pubout | sha256sum
  # les deux empreintes doivent être identiques
  ```
  En cas de doute, le plus simple est de repartir sur un nouveau nom de client.

- **`TLS Error: TLS key negotiation failed to occur within 60 seconds`**
  Le client n'a reçu aucune réponse du serveur. Dans l'ordre, vérifier :
  1. L'IP de `remote` dans le `.ovpn` est-elle toujours la bonne ? (l'IP externe de Secure peut changer si elle est en DHCP — revérifier avec `ip a`)
  2. Le serveur OpenVPN tourne-t-il (`systemctl status openvpn-server@server`) ?
  3. Le pare-feu laisse-t-il passer l'UDP 1194 (`iptables -L INPUT -n`) ?
  4. Les paquets arrivent-ils jusqu'à Secure (`tcpdump -ni <interface_externe> udp port 1194`) ?
