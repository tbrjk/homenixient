{ config, pkgs, lib, userSettings, ... }:

# =============================================================================
#  home-manager : configuration de l'utilisateur.
#
#  Là où les modules NixOS configurent le SYSTÈME, home-manager configure TON
#  environnement : shell, git, éditeur, petits outils. Tout est déclaratif et
#  versionné, comme le reste. Les infos perso viennent de settings.nix.
# =============================================================================

{
  imports = [
    ./shell.nix # zsh, alias, raccourcis Docker/Exegol
    ./update-watch.nix # veille des mises à jour (notification)
  ];

  home.username = userSettings.username;
  home.homeDirectory = "/home/${userSettings.username}";

  # Repère de version de home-manager (comme system.stateVersion). Ne pas changer.
  home.stateVersion = "26.05";

  # Laisse home-manager se gérer lui-même.
  programs.home-manager.enable = true;

  # ---------------------------------------------------------------------------
  # Git
  # ---------------------------------------------------------------------------
  programs.git = {
    enable = true;
    userName = userSettings.fullName;
    userEmail = userSettings.email;
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
    ignores = [ "result" "result-*" ".direnv/" "*.swp" ];
  };

  # ---------------------------------------------------------------------------
  # direnv : charge automatiquement un environnement en entrant dans un dossier
  # (pratique pour des projets de dev). nix-direnv le met en cache.
  # ---------------------------------------------------------------------------
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Terminal & confort
  # ---------------------------------------------------------------------------
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    baseIndex = 1;
    mouse = true;
    historyLimit = 50000;
    escapeTime = 10;
  };

  # Invite de commande informative (affiche le dossier git, etc.).
  programs.starship.enable = true;

  # Éditeur : neovim, réglé simple.
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraConfig = ''
      set number
      set expandtab shiftwidth=2 tabstop=2
      set ignorecase smartcase
      set clipboard=unnamedplus
    '';
  };

  # Recherche floue (Ctrl-R sur l'historique, etc.).
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Remplaçants modernes d'outils classiques.
  programs.bat.enable = true; # `cat` avec coloration
  programs.eza = {
    enable = true; # `ls` amélioré
    icons = "auto";
  };
  programs.zoxide = {
    enable = true; # `cd` intelligent (mémorise les dossiers)
    enableZshIntegration = true;
  };

  # ---------------------------------------------------------------------------
  # Outils CLI de l'utilisateur.
  #  → C'EST ICI qu'on ajoute un outil perso (convention, cf. base.nix).
  #    Les programmes avec config dédiée (git, tmux, fzf, bat, eza, zoxide…)
  #    sont déclarés plus haut via `programs.*`. Le reste va dans cette liste.
  # ---------------------------------------------------------------------------
  home.packages = with pkgs; [
    ripgrep # `rg` : grep rapide
    fd # `find` moderne
    jq # manipulation de JSON
    sd # sed simplifié
    dust # `du` visuel
    duf # `df` visuel
    just # lanceur de commandes (voir justfile) — requis
    gh # CLI GitHub
  ];

  # ---------------------------------------------------------------------------
  # Verrouillage automatique de l'écran (GNOME) après 5 min d'inactivité.
  # ---------------------------------------------------------------------------
  dconf.settings = {
    "org/gnome/desktop/session".idle-delay = lib.hm.gvariant.mkUint32 300;
    "org/gnome/desktop/screensaver" = {
      lock-enabled = true;
      lock-delay = lib.hm.gvariant.mkUint32 0;
    };
    "org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };
}
