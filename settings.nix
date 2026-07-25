# =============================================================================
#  settings.nix — TES réglages personnels, au même endroit.
#
#  C'est le SEUL fichier à personnaliser. Le reste de la config lit ces valeurs.
#  Normalement, tu n'édites même pas ce fichier à la main : `./install.sh` le
#  génère à partir de tes réponses. Mais tu peux l'ajuster ici si besoin, puis
#  relancer `just build` (ou `./install.sh`).
#
#  Ce fichier ne contient AUCUN secret (pas de mot de passe) : il peut être
#  publié sur GitHub sans risque. Le mot de passe se définit séparément, à
#  l'installation (voir install.sh / INSTALL.md).
# =============================================================================
{
  # --- Identité utilisateur ---
  username = "hann"; # nom de login (minuscules, sans espace)
  fullName = "hann"; # nom affiché + nom pour git
  email = "thomas.brejka@gmail.com"; # email pour git

  # --- Machine ---
  hostname = "homenixient"; # nom réseau de la machine

  # --- Localisation ---
  timezone = "Europe/Paris";
  keymap = "fr"; # disposition clavier console (fr, us, be…)
  locale = "fr_FR.UTF-8"; # langue par défaut

  # --- Disque (pour l'installation chiffrée avec disko) ---
  #  ⚠️  disko EFFACE ce disque. Utilise un chemin stable /dev/disk/by-id/…
  #      `ls -l /dev/disk/by-id/`   —  install.sh t'aide à le choisir.
  disk = "/dev/disk/by-id/CHANGE_ME";

  # --- Options matériel / virtualisation ---
  kernelLatest = false; # true = noyau le plus récent (matériel très neuf).
  # ⚠️ peut casser le module VirtualBox — laisser false si possible.
  virtualboxExtensionPack = false; # USB/RDP dans VirtualBox.
  # ⚠️ sa compilation peut saturer la RAM de l'ISO À L'INSTALLATION.
  #    Laisse false pour installer, puis passe à true + `just build` une fois
  #    le système démarré (RAM + swap complets, aucun souci).
}
