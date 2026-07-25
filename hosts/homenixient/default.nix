{ config, pkgs, lib, inputs, userSettings, ... }:

# =============================================================================
#  Définition de la machine « homenixient ».
#
#  Ce fichier rassemble ce qui est SPÉCIFIQUE à cette machine (nom, boot,
#  utilisateur) et importe tous les modules réutilisables. Pour un second
#  poste, tu dupliquerais ce dossier (hosts/autre-machine/) et l'adapterais.
# =============================================================================

{
  imports = [
    # Matériel : généré à l'installation (cf. INSTALL.md). Placeholder pour
    # l'instant → à remplacer avant le premier build réel.
    ./hardware-configuration.nix

    # Disque + chiffrement déclaratifs.
    ./disko.nix

    # Les modules fonctionnels (chacun est commenté en tête).
    ../../modules/nixos/base.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/virtualisation.nix
    ../../modules/nixos/hardening.nix

    # Profil matériel : décommente celui de TA machine (support optimisé).
    # inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
    # inputs.nixos-hardware.nixosModules.framework-13-7040-amd
    # inputs.nixos-hardware.nixosModules.dell-xps-13-9310
    # Liste complète : https://github.com/NixOS/nixos-hardware
  ];

  # ---------------------------------------------------------------------------
  # Identité (valeur venant de settings.nix)
  # ---------------------------------------------------------------------------
  networking.hostName = userSettings.hostname;

  # ---------------------------------------------------------------------------
  # Démarrage
  # ---------------------------------------------------------------------------
  # systemd-boot : bootloader simple pour UEFI. Chaque build ajoute une entrée
  # « génération » dans le menu de démarrage → c'est ton filet de sécurité
  # (une mise à jour casse quelque chose ? tu démarres sur la génération d'avant).
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 20; # 20 générations au menu

  # Noyau : stable par défaut (le plus compatible avec le module VirtualBox).
  # Bascule contrôlée par settings.nix : `kernelLatest = true` → noyau récent
  # (matériel très neuf). ⚠️ peut casser VirtualBox.
  boot.kernelPackages =
    if userSettings.kernelLatest then pkgs.linuxPackages_latest else pkgs.linuxPackages;

  # ---------------------------------------------------------------------------
  # Utilisateur (nom/infos venant de settings.nix)
  # ---------------------------------------------------------------------------
  users.users.${userSettings.username} = {
    isNormalUser = true;
    description = userSettings.fullName;
    extraGroups = [
      "wheel" # droit d'utiliser sudo
      "networkmanager" # gérer le réseau
      "docker" # utiliser Docker sans sudo (requis par Exegol)
      "vboxusers" # utiliser VirtualBox
    ];
    shell = pkgs.zsh;

    # Le mot de passe se définit à l'installation (install.sh le demande) ou
    # plus tard avec `passwd`. On ne le met PAS ici : un hash dans un fichier
    # publié sur GitHub serait une fuite.
    #
    # Clé SSH publique (si tu veux te connecter à cette machine à distance) :
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
  };

  # ---------------------------------------------------------------------------
  # Repère de migration des données à état persistant.
  #  ⚠️  Ne JAMAIS changer après l'installation. Ce n'est pas la version du
  #      système (qui suit nixpkgs) : c'est un marqueur de compatibilité.
  # ---------------------------------------------------------------------------
  system.stateVersion = "26.05";
}
