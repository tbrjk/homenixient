{ config, pkgs, lib, userSettings, ... }:

# =============================================================================
#  Environnement de bureau : GNOME sur Wayland.
#
#  GNOME est le choix le plus reposant quand on découvre NixOS : il fonctionne
#  bien dès l'installation, avec très peu de configuration à écrire.
# =============================================================================

{
  # Serveur d'affichage + disposition clavier graphique (suit settings.nix).
  # Le clavier de la CONSOLE texte est réglé séparément dans base.nix
  # (console.keyMap). On ne met PAS console.useXkbConfig ici : ça entrerait en
  # conflit avec console.keyMap (l'un est une chaîne, l'autre une dérivation).
  services.xserver = {
    enable = true;
    xkb = {
      layout = userSettings.keymap;
      variant = "";
    };
  };

  # GDM = écran de connexion ; GNOME = le bureau.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Retire quelques applications GNOME par défaut dont on n'a pas besoin.
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-music
    epiphany # navigateur GNOME (on utilise Firefox)
    geary # mail
    totem # vidéo
  ];

  # ---------------------------------------------------------------------------
  # Audio : PipeWire (le standard moderne, remplace PulseAudio)
  # ---------------------------------------------------------------------------
  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Portails XDG : partage d'écran, sélecteurs de fichiers, presse-papiers
  # inter-applications sous Wayland. Nécessaire au bon fonctionnement de GNOME.
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
  };

  # ---------------------------------------------------------------------------
  # Polices
  # ---------------------------------------------------------------------------
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts
      noto-fonts-emoji
      dejavu_fonts
      liberation_ttf # substituts Arial/Times/Courier (compat documents)
      # Police à chasse fixe avec icônes (jolie dans le terminal / les prompts).
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.defaultFonts.monospace = [ "JetBrainsMono Nerd Font" ];
  };

  # ---------------------------------------------------------------------------
  # Applications de bureau de base
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    firefox
    keepassxc # gestionnaire de mots de passe
    gnome-tweaks # réglages GNOME avancés
    wl-clipboard # presse-papiers en ligne de commande (Wayland)
  ];
}
