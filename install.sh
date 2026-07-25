#!/usr/bin/env bash
# =============================================================================
#  homenixient — installateur / redéployeur.
#
#  Un seul script pour deux situations :
#    • INSTALLATION NEUVE (depuis l'ISO NixOS) : formate un disque chiffré,
#      génère la config matérielle, installe le système complet.
#    • REDÉPLOIEMENT (sur un homenixient déjà installé) : applique la config.
#
#  Il te pose les questions nécessaires, écrit settings.nix, puis fait le reste.
#
#  Usage :
#    ./install.sh              # menu interactif (choisit install ou rebuild)
#    ./install.sh install      # force le mode installation neuve
#    ./install.sh rebuild      # force le mode redéploiement
#    ./install.sh --help
# =============================================================================
set -euo pipefail

# --- Emplacement du dépôt (dossier de ce script) -----------------------------
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS="$REPO/settings.nix"
FLAKE_ATTR="homenixient" # nom dans nixosConfigurations.<...>
HW="$REPO/hosts/homenixient/hardware-configuration.nix"
DISKO="$REPO/hosts/homenixient/disko.nix"

# --- Couleurs / journal ------------------------------------------------------
if [ -t 1 ]; then
  C_B="\033[1m"; C_G="\033[1;32m"; C_Y="\033[1;33m"; C_R="\033[1;31m"; C_0="\033[0m"
else
  C_B=""; C_G=""; C_Y=""; C_R=""; C_0=""
fi
info() { echo -e "${C_G}▶${C_0} $*"; }
warn() { echo -e "${C_Y}⚠${C_0}  $*"; }
err()  { echo -e "${C_R}✖${C_0} $*" >&2; }
die()  { err "$*"; exit 1; }
title(){ echo -e "\n${C_B}== $* ==${C_0}"; }

# --- Flakes activés (nécessaire sur l'ISO) -----------------------------------
export NIX_CONFIG="experimental-features = nix-command flakes"

# --- sudo : on l'utilise au besoin (root direct sur l'ISO = pas de sudo) -----
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

# =============================================================================
#  Aide
# =============================================================================
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
  exit 0
fi

# =============================================================================
#  Petites fonctions de saisie
# =============================================================================

# ask "Question" "valeur_par_defaut"  → renvoie la saisie (ou le défaut)
ask() {
  local q="$1" def="${2:-}" ans
  if [ -n "$def" ]; then
    read -r -p "$(echo -e "${C_B}$q${C_0} [${def}] : ")" ans || true
    echo "${ans:-$def}"
  else
    read -r -p "$(echo -e "${C_B}$q${C_0} : ")" ans || true
    echo "$ans"
  fi
}

# ask_yn "Question" "Y|N"  → renvoie true/false
ask_yn() {
  local q="$1" def="${2:-N}" ans hint="y/N"
  [ "$def" = "Y" ] && hint="Y/n"
  read -r -p "$(echo -e "${C_B}$q${C_0} [$hint] : ")" ans || true
  ans="${ans:-$def}"
  case "$ans" in [yYoO]*) echo true ;; *) echo false ;; esac
}

# Lit la valeur actuelle d'une clé dans settings.nix (pour pré-remplir).
cur() {
  [ -f "$SETTINGS" ] || { echo ""; return; }
  grep -E "^\s*$1\s*=" "$SETTINGS" | head -1 \
    | sed -E 's/.*=\s*"?([^";]*)"?\s*;.*/\1/' | sed 's/[[:space:]]*$//'
}

