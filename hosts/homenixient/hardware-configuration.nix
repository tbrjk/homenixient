# ============================================================================
#  PLACEHOLDER — à remplacer avant le premier `nixos-rebuild`. Voir INSTALL.md.
#
#  Ce fichier décrit le matériel (modules noyau de démarrage, etc.). Il se
#  GÉNÈRE sur la machine, il ne s'écrit pas à la main et ne se copie pas d'un
#  poste à l'autre.
#
#  Comme on utilise disko (qui fournit déjà les systèmes de fichiers), génère
#  ce fichier SANS les filesystems, sinon doublon → erreur de build :
#
#      sudo nixos-generate-config --no-filesystems --root /mnt \
#        --show-hardware-config > hosts/homenixient/hardware-configuration.nix
#
#  Tant que ce placeholder est là, l'évaluation échoue volontairement (throw)
#  pour t'empêcher d'installer une machine sans description matérielle.
# ============================================================================
_:

throw ''

  hosts/homenixient/hardware-configuration.nix est encore le placeholder.

  Génère le vrai fichier (méthode disko, cf. INSTALL.md) :
      sudo nixos-generate-config --no-filesystems --root /mnt \
        --show-hardware-config > hosts/homenixient/hardware-configuration.nix

  Puis : git add hosts/homenixient/hardware-configuration.nix
''
