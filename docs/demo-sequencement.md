# Déroulé de la démonstration

Séquencement attendu : création d'un nouveau client → attaque sans VPN → activation du VPN → (option) attaque que le VPN ne protège pas.

## 1. Création d'un nouveau client

Expliquer les 4 temps, en s'appuyant sur le diagramme de séquence PKI :

1. **Client** : génère sa clé privée + une demande (`gen-req`). La clé privée ne quitte jamais le client.
2. **Envoi** de la demande (`.req`) à la CA, sur Secure.
3. **Secure** : la CA importe la demande (`import-req`) puis la signe (`sign-req`). La clé privée de la CA ne quitte jamais Secure.
4. **Retour** du certificat signé, de `ca.crt` et de `vpn.key` vers le client (voir `scripts/generate_and_send.sh`), puis création du `.ovpn`.

Utiliser un nom de client inédit pour chaque démo (ex. `client2`, `client3`), pour que ce soit un vrai "nouveau client".

## 2. Attaque sans VPN

Sur Secure, capturer le trafic sur l'interface externe :
```bash
tcpdump -i <interface_externe> -w sans_vpn.pcap port 23 or port 80 or port 3306
```

Depuis le client, VPN éteint, se connecter à Secure sur un service en clair (telnet, HTTP, ou MariaDB selon le lab).

Ouvrir la capture dans Wireshark (*Follow TCP Stream*) : identifiants et contenu lisibles en clair.

## 3. Activation du VPN

Sur le client :
```bash
openvpn --config <nom_client>.ovpn
ip a show tun0
ping <IP_interne_Serveur>
```

Nouvelle capture sur Secure, même interface externe : seul du trafic UDP 1194 chiffré est visible.

Même manipulation que l'étape 2, mais vers l'adresse interne de Serveur à travers le tunnel.

**Piège à éviter** : capturer sur `tun0` montre le trafic déjà déchiffré — toujours capturer sur l'interface externe pour que la démonstration soit honnête.

## 4. (Option) Attaque que le VPN ne protège pas

Le VPN protège le **transport**, pas l'**authentification** ni l'**application**. Démonstration possible, à travers le tunnel actif :

```bash
hydra -l <compte_de_test> -P mini-liste.txt ssh://<IP_interne_Serveur>
```

(SSH est plus fiable que telnet pour ce test avec hydra.)

**Conclusion à formuler** : même chiffré par le VPN, un mot de passe faible reste devinable, et un client compromis conserverait son accès au tunnel. Le compte de test et son mot de passe sont créés uniquement pour cette démonstration et supprimés ensuite.

## Préparation

- Vérifier l'IP externe actuelle de Secure avant chaque séance (`ip a`), si elle est attribuée par DHCP.
- Avoir un compte de test dédié sur Serveur, non réutilisé ailleurs.
- Garder les deux fichiers `.pcap` (avec/sans VPN) et des captures d'écran de chaque étape : réutilisables pour l'article à rendre.