# =============================================================================
#  Collecte des réglages → settings.nix
# =============================================================================
gather_settings() {
  local mode="$1" # install | rebuild
  title "Réglages (settings.nix)"
  echo "Entrée vide = garder la valeur entre [crochets]."
  echo

  USERNAME=$(ask "Nom d'utilisateur (login)" "$(cur username)")
  FULLNAME=$(ask "Nom complet (affichage + git)" "$(cur fullName)")
  EMAIL=$(ask    "Email (git)" "$(cur email)")
  HOSTNAME=$(ask "Nom de la machine (hostname)" "$(cur hostname)")
  TIMEZONE=$(ask "Fuseau horaire" "$(cur timezone)")
  KEYMAP=$(ask   "Clavier console (fr, us, be…)" "$(cur keymap)")
  LOCALE=$(ask   "Locale" "$(cur locale)")

  local kl def_kl="N" vb def_vb="Y"
  [ "$(cur kernelLatest)" = "true" ] && def_kl="Y"
  [ "$(cur virtualboxExtensionPack)" = "false" ] && def_vb="N"
  KERNEL_LATEST=$(ask_yn "Noyau le plus récent ? (⚠ peut casser VirtualBox)" "$def_kl")
  VBOX_EXTPACK=$(ask_yn  "VirtualBox Extension Pack ? (USB/RDP, build + long)" "$def_vb")

  # Disque : demandé seulement en installation neuve.
  if [ "$mode" = "install" ]; then
    choose_disk
  else
    DISK="$(cur disk)"
  fi

  write_settings
  info "settings.nix écrit."
}

choose_disk() {
  title "Choix du disque à FORMATER"
  warn "Le disque choisi sera EFFACÉ intégralement."
  echo
  echo "Disques détectés :"
  lsblk -dpno NAME,SIZE,MODEL 2>/dev/null | sed 's/^/  /' || true
  echo
  echo "Chemins stables (recommandés — /dev/disk/by-id/) :"
  ls -l /dev/disk/by-id/ 2>/dev/null | grep -v '\-part' | awk '{print "  "$9" -> "$11}' | sed '/-> $/d' || true
  echo
  DISK=$(ask "Disque cible (chemin complet, idéalement /dev/disk/by-id/…)" "$(cur disk)")
  [ -n "$DISK" ] && [ "$DISK" != "/dev/disk/by-id/CHANGE_ME" ] \
    || die "Aucun disque valide fourni."
  [ -e "$DISK" ] || die "Le chemin '$DISK' n'existe pas."
}

write_settings() {
  cat > "$SETTINGS" <<EOF
# =============================================================================
#  settings.nix — généré par ./install.sh. Éditable à la main puis \`just build\`.
#  Ne contient AUCUN secret : publiable sur GitHub.
# =============================================================================
{
  # --- Identité utilisateur ---
  username = "$USERNAME";
  fullName = "$FULLNAME";
  email = "$EMAIL";

  # --- Machine ---
  hostname = "$HOSTNAME";

  # --- Localisation ---
  timezone = "$TIMEZONE";
  keymap = "$KEYMAP";
  locale = "$LOCALE";

  # --- Disque (disko efface ce disque à l'installation) ---
  disk = "$DISK";

  # --- Options matériel / virtualisation ---
  kernelLatest = $KERNEL_LATEST;
  virtualboxExtensionPack = $VBOX_EXTPACK;
}
EOF
}

summary() {
  title "Récapitulatif"
  cat <<EOF
  Utilisateur : $USERNAME ($FULLNAME <$EMAIL>)
  Machine     : $HOSTNAME
  Localisation: $TIMEZONE / clavier $KEYMAP / $LOCALE
  Noyau récent: $KERNEL_LATEST     VirtualBox ExtPack: $VBOX_EXTPACK
  Disque      : ${DISK:-<inchangé>}
EOF
}

# =============================================================================
#  Git : le flake ne voit que les fichiers suivis. On les ajoute.
# =============================================================================
git_track() {
  $SUDO git config --global --add safe.directory "$REPO" 2>/dev/null || true
  git config --global --add safe.directory "$REPO" 2>/dev/null || true
  if [ ! -d "$REPO/.git" ]; then
    ( cd "$REPO" && git init -q && git add -A )
  else
    ( cd "$REPO" && git add -A )
  fi
}

