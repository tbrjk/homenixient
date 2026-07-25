{ config, pkgs, lib, inputs, userSettings, ... }:

# =============================================================================
#  Fondations : Nix lui-même, langue/clavier, réseau, paquets système de base.
#  Ce module vaut pour n'importe quelle machine (rien de spécifique ici).
# =============================================================================

{
  # ---------------------------------------------------------------------------
  # Configuration de Nix
  # ---------------------------------------------------------------------------
  nix.settings = {
    # Active les commandes modernes `nix ...` et les flakes. Indispensable.
    experimental-features = [ "nix-command" "flakes" ];

    # Déduplique le store par hardlink → récupère de l'espace disque.
    auto-optimise-store = true;

    # Autorise les membres de `wheel` à gérer des caches sans être root.
    trusted-users = [ "root" "@wheel" ];

    # Caches binaires : sans eux, beaucoup de paquets se RECOMPILENT localement
    # (long). On ajoute le cache communautaire en plus du cache officiel.
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    max-jobs = "auto"; # builds parallèles
  };

  # Ramasse-miettes automatique du store (nettoie ce qui n'est plus référencé).
  # Ne touche JAMAIS la génération courante ni celles listées au boot.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Fait pointer `nixpkgs` (dans `nix shell nixpkgs#x`, le registre…) vers la
  # MÊME révision que ton flake → cohérence entre le système et les commandes
  # ponctuelles.
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

  # ---------------------------------------------------------------------------
  # Langue / heure / clavier
  # ---------------------------------------------------------------------------
  # Valeurs venant de settings.nix.
  time.timeZone = userSettings.timezone;
  i18n.defaultLocale = userSettings.locale;
  i18n.extraLocaleSettings = {
    # Messages système en anglais : les erreurs sont plus faciles à chercher.
    LC_MESSAGES = "en_US.UTF-8";
    LC_TIME = userSettings.locale;
    LC_MONETARY = userSettings.locale;
  };
  console.keyMap = userSettings.keymap;

  # ---------------------------------------------------------------------------
  # Réseau
  # ---------------------------------------------------------------------------
  # NetworkManager : gestion simple du réseau (applet GNOME, Wi-Fi, VPN…).
  networking.networkmanager.enable = true;

  # Résolution DNS moderne (cache, DNSSEC en mode souple).
  services.resolved = {
    enable = true;
    settings.Resolve.DNSSEC = "allow-downgrade";
  };

  # ---------------------------------------------------------------------------
  # Divers
  # ---------------------------------------------------------------------------
  boot.tmp.cleanOnBoot = true; # nettoie /tmp au démarrage

  # zsh comme shell par défaut (activé/configuré finement côté home-manager).
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];

  # Systèmes de fichiers courants sur clés/disques externes.
  boot.supportedFilesystems = [ "ntfs" "exfat" ];

  # ---------------------------------------------------------------------------
  # Paquets système de base
  #
  #  CONVENTION (où déclarer un outil ?) :
  #   • ICI (base.nix) = strict système / dépannage + outils Nix. Ces paquets
  #     doivent être dispo même pour root et hors session graphique (rescue).
  #   • Dans un module de fonctionnalité (desktop.nix, virtualisation.nix) =
  #     les paquets propres à cette fonctionnalité (firefox ; docker-compose…).
  #   • Dans home/user = TOUS les outils CLI de confort de l'utilisateur
  #     (ripgrep, fd, jq, bat, eza…). ← c'est là qu'on ajoute un outil perso.
  #  Objectif : un seul endroit par outil, aucun doublon.
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    git # utilisé par Nix (flakes) et indispensable en dépannage
    vim # éditeur de secours (root / hors session)
    wget
    curl
    file
    btop # moniteur de processus
    unzip
    p7zip
    pciutils # `lspci`
    usbutils # `lsusb`
    lsof
    rsync

    # Outils spécifiques à Nix, très utiles au quotidien :
    nix-output-monitor # `nom` : sortie de build lisible
    nvd # diff de paquets entre deux générations
    nix-tree # explore les dépendances d'un paquet
  ];
}
