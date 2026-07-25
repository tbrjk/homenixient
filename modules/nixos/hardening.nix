{ config, pkgs, lib, ... }:

# =============================================================================
#  Sécurité de base — raisonnable pour un poste de travail (pas un serveur).
#
#  L'idée : durcir le périmètre (disque chiffré, pare-feu, sudo) sans rendre la
#  machine pénible à utiliser au quotidien.
# =============================================================================

{
  # ---------------------------------------------------------------------------
  # Chiffrement du disque
  # ---------------------------------------------------------------------------
  #  Géré par disko.nix (LUKS2 sur la partition root). La passphrase est
  #  demandée à chaque démarrage. C'est la protection principale des données au
  #  repos (vol/perte de la machine).
  #
  #  Recommandé en plus : mot de passe firmware (UEFI/BIOS) + ordre de
  #  démarrage verrouillé. Sinon, quelqu'un peut démarrer sur une clé USB pour
  #  contourner certaines protections (le chiffrement LUKS reste, lui, efficace).

  # ---------------------------------------------------------------------------
  # Pare-feu
  # ---------------------------------------------------------------------------
  networking.firewall = {
    enable = true;
    # Aucun port ouvert en entrée par défaut : la machine n'expose rien sur le
    # réseau. Ajoute un port ici seulement si tu héberges un service.
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };

  # ---------------------------------------------------------------------------
  # Élévation de privilèges (sudo)
  # ---------------------------------------------------------------------------
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true; # demande le mot de passe (ne pas désactiver)
    execWheelOnly = true; # seuls les membres de `wheel` peuvent utiliser sudo
  };

  # ---------------------------------------------------------------------------
  # Réglages noyau (sysctl) — durcissement réseau léger, sans gêner l'usage
  # ---------------------------------------------------------------------------
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv4.tcp_syncookies" = 1;
    # Limite la fuite d'adresses noyau vers les processus non privilégiés.
    "kernel.kptr_restrict" = 1;
  };

  # ---------------------------------------------------------------------------
  # Session
  # ---------------------------------------------------------------------------
  security.polkit.enable = true; # autorisations fines (montage, etc.)
  security.rtkit.enable = true; # priorité temps réel pour l'audio (PipeWire)
  # Le verrouillage automatique de l'écran est réglé côté home-manager (GNOME).

  # ---------------------------------------------------------------------------
  # Services réseau désactivés par défaut (rien n'écoute sur le réseau)
  # ---------------------------------------------------------------------------
  services.openssh.enable = false; # active-le seulement si tu veux du SSH entrant
  services.printing.enable = false; # active-le si tu as une imprimante

  # ---------------------------------------------------------------------------
  # Mises à jour
  # ---------------------------------------------------------------------------
  #  PAS de mise à jour automatique : sur une base, on met à jour quand ON
  #  décide, après avoir regardé ce qui change (`just diff`), avec la génération
  #  précédente disponible au boot en cas de souci. La veille (notification)
  #  est gérée côté home-manager (home/user/update-watch.nix).
  system.autoUpgrade.enable = false;

  # Journal système borné (évite qu'il remplisse le disque).
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    MaxRetentionSec=1month
  '';
}
