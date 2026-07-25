{ config, pkgs, lib, ... }:

# =============================================================================
#  zsh : shell interactif, alias et petits raccourcis.
#
#  Objectif : que les tâches courantes (rebuild, mise à jour, Docker, Exegol)
#  tiennent en une commande courte et mémorisable.
# =============================================================================

let
  # Emplacement du dépôt de configuration. À adapter si tu le ranges ailleurs.
  flakeDir = "$HOME/homenixient";
in
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true; # suggestions grisées d'après l'historique
    syntaxHighlighting.enable = true; # colore la ligne de commande
    enableCompletion = true;

    history = {
      size = 50000;
      save = 50000;
      extended = true; # horodate les commandes
      ignoreDups = true;
      ignoreSpace = true; # une commande commençant par un espace n'est pas historisée
    };

    shellAliases = {
      # ---- Système (construits autour du flake) ----------------------------
      # Applique la config maintenant + au prochain boot.
      rebuild = "sudo nixos-rebuild switch --flake ${flakeDir}#homenixient";
      # Applique maintenant SANS rendre permanent (revient au reboot si ça casse).
      rebuild-test = "sudo nixos-rebuild test --flake ${flakeDir}#homenixient";
      # Revient à la génération précédente.
      rollback = "sudo nixos-rebuild switch --rollback";
      # Liste les générations disponibles au démarrage.
      generations = "nixos-rebuild list-generations";
      # Met à jour les dépendances (réécrit flake.lock ; n'applique rien).
      update = "nix flake update --flake ${flakeDir}";

      # ---- Recherche de paquets --------------------------------------------
      # `ns firefox` : cherche un paquet. `nr <pkg>` : le lance sans l'installer.
      ns = "nix search nixpkgs";
      nr = "nix run nixpkgs#";

      # ---- Confort ---------------------------------------------------------
      ll = "eza -la --group-directories-first";
      lt = "eza --tree --level=2";
      ".." = "cd ..";
      "..." = "cd ../..";

      # ---- Docker ----------------------------------------------------------
      d = "docker";
      dps = "docker ps";
      dimg = "docker images";
      lzd = "lazydocker"; # interface TUI

      # ---- Exegol ----------------------------------------------------------
      # (le wrapper `exegol` est fourni par nixpkgs, cf. virtualisation.nix)
      exe = "exegol";
      exe-install = "exegol install"; # télécharge/maj une image
      exe-start = "exegol start"; # démarre/entre dans un conteneur
      exe-info = "exegol info"; # état des images et conteneurs
    };

    initContent = ''
      # ------------------------------------------------------------------
      # nsh : shell jetable avec des paquets, sans rien installer.
      #   nsh ncdu gping       → un shell temporaire avec ces outils
      # ------------------------------------------------------------------
      nsh() {
        local args=()
        for p in "$@"; do args+=("nixpkgs#$p"); done
        nix shell "''${args[@]}"
      }

      # Commandes commençant par un espace = non historisées (pour un secret).
      setopt HIST_IGNORE_SPACE
    '';

    # Raccourcis de chemin : `cd ~cfg`
    dirHashes = {
      cfg = "${flakeDir}";
    };
  };
}
