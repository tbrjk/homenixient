# homenixient

Base NixOS **stable, chiffrée et simple** : un système propre et reproductible,
avec la virtualisation prête à l'emploi (Docker, VirtualBox, Exegol). Les outils
(pentest ou autres) vivent dans les conteneurs/VM, pas sur le système lui-même.

> 🧭 **Tu débutes sur NixOS ?** Lis d'abord [`docs/DOCUMENTATION.md`](docs/DOCUMENTATION.md) :
> il explique le fonctionnement de Nix pas à pas, sans prérequis.

---

## Installer en une commande

Depuis l'**ISO NixOS** (démarrée sur la machine cible), trois commandes courtes :

```bash
git clone https://github.com/tbrjk/homenixient
cd homenixient
./install.sh
```

> `git` est déjà présent sur l'ISO. S'il manque : `nix-shell -p git` puis les
> mêmes commandes.

`install.sh` te pose les questions nécessaires (utilisateur, machine, disque…),
puis **fait tout seul** : chiffrement du disque, génération de la config
matérielle, installation complète. Tu n'édites aucun fichier à la main.

**Redéployer** plus tard (nouvelle machine, ou ré-appliquer la config) : la même
commande. Sur un système déjà installé, lance simplement `./install.sh` depuis
`~/homenixient` — il détecte qu'il faut reconstruire, pas réinstaller.

Détails et méthode manuelle : [`INSTALL.md`](INSTALL.md).

---

## Ce que fait cette base

- **Système stable** : canal nixpkgs stable (26.05), avec une « fenêtre » sur le
  canal récent (`pkgs.unstable.*`) pour piocher un paquet à jour au cas par cas.
- **Disque chiffré** (LUKS) déclaré dans le dépôt → installation reproductible.
- **Bureau GNOME** (Wayland), clavier FR, prêt à l'emploi.
- **Virtualisation** : Docker + VirtualBox + Exegol.
- **Veille des mises à jour** : notification hebdomadaire si le système a pris du
  retard — **aucune** mise à jour automatique.
- **Retour arrière** : chaque changement crée une « génération » ; en cas de
  problème, on redémarre sur la précédente.

---

## Structure

```
install.sh                # installateur / redéployeur guidé  ← le point d'entrée
settings.nix              # TES réglages (nom, machine, disque…) — généré par install.sh
flake.nix                 # point d'entrée Nix (dépendances + définition machine)
justfile                  # raccourcis : just build / diff / update / gc…
INSTALL.md                # détails d'installation + méthode manuelle
docs/DOCUMENTATION.md     # tout comprendre (débutant NixOS)
hosts/homenixient/
  default.nix             # LA machine : boot, utilisateur (lit settings.nix)
  disko.nix               # disque + chiffrement (disque lu depuis settings.nix)
  hardware-configuration.nix  # généré à l'installation (placeholder au départ)
modules/nixos/
  base.nix                # Nix, langue, réseau, paquets de base
  desktop.nix             # GNOME / Wayland / polices
  virtualisation.nix      # Docker + VirtualBox + Exegol  ← le cœur
  hardening.nix           # pare-feu, sudo, réglages de sécurité
home/user/
  default.nix             # ton environnement : git, éditeur, outils
  shell.nix               # zsh + raccourcis (rebuild, docker, exegol…)
  update-watch.nix        # veille des mises à jour (notification)
```

**Un seul fichier à personnaliser : `settings.nix`** (et encore, `install.sh`
le remplit pour toi). Tout le reste lit ces valeurs — pas de fichier à éditer à
la main, pas de risque de casser la config.

---

## Au quotidien

```bash
just build          # applique la configuration
just diff           # montre ce qui changerait au prochain build
just rollback       # revient à la génération précédente
just gc             # fait le ménage dans le disque
```

Un changement casse quelque chose ? **Redémarre et choisis la génération
précédente dans le menu de démarrage.** C'est le filet de sécurité de NixOS.

### Mettre à jour

```bash
just update-check   # suis-je en retard ? (ne touche à rien)
just update-preview # ce qui changerait, sur une copie (rien appliqué)
just update         # met à jour flake.lock…
just diff           # …regarde ce qui change…
just build          # …et applique
```

---

## Virtualisation

**Docker**
```bash
docker run --rm hello-world      # test
lazydocker                       # interface visuelle (alias : lzd)
```

**VirtualBox** — lance-le depuis le menu des applications, ou :
```bash
VBoxManage --version
```

**Exegol** (environnement de travail conteneurisé, fourni par nixpkgs)
```bash
exegol install            # télécharge une image (première fois)   [alias: exe-install]
exegol start maStation    # crée/entre dans un conteneur           [alias: exe-start]
exegol info               # état des images et conteneurs          [alias: exe-info]
```

Les images Exegol/Docker se mettent à jour **à la main** (`exegol update`,
`docker pull …`) — indépendamment du système.

---

## Personnalisation

Tout se règle dans **`settings.nix`** (nom d'utilisateur, machine, fuseau,
clavier, disque, noyau récent oui/non, extension pack VirtualBox oui/non).
`install.sh` le génère à partir de tes réponses ; tu peux aussi l'éditer ensuite
et relancer `just build`.

Réglages plus fins (profil matériel `nixos-hardware`, clé SSH…) : voir les
commentaires dans `hosts/homenixient/default.nix`.

Détails d'installation : [`INSTALL.md`](INSTALL.md).
