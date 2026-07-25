{ config, pkgs, lib, userSettings, ... }:

# =============================================================================
#  Virtualisation — le cœur de cette base.
#
#  Trois briques, chacune pour un usage différent :
#    • Docker      → conteneurs légers ; c'est ce sur quoi Exegol tourne.
#    • VirtualBox  → machines virtuelles complètes (Windows, autres Linux…).
#    • Exegol      → environnement de travail conteneurisé (basé sur Docker).
#
#  RAPPEL IMPORTANT : un conteneur (Docker/Exegol) PARTAGE le noyau de l'hôte.
#  Une VM VirtualBox, elle, a son PROPRE noyau (isolation plus forte, mais plus
#  lourde). Choisis selon le besoin : conteneur = rapide/jetable, VM = isolé.
# =============================================================================

{
  # ---------------------------------------------------------------------------
  # 1. Docker
  # ---------------------------------------------------------------------------
  virtualisation.docker = {
    enable = true;

    # Nettoie automatiquement les conteneurs/images/volumes orphelins chaque
    # semaine (Docker a tendance à remplir le disque sinon).
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  # L'utilisateur est déjà dans le groupe `docker` (cf. host) → il utilise
  # Docker et Exegol sans `sudo`.

  # ---------------------------------------------------------------------------
  # 2. VirtualBox
  # ---------------------------------------------------------------------------
  virtualisation.virtualbox.host = {
    enable = true;

    # Extension Pack : USB 2.0/3.0, RDP, chiffrement de disque VM…
    #  ⚠️  Non-libre (licence Oracle) ET compilé localement → le PREMIER build
    #      peut être long. Réglable dans settings.nix (`virtualboxExtensionPack`).
    enableExtensionPack = userSettings.virtualboxExtensionPack;
  };
  # L'utilisateur est déjà dans le groupe `vboxusers` (cf. host).
  #
  #  NOTE compatibilité noyau : VirtualBox compile un module noyau. Si tu
  #  actives `linuxPackages_latest` (dans le host) et que VirtualBox refuse de
  #  démarrer après un build, reviens au noyau stable par défaut. C'est la
  #  raison pour laquelle on garde le noyau stable.
  #
  #  NOTE VirtualBox vs KVM : on n'active PAS libvirt/KVM ici, donc pas de
  #  conflit de module noyau. (Docker n'a pas besoin de KVM.)

  # ---------------------------------------------------------------------------
  # 3. Exegol
  #
  #  Exegol = un « pilote » (le wrapper, en Python) + des images Docker toutes
  #  prêtes. Le wrapper crée/lance des conteneurs jetables avec ton dossier de
  #  travail monté dedans. Comme tout vit dans le conteneur (basé Kali/Ubuntu),
  #  il n'y a AUCUN problème de compatibilité binaire côté hôte NixOS.
  #
  #  Le wrapper est packagé dans nixpkgs (`pkgs.exegol`) → déclaré ci-dessous,
  #  proprement et déclarativement. Les IMAGES, elles, se tirent avec
  #  `exegol install` (téléchargement depuis Docker Hub) — hors périmètre Nix,
  #  et c'est normal.
  # ---------------------------------------------------------------------------
  environment.systemPackages = with pkgs; [
    # --- Exegol ---
    exegol # le wrapper (crée/lance les conteneurs de travail)

    # --- Outils Docker en ligne de commande ---
    docker-compose
    lazydocker # interface TUI pour Docker (pratique)

    # (VirtualBox lui-même est fourni par virtualisation.virtualbox.host)
  ];

  # ---------------------------------------------------------------------------
  #  GUI depuis un conteneur (navigateurs, outils graphiques Exegol) : le
  #  wrapper Exegol gère le partage de l'affichage (X11/Wayland) et des
  #  périphériques USB (option `--device`) automatiquement. Rien à configurer
  #  côté système pour un usage standard.
  # ---------------------------------------------------------------------------
}
