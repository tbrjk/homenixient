# Raccourcis de gestion du système. Tape `just` pour voir la liste.
# `just` est fourni par home-manager.

host := "homenixient"
flake := justfile_directory()

default:
    @just --list

# --- Application de la configuration --------------------------------------

# Applique la config MAINTENANT + au prochain démarrage (cas normal)
build:
    sudo nixos-rebuild switch --flake {{flake}}#{{host}}

# Applique maintenant SANS rendre permanent (revient au reboot si ça casse)
test:
    sudo nixos-rebuild test --flake {{flake}}#{{host}}

# Prépare pour le prochain démarrage seulement (utile pour un changement de noyau)
boot:
    sudo nixos-rebuild boot --flake {{flake}}#{{host}}

# Construit sans appliquer : détecte une config cassée sans risque
dry:
    nixos-rebuild build --flake {{flake}}#{{host}}

# --- Générations / retour arrière -----------------------------------------

# Revient à la génération précédente
rollback:
    sudo nixos-rebuild switch --rollback

# Liste les générations disponibles au démarrage
generations:
    nixos-rebuild list-generations

# Diff des paquets entre la génération actuelle et celle qui serait construite
diff:
    nixos-rebuild build --flake {{flake}}#{{host}} && nvd diff /run/current-system ./result

# --- Mises à jour ----------------------------------------------------------

# VEILLE : suis-je en retard sur nixpkgs ? (ne touche à rien)
update-check:
    nixos-update-check {{flake}}

# Met à jour les dépendances (réécrit flake.lock ; n'applique rien)
update:
    nix flake update --flake {{flake}}

# Met à jour une seule dépendance, ex : just update-one nixpkgs
update-one input:
    nix flake update {{input}} --flake {{flake}}

# Prévisualise le diff d'une mise à jour SANS toucher flake.lock ni le système.
# Travaille sur une COPIE du dépôt, jetée à la fin.
update-preview:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    echo "→ Copie du dépôt dans un dossier temporaire (le vrai n'est pas touché)…"
    cp -a {{flake}}/. "$tmp/repo/"
    rm -rf "$tmp/repo/.git"
    echo "→ Mise à jour du lock candidat…"
    nix flake update --flake "$tmp/repo"
    echo "→ Build du système candidat…"
    nix build "$tmp/repo#nixosConfigurations.{{host}}.config.system.build.toplevel" \
      --out-link "$tmp/candidate"
    echo "→ Diff (actuel → candidat) :"
    nvd diff /run/current-system "$tmp/candidate"
    echo ""
    echo "Rien n'a été appliqué. Pour de vrai : just update && just diff && just build"

# --- Divers ----------------------------------------------------------------

# Vérifie que la config évalue sans erreur
check:
    nix flake check {{flake}}

# Formate tous les fichiers .nix
fmt:
    nix fmt

# Nettoie le store (générations > 30 j) et déduplique
gc:
    sudo nix-collect-garbage --delete-older-than 30d
    nix store optimise