# =============================================================================
#  INSTALLATION NEUVE
# =============================================================================
run_install() {
  gather_settings install
  summary
  echo
  warn "INSTALLATION NEUVE : le disque ci-dessus va être EFFACÉ et CHIFFRÉ."
  local base; base="$(basename "$DISK")"
  local confirm; confirm=$(ask "Tape le nom du disque pour confirmer (\"$base\")" "")
  [ "$confirm" = "$base" ] || die "Confirmation incorrecte. Abandon (rien n'a été touché)."

  title "1/5 · Partitionnement + chiffrement (disko)"
  # disko lit le disque via settings.nix (import direct dans disko.nix).
  # Si '--mode disko' échoue sur ta version, remplace par '--mode destroy,format,mount'.
  $SUDO nix run github:nix-community/disko/latest -- --mode disko "$DISKO"

  title "2/5 · Génération de la config matérielle (sans filesystems)"
  # disko fournit déjà les filesystems → --no-filesystems évite les doublons.
  $SUDO nixos-generate-config --no-filesystems --root /mnt --show-hardware-config > "$HW"
  info "hardware-configuration.nix généré."

  title "3/5 · Suivi git des fichiers générés"
  git_track

  title "4/5 · Installation du système (long : téléchargement + build)"
  $SUDO nixos-install --flake "$REPO#$FLAKE_ATTR" --no-root-passwd

  title "5/5 · Finalisation"
  # Mot de passe root
  info "Définis le mot de passe ROOT :"
  $SUDO nixos-enter --root /mnt -c "passwd root" || warn "à définir plus tard."
  # Mot de passe utilisateur
  info "Définis le mot de passe de '$USERNAME' :"
  $SUDO nixos-enter --root /mnt -c "passwd $USERNAME" || warn "à définir plus tard."
  # Copie du dépôt dans le home du nouveau système (pour les rebuilds futurs)
  local target="/mnt/home/$USERNAME/homenixient"
  $SUDO mkdir -p "/mnt/home/$USERNAME"
  $SUDO cp -a "$REPO/." "$target/"
  $SUDO rm -rf "$target/.git"
  $SUDO nixos-enter --root /mnt -c "chown -R $USERNAME:users /home/$USERNAME/homenixient" || true

  echo
  info "${C_B}Installation terminée.${C_0}"
  echo "  Le dépôt est copié dans ~/homenixient sur le nouveau système."
  echo "  Redémarre puis retire le média :   $SUDO reboot"
  echo "  Au démarrage : saisis la passphrase du disque, puis connecte-toi."
}

# =============================================================================
#  REDÉPLOIEMENT (système déjà installé)
# =============================================================================
run_rebuild() {
  gather_settings rebuild
  summary
  echo

  # Garde-fou : sans hardware-config réelle, on ne peut pas construire.
  if [ ! -f "$HW" ] || grep -q "throw" "$HW"; then
    die "hardware-configuration.nix absent ou placeholder.
     Ce système n'a pas encore été installé par ce dépôt.
     Utilise le mode INSTALLATION depuis l'ISO, ou génère-le :
       $SUDO nixos-generate-config --no-filesystems --show-hardware-config > $HW"
  fi

  git_track
  title "Application de la configuration"
  $SUDO nixos-rebuild switch --flake "$REPO#$FLAKE_ATTR"
  info "Système à jour."
}

# =============================================================================
#  Choix du mode
# =============================================================================
main() {
  echo -e "${C_B}homenixient — installateur${C_0}"

  local mode="${1:-}"
  if [ -z "$mode" ]; then
    # Suggestion : ISO live → install ; système installé → rebuild.
    local default_choice="1"
    if command -v nixos-rebuild >/dev/null && [ ! -d /iso ] && [ -f "$HW" ] && ! grep -q throw "$HW"; then
      default_choice="2"
    fi
    title "Que veux-tu faire ?"
    echo "  1) Installation NEUVE (formate un disque chiffré — depuis l'ISO)"
    echo "  2) Redéployer la config sur CE système déjà installé"
    local c; c=$(ask "Choix" "$default_choice")
    case "$c" in
      1) mode="install" ;;
      2) mode="rebuild" ;;
      *) die "Choix invalide." ;;
    esac
  fi

  case "$mode" in
    install) run_install ;;
    rebuild) run_rebuild ;;
    *) die "Mode inconnu : '$mode' (attendu : install | rebuild)" ;;
  esac
}

main "$@"
