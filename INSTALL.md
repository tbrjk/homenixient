# INSTALL — installer / redéployer homenixient

L'installation est **guidée par `install.sh`** : il pose les questions, écrit
`settings.nix`, chiffre le disque, génère la config matérielle et installe. Tu
n'édites aucun fichier à la main.

> ⚠️ **Sauvegarde d'abord.** L'installation neuve **efface** le disque cible.

---

## Méthode recommandée : `install.sh`

### 1. Démarrer sur l'ISO NixOS

Grave l'ISO (https://nixos.org/download) sur une clé USB, démarre la machine
dessus. Branche le réseau :

- **Ethernet** : rien à faire.
- **Wi-Fi** :
  ```bash
  sudo systemctl start wpa_supplicant
  wpa_cli
  > add_network
  > set_network 0 ssid "MonSSID"
  > set_network 0 psk "MotDePasse"
  > enable_network 0
  > quit
  ```
  Vérifier : `ping -c1 nixos.org`.

### 2. Trois commandes

```bash
git clone https://github.com/tbrjk/homenixient
cd homenixient
./install.sh
```

> `git` est présent sur l'ISO NixOS. S'il manque : `nix-shell -p git` d'abord.

### 3. Répondre aux questions

`install.sh` demande : utilisateur, nom complet, email, hostname, fuseau,
clavier, locale, noyau récent (oui/non), extension pack VirtualBox (oui/non),
et **le disque à formater** — présenté sous forme de **liste numérotée**
(taille, bus, modèle), la clé USB d'installation étant automatiquement exclue :
tu tapes juste le numéro. Puis il récapitule et demande **confirmation** avant
d'effacer quoi que ce soit.

### 4. Ce qu'il fait ensuite, tout seul

1. formate + chiffre le disque (disko, LUKS2) — **il demande ta passphrase** ;
2. génère `hardware-configuration.nix` (sans filesystems, disko les fournit) ;
3. installe le système complet (`nixos-install`) ;
4. te fait définir les mots de passe **root** et **utilisateur** ;
5. copie le dépôt dans `~/homenixient` du nouveau système (pour les rebuilds).

### 5. Redémarrer

```bash
sudo reboot
```

Retire la clé USB. Au démarrage : passphrase du disque, puis écran de connexion
GNOME. Vérifie ensuite :

```bash
docker run --rm hello-world
VBoxManage --version
exegol version
```

---

## Redéployer (machine déjà installée)

Sur un homenixient déjà installé, depuis `~/homenixient` :

```bash
./install.sh          # détecte le mode « reconstruction »
# ou directement :
just build
```

Pour repartir de zéro sur une **autre** machine : reprends la commande de l'étape
2 depuis l'ISO. Comme `settings.nix` est versionné dans ton dépôt, la machine se
reconstruit à l'identique (pense à ajuster le disque cible si différent).

---

## Modes explicites

```bash
./install.sh              # menu (choisit automatiquement install vs rebuild)
./install.sh install      # force l'installation neuve (formate le disque)
./install.sh rebuild      # force la reconstruction du système courant
./install.sh --help
```

---

## Méthode manuelle (repli)

Si tu préfères tout piloter, ou en cas de souci avec le script. Étapes que
`install.sh` automatise :

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
nix shell nixpkgs#git
git clone https://github.com/tbrjk/homenixient && cd homenixient

# 1. Renseigner les réglages (dont le disque) :
$EDITOR settings.nix          # au minimum : disk = "/dev/disk/by-id/…"

# 2. Formater + chiffrer + monter (disko lit settings.nix) :
sudo nix run github:nix-community/disko/latest -- \
  --mode disko ./hosts/homenixient/disko.nix
#   (si '--mode disko' échoue : essayer '--mode destroy,format,mount')

# 3. Config matérielle SANS filesystems (disko les fournit) :
sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config \
  > hosts/homenixient/hardware-configuration.nix

# 4. Le flake ne voit que les fichiers suivis par git :
git add -A

# 5. Installer :
sudo nixos-install --flake .#homenixient

# 6. Mots de passe :
sudo nixos-enter --root /mnt -c "passwd root"
sudo nixos-enter --root /mnt -c "passwd <utilisateur>"

# 7. Redémarrer :
sudo reboot
```

---

## Dépannage

| Symptôme | Cause | Solution |
|----------|-------|----------|
| `error: … does not exist` | fichier non suivi par git | `git add -A` (install.sh le fait) |
| `fileSystems … defined multiple times` | hardware-config AVEC filesystems + disko | régénérer avec `--no-filesystems` |
| `--mode disko` refusé | version de disko | utiliser `--mode destroy,format,mount` |
| `cannot find device …` au boot | disque `/dev/sda` qui a changé | mettre un `/dev/disk/by-id/…` dans settings.nix |
| `experimental feature 'flakes' … disabled` | flakes non activés | `export NIX_CONFIG="experimental-features = nix-command flakes"` |
| VirtualBox ne démarre pas après un build | noyau trop récent | `kernelLatest = false` dans settings.nix, puis `just build` |
| `Out of memory` / `No space left` pendant l'install | RAM de l'ISO saturée par un gros build | `virtualboxExtensionPack = false` (l'activer après le 1er boot) ; install.sh ajoute déjà swap + TMPDIR sur le disque |

---

## Rappels sécurité

- **Passphrase LUKS forte** : seule protection des données en cas de perte/vol.
- **Mot de passe firmware UEFI** + ordre de démarrage verrouillé : empêche le
  contournement par démarrage sur clé USB.
- **`settings.nix` ne contient aucun secret** (pas de mot de passe) → publiable
  sur GitHub. Les mots de passe se définissent à l'installation, hors dépôt.
- Pour de vrais secrets plus tard (VPN auto, tokens…) : `sops-nix`/`agenix`
  (voir `docs/DOCUMENTATION.md`).
