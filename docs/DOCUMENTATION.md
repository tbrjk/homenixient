# Documentation — homenixient

Guide complet pour **comprendre et utiliser** cette base NixOS, écrit pour
quelqu'un qui **découvre NixOS**. On part de zéro : aucun prérequis Nix.

**Sommaire**

1. [Comprendre NixOS en 5 minutes](#1-comprendre-nixos)
2. [Le vocabulaire minimum](#2-vocabulaire)
3. [Lire un fichier de configuration](#3-lire-la-config)
4. [Comment cette config est organisée](#4-organisation)
5. [Le quotidien : appliquer, revenir en arrière](#5-quotidien)
6. [Les mises à jour et la veille](#6-mises-à-jour)
7. [La virtualisation : Docker, VirtualBox, Exegol](#7-virtualisation)
8. [Exécuter un programme téléchargé](#8-binaires)
9. [Le disque (/nix/store) et le ménage](#9-store)
10. [Problèmes courants](#10-problèmes)
11. [Sécurité : ce qu'il faut savoir](#11-sécurité)
12. [Antisèche](#12-antisèche)

---

## 1. Comprendre NixOS

### L'idée centrale

Sur une distribution classique (Ubuntu, Arch…), tu installes des logiciels et
modifies des fichiers **au fur et à mesure**. Après quelques mois, personne ne
sait exactement comment le système en est arrivé là. Si quelque chose casse,
tu répares à la main.

Sur **NixOS**, c'est l'inverse : tu **décris** l'état voulu du système dans des
fichiers texte, et NixOS **construit** exactement cet état.

```
tes fichiers de config  ──►  NixOS construit  ──►  ton système
```

Tu ne modifies jamais le système directement. Tu modifies la description, puis
tu lances une commande qui applique. Conséquences concrètes :

- **Reproductible** : les mêmes fichiers donnent toujours le même système. Tu
  peux réinstaller ta machine à l'identique, ou la recréer ailleurs.
- **Réversible** : chaque changement crée une « génération ». Si une mise à jour
  casse quelque chose, tu **redémarres sur la génération précédente**. Pas de
  réparation à la main, pas de système cassé irrécupérable.
- **Documenté tout seul** : ta config EST la documentation de ta machine.

### Le prix à payer (autant le savoir)

1. On ne bricole plus « en direct ». Éditer `/etc/…` à la main ne sert à rien :
   le fichier est reconstruit au prochain build. Tout passe par la config.
2. Un programme téléchargé sur internet ne démarre pas toujours du premier coup
   (voir §8). Mais dans cette base, tes outils vivent dans Docker/Exegol/
   VirtualBox, où ce comportement n'existe pas.
3. Le langage de config est un peu déroutant au début (§3).

Le compromis est payant ici : tu obtiens une machine **stable et increvable**,
et toute la complexité des outils est déportée dans les conteneurs/VM.

---

## 2. Vocabulaire

Quelques mots reviennent partout :

- **Paquet** : un logiciel (ex : `firefox`, `docker`).
- **Module** : un morceau de configuration réutilisable (les fichiers dans
  `modules/nixos/`). Cette base est faite de modules.
- **Option** : un réglage exposé par un module (ex : `networking.hostName`,
  `services.openssh.enable`). Il en existe des dizaines de milliers ; on les
  cherche sur https://search.nixos.org/options.
- **Génération** : un instantané complet et démarrable de ton système, numéroté.
  Chaque `just build` en crée une. Revenir en arrière = choisir une génération
  antérieure.
- **flake** : le point d'entrée de la config (`flake.nix`), avec ses dépendances
  **épinglées** dans `flake.lock` (versions figées → reproductibilité).
- **nixpkgs** : l'immense collection de paquets (~120 000) + le système de
  modules NixOS. C'est une dépendance du flake.
- **/nix/store** : le dossier où tout est stocké (§9).
- **home-manager** : l'outil qui gère la config de ton **utilisateur** (shell,
  git…) comme NixOS gère le système.

---

## 3. Lire la config

Tu n'as pas besoin de maîtriser le langage Nix pour utiliser cette base, mais
savoir le **lire** aide à la modifier. L'essentiel :

```nix
# Ceci est un commentaire.

# Un "attribute set" = un ensemble de réglages { clé = valeur; }
{
  networking.hostName = "homenixient";   # une chaîne de caractères
  services.openssh.enable = false;       # un booléen (true/false)

  # Une LISTE utilise des ESPACES (pas des virgules !) :
  environment.systemPackages = [ firefox git btop ];
}
```

⚠️ **Le piège classique du débutant** : mettre des virgules dans une liste.

```nix
[ firefox, git ]   # ❌ ERREUR
[ firefox git ]    # ✅ correct (espaces)
```

Un **module** (comme `modules/nixos/desktop.nix`) a toujours cette forme :

```nix
{ config, pkgs, lib, ... }:   # en-tête (des valeurs fournies par le système)
{                             # le corps : les réglages
  services.desktopManager.gnome.enable = true;
  environment.systemPackages = with pkgs; [ firefox ];
}
```

`with pkgs;` veut dire « les noms qui suivent sont des paquets » : `with pkgs;
[ firefox git ]` = `[ pkgs.firefox pkgs.git ]`. Un raccourci pour ne pas répéter
`pkgs.` partout.

Tous les modules sont **fusionnés** par NixOS en une seule configuration.
L'ordre des fichiers n'a pas d'importance.

---

## 4. Organisation

```
install.sh         ← installateur / redéployeur guidé (le point d'entrée humain)
settings.nix       ← TES réglages (nom, machine, disque…). Le seul à personnaliser.
  │  lu par ↓
flake.nix          ← point d'entrée Nix : dépendances + « construis la machine »
  │
  └─ hosts/homenixient/default.nix   ← LA machine (boot, utilisateur)
       │  importe ↓
       ├─ hosts/homenixient/disko.nix              (disque + chiffrement)
       ├─ hosts/homenixient/hardware-configuration.nix (matériel, généré à l'install)
       ├─ modules/nixos/base.nix          (Nix, langue, réseau, paquets de base)
       ├─ modules/nixos/desktop.nix       (GNOME)
       ├─ modules/nixos/virtualisation.nix (Docker + VirtualBox + Exegol)
       └─ modules/nixos/hardening.nix     (pare-feu, sudo, sécurité)

  home/user/…      ← TON environnement utilisateur (shell, git, outils)
```

**Le fichier à connaître : `settings.nix`.** Il contient tes infos (nom,
machine, fuseau, clavier, disque, options). Tous les autres fichiers **lisent**
ces valeurs — tu ne les édites pas pour changer ton nom ou ta timezone. C'est
`install.sh` qui remplit `settings.nix` à partir de tes réponses.

Pour modifier un **réglage perso** (nom, fuseau, clavier…) : édite
`settings.nix`, puis `just build`. Pour modifier un **comportement** (ajouter un
paquet, changer une option système) : édite le module concerné, puis `just
build`.

### Deux points de conception à connaître

**Canal stable + fenêtre sur le récent.** Le système est sur le canal **stable**
(nixpkgs 26.05) : peu de surprises, correctifs de sécurité rétroportés. Si un
jour tu veux UN paquet en version très récente, tu peux écrire
`pkgs.unstable.<nom>` dans un module — sans passer toute la machine en rolling.
C'est le meilleur des deux mondes.

**Les outils ne sont pas sur le système.** Volontairement, cette base ne
contient aucun outil « métier ». Ils vivent dans Docker/Exegol/VirtualBox (§7).
Résultat : le système reste léger, stable, et rapide à reconstruire.

---

## 5. Quotidien

### Appliquer un changement

Après avoir édité un fichier `.nix` :

```bash
just build     # applique maintenant + au prochain démarrage
```

Trois variantes utiles :

```bash
just build     # le cas normal
just test      # applique maintenant, mais PAS au prochain boot
               #   → si ça casse, un simple redémarrage te ramène à l'état d'avant
just boot      # applique seulement au prochain démarrage (ex : changement de noyau)
```

Réflexe recommandé pour un changement risqué : `just test` d'abord. Si tout va
bien, `just build` pour rendre permanent.

### Revenir en arrière

C'est LA force de NixOS. Chaque build crée une génération démarrable.

```bash
just generations     # liste les générations
just rollback        # revient à la précédente (à chaud)
```

Si le système ne démarre même plus : **redémarre, et dans le menu de démarrage,
choisis une génération plus ancienne**. Réparation en 30 secondes, sans clé USB.

### Voir ce qui va changer avant d'appliquer

```bash
just diff      # construit la nouvelle config sans l'appliquer,
               # et liste les paquets ajoutés / retirés / mis à jour
```

### Chercher un paquet ou une option

```bash
ns firefox                          # cherche un paquet (alias de nix search)
# en ligne :
#   https://search.nixos.org/packages   ← les logiciels
#   https://search.nixos.org/options    ← les réglages (services.*, etc.)
```

### Installer un logiciel durablement

Ajoute-le à `environment.systemPackages` dans un module (ex : `desktop.nix`
pour une appli de bureau), puis `just build`. Pour juste l'essayer une fois,
sans l'installer :

```bash
nix run nixpkgs#vlc      # lance et oublie
nsh vlc mpv              # shell temporaire avec ces outils (alias maison)
```

---

## 6. Mises à jour

### Le principe (différent d'Ubuntu/Arch)

Sur NixOS avec flakes, une mise à jour se fait en **deux temps séparés** :

```bash
just update    # 1. met à jour les versions (réécrit flake.lock) — n'installe RIEN
just diff      # 2. regarde ce qui changerait
just build     # 3. applique
```

`just update` ne change rien sur ta machine : il met juste à jour le fichier de
versions. Tant que tu ne fais pas `just build`, rien n'est appliqué. Tu décides.

### La veille (notification, sans rien faire)

Une fois par semaine, une **notification** t'indique si le système a pris du
retard sur nixpkgs. Rien n'est installé automatiquement — c'est juste une
information.

```bash
just update-check      # lancer la vérification à la main
```

Le dernier résultat est dans
`~/.local/state/nixos-update-watch/last-check.txt`.

Pour voir **exactement ce qui changerait** avant de te décider, sans rien
appliquer ni même modifier ton `flake.lock` :

```bash
just update-preview    # travaille sur une copie, affiche le diff, puis jette
```

### Et les images Docker / Exegol ?

Elles se mettent à jour **séparément**, à la main (elles ne dépendent pas de
nixpkgs) :

```bash
exegol update              # met à jour les images Exegol
docker pull <image>        # met à jour une image Docker
```

### En cas de mise à jour ratée

```bash
just rollback                                  # revient en arrière (à chaud)
# ou, de façon reproductible :
git checkout HEAD~1 flake.lock && just build   # revient aux versions d'avant
```

---

## 7. Virtualisation

Trois outils, trois usages. Rappel clé : un **conteneur** (Docker/Exegol)
partage le noyau de la machine (léger, rapide) ; une **VM** (VirtualBox) a son
propre noyau (isolation plus forte, plus lourde).

### Docker

Conteneurs légers. Tu es déjà dans le groupe `docker` → pas besoin de `sudo`.

```bash
docker run --rm hello-world        # test rapide
docker ps                          # conteneurs en cours (alias : dps)
docker images                      # images téléchargées (alias : dimg)
lazydocker                         # interface visuelle en terminal (alias : lzd)
```

Le ménage se fait tout seul chaque semaine (images/conteneurs orphelins).

### VirtualBox

Machines virtuelles complètes (Windows, autre Linux…). Lance-le depuis le menu
des applications GNOME, ou en ligne de commande :

```bash
VBoxManage --version
VBoxManage list vms
```

> **Si VirtualBox refuse de démarrer après une mise à jour** : c'est
> probablement un noyau trop récent. Cette base utilise le noyau stable pour
> l'éviter. Si tu as activé `linuxPackages_latest`, reviens au noyau par défaut.

L'Extension Pack (USB, RDP) est activé par défaut. Si le premier build est trop
long, tu peux le désactiver dans `modules/nixos/virtualisation.nix`
(`enableExtensionPack = false`).

### Exegol

Environnement de travail conteneurisé : des images toutes prêtes + un pilote
(le wrapper) qui crée des conteneurs jetables avec ton dossier de travail
dedans. Comme tout vit dans le conteneur, **aucun** souci de compatibilité côté
NixOS.

```bash
exegol install             # télécharge une image (première fois)  [alias exe-install]
exegol start maStation     # crée / entre dans un conteneur        [alias exe-start]
exegol info                # état des images et conteneurs         [alias exe-info]
exegol stop maStation      # arrête un conteneur
```

Le wrapper Exegol est packagé dans nixpkgs et déjà déclaré dans
`modules/nixos/virtualisation.nix` → disponible dès l'installation, rien à
faire. Seules les **images** se téléchargent, avec `exegol install`.

**Interfaces graphiques et USB depuis Exegol** : le wrapper gère le partage de
l'affichage (X11/Wayland) et des périphériques USB automatiquement. Rien à
configurer pour un usage standard.

**Ce qu'un conteneur ne peut PAS faire** : charger un module noyau (le noyau
reste celui de l'hôte). Pour un besoin de ce type (certains drivers), il faut
passer par une VM VirtualBox ou configurer le module côté NixOS.

---

## 8. Binaires

Bon à savoir : un programme **téléchargé sur internet** (release GitHub,
installeur, binaire tout prêt) ne démarre pas toujours directement sur NixOS,
avec un message trompeur :

```
$ ./mon-programme
bash: ./mon-programme: No such file or directory     # (le fichier existe pourtant)
```

Raison : NixOS n'a pas les chemins système « classiques » que le binaire attend.

**Dans cette base, ce n'est pas un problème** : tes outils vivent dans
Docker/Exegol/VirtualBox, où ce comportement n'existe pas (ce sont des
environnements « classiques »). Lance donc ce genre de binaire **dans un
conteneur**, pas sur le système.

> Si un jour tu as vraiment besoin de faire tourner des binaires téléchargés
> **directement sur le système**, on réintroduira le module `nix-ld` (retiré
> pour garder cette base minimale). Dis-le-moi à ce moment-là.

---

## 9. Store

### C'est quoi le /nix/store

Tout ce qui est installé vit dans `/nix/store`, chaque paquet dans un dossier
dont le nom contient un code unique. Plusieurs versions peuvent coexister sans
conflit. C'est ce qui permet le retour arrière instantané : une « ancienne »
génération pointe simplement vers d'anciens dossiers, toujours présents.

Contrepartie : le store **grossit**. D'où le ménage.

### Faire le ménage

```bash
just gc      # supprime les générations de plus de 30 jours + optimise l'espace
```

C'est fait **automatiquement** chaque semaine. Le ménage ne touche jamais la
génération courante ni celles proposées au démarrage : tu ne peux pas casser ton
système avec un `gc`.

⚠️ Après un ménage, les générations supprimées disparaissent du menu de
démarrage. Les 30 jours de marge te laissent le temps de revenir loin en arrière
si un problème se révèle tard.

---

## 10. Problèmes

| Symptôme | Cause probable | Solution |
|----------|----------------|----------|
| `[fichier] does not exist` au build | fichier `.nix` pas ajouté à git | `git add` le fichier (un flake ne voit que le suivi par git) |
| Erreur de syntaxe bizarre | virgule dans une liste, ou `;` manquant | `just fmt` reformate et révèle souvent l'erreur |
| `attribute 'X' missing` | nom de paquet inexistant/renommé | `ns X` pour trouver le bon nom |
| Un binaire téléchargé ne démarre pas | pas de chemins « classiques » | le lancer dans un conteneur (§8) |
| VirtualBox HS après mise à jour | noyau trop récent | rester sur le noyau stable (défaut) |
| Une modif de `/etc` a « disparu » | `/etc` est reconstruit à chaque build | faire le réglage via une option NixOS, pas à la main |
| Le build recompile longtemps | cache non atteint / dépendance de base modifiée | patienter ; vérifier le réseau |

Pour **toute** erreur, ajoute `--show-trace` pour le détail complet :
```bash
nixos-rebuild build --flake .#homenixient --show-trace
```

---

## 11. Sécurité

- **Disque chiffré (LUKS)** : passphrase au démarrage. C'est la protection de
  tes données si la machine est perdue ou volée. Choisis-la forte.
- **Mot de passe firmware (UEFI)** + démarrage verrouillé : recommandé, pour
  empêcher un contournement par démarrage sur clé USB.
- **Jamais de secret dans un fichier `.nix`** : tout ce que tu mets dans la
  config finit **lisible par tous** dans `/nix/store`. Pour un mot de passe ou
  une clé, ne l'écris pas en clair (on ajoutera un outil dédié, `sops-nix`, si
  le besoin apparaît).
- **Pare-feu** fermé en entrée par défaut : la machine n'expose rien sur le
  réseau. N'ouvre un port que si tu héberges un service.
- **Historique shell** : une commande commençant par une **espace** n'est pas
  enregistrée dans l'historique — pratique pour taper un mot de passe ponctuel.

---

## 12. Antisèche

```bash
# ---- Système -------------------------------------------------------------
just build          # applique la configuration
just test           # applique sans rendre permanent (annulé au reboot)
just boot           # applique au prochain démarrage seulement
just diff           # ce qui changerait au prochain build
just rollback       # génération précédente (ou : menu de démarrage)
just generations    # liste des générations
just check          # vérifie que la config est valide
just fmt            # reformate les fichiers .nix
just gc             # ménage du disque

# ---- Mises à jour --------------------------------------------------------
just update-check   # suis-je en retard ? (ne touche à rien)
just update-preview # ce qui changerait, sur une copie (rien appliqué)
just update         # met à jour flake.lock (n'applique rien)
just update-one nixpkgs
git checkout HEAD~1 flake.lock && just build   # revenir aux versions d'avant

# ---- Paquets à la volée (rien d'installé) --------------------------------
ns <nom>            # chercher un paquet
nix run nixpkgs#<pkg> -- <args>
nsh <p1> <p2>       # shell temporaire avec ces outils

# ---- Docker / VirtualBox / Exegol ----------------------------------------
docker run --rm hello-world     # test docker
lazydocker                      # interface docker (alias lzd)
VBoxManage --version            # virtualbox
exegol install                  # image exegol       (alias exe-install)
exegol start <nom>              # conteneur exegol    (alias exe-start)
exegol update                   # maj images exegol

# ---- Diagnostic ----------------------------------------------------------
journalctl -xe                  # logs système
systemctl status <service>      # état d'un service
nixos-rebuild build --flake .#homenixient --show-trace   # erreur détaillée
```

### Où chercher de l'aide

- Paquets : https://search.nixos.org/packages
- Réglages : https://search.nixos.org/options
- Manuel NixOS : https://nixos.org/manual/nixos/stable/
- Wiki (orienté pratique) : https://wiki.nixos.org/
- Exegol : https://exegol.readthedocs.io/
```
