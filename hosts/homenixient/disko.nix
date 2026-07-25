{ lib, ... }:

# =============================================================================
#  Disque complet, DÉCLARATIF : partitionnement + chiffrement + filesystems.
#
#  Avec disko, plus besoin de fdisk/cryptsetup/mkfs à la main : une seule
#  commande formate et monte tout (cf. INSTALL.md). Le disque entier devient
#  reproductible → réinstallation à l'identique quand tu veux.
#
#  ⚠️  disko EFFACE ET FORMATE le disque cible. Vérifie `disk` avant tout.
#
#  Schéma :
#    - GPT
#    - partition 1 : ESP (EFI), 1 GiB, FAT32, montée sur /boot
#    - partition 2 : LUKS2 (chiffré) → root ext4, monté sur /
#    - swap : fichier sur le root chiffré (donc chiffré aussi)
# =============================================================================

let
  # Disque cible : vient de settings.nix (renseigné par install.sh).
  # On l'importe directement pour que ce fichier fonctionne AUSSI en dehors du
  # flake (la commande `disko` l'évalue seul lors du formatage).
  disk = (import ../../settings.nix).disk;
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = disk;
      content = {
        type = "gpt";
        partitions = {
          # ---- ESP (partition de démarrage EFI) --------------------------
          ESP = {
            priority = 1;
            name = "ESP";
            size = "1G";
            type = "EF00"; # type GPT « EFI System »
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ]; # /boot non lisible par tous
            };
          };

          # ---- Partition chiffrée (LUKS2) → root -------------------------
          luks = {
            priority = 2;
            name = "cryptroot";
            size = "100%"; # tout le reste du disque
            content = {
              type = "luks";
              name = "cryptroot"; # apparaîtra en /dev/mapper/cryptroot
              settings = {
                # TRIM sur SSD (perf). Mets à false pour un peu plus de
                # confidentialité (évite une fuite d'info par les blocs libres).
                allowDiscards = true;
              };
              # Passphrase demandée INTERACTIVEMENT au moment du formatage
              # (et à chaque démarrage). Ne jamais mettre de `passwordFile`
              # pointant vers un secret versionné : il finirait en clair dans
              # /nix/store (lisible par tous). Voir docs, section sécurité.
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };

  # Swap = fichier sur le root CHIFFRÉ (donc chiffré). 8 GiB par défaut ;
  # ajuste selon ta RAM (utile aussi pour l'hibernation).
  swapDevices = [
    {
      device = "/swapfile";
      size = 8 * 1024; # en MiB
    }
  ];

  # ---------------------------------------------------------------------------
  # NOTE — déverrouillage automatique (optionnel, désactivé par défaut)
  #
  #  Par défaut : passphrase saisie au clavier à chaque démarrage (le plus sûr).
  #  Pour déverrouiller via une clé USB ou le TPM, voir la doc NixOS sur
  #  `boot.initrd.luks.devices`. Le TPM est pratique mais réduit la protection
  #  en cas de vol de la machine entière.
  # ---------------------------------------------------------------------------
}
