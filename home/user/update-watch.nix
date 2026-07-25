{ config, pkgs, lib, ... }:

# =============================================================================
#  Veille des mises à jour — te PRÉVIENT, sans jamais rien appliquer.
#
#  Une fois par semaine, on compare la version de nixpkgs épinglée dans ton
#  flake.lock à la dernière version publiée. Si tu as du retard, une
#  notification de bureau te le signale. C'est tout : rien n'est téléchargé,
#  buildé, ni installé. Tu décides quand mettre à jour (`update` + `just diff`).
#
#  Note : cette veille concerne le SYSTÈME (nixpkgs). Les images Exegol/Docker
#  se mettent à jour séparément, à la main (`exegol update`, `docker pull …`) —
#  voir la documentation.
# =============================================================================

let
  flakeDir = "${config.home.homeDirectory}/homenixient";

  updateCheck = pkgs.writeShellApplication {
    name = "nixos-update-check";
    runtimeInputs = with pkgs; [ jq curl coreutils libnotify ];
    text = ''
      set -euo pipefail

      FLAKE_DIR="''${1:-${flakeDir}}"
      LOCK="$FLAKE_DIR/flake.lock"
      STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos-update-watch"
      mkdir -p "$STATE_DIR"
      REPORT="$STATE_DIR/last-check.txt"

      if [ ! -f "$LOCK" ]; then
        echo "flake.lock introuvable dans $FLAKE_DIR" >&2
        exit 1
      fi

      # Révision actuellement épinglée
      locked_rev=$(jq -r '.nodes.nixpkgs.locked.rev' "$LOCK")
      locked_epoch=$(jq -r '.nodes.nixpkgs.locked.lastModified' "$LOCK")
      branch=$(jq -r '.nodes.nixpkgs.original.ref // "nixos-26.05"' "$LOCK")
      owner=$(jq -r '.nodes.nixpkgs.original.owner // "NixOS"' "$LOCK")
      repo=$(jq -r '.nodes.nixpkgs.original.repo // "nixpkgs"' "$LOCK")

      # Dernière révision publiée (API GitHub, pas de token nécessaire)
      api="https://api.github.com/repos/$owner/$repo/commits/$branch"
      if ! upstream_json=$(curl -fsSL -H "Accept: application/vnd.github+json" "$api" 2>/dev/null); then
        echo "$(date -Iseconds) — vérification impossible (réseau ou API indispo)" > "$REPORT"
        exit 0
      fi
      upstream_rev=$(echo "$upstream_json" | jq -r '.sha')
      upstream_date=$(echo "$upstream_json" | jq -r '.commit.committer.date')

      now=$(date +%s)
      age_days=$(( (now - locked_epoch) / 86400 ))

      {
        echo "Vérifié le : $(date -Iseconds)"
        echo "Branche    : $owner/$repo @ $branch"
        echo "Épinglé    : ''${locked_rev:0:12}  (âge : ''${age_days} j)"
        echo "Publié     : ''${upstream_rev:0:12}  ($upstream_date)"
      } > "$REPORT"

      if [ "$locked_rev" = "$upstream_rev" ]; then
        echo "À jour." | tee -a "$REPORT"
        exit 0   # rien à signaler = pas de notification (pas de bruit)
      fi

      echo "MISE À JOUR DISPONIBLE." | tee -a "$REPORT"
      {
        echo ""
        echo "Voir ce qui changerait (sans rien appliquer) :  just update-preview"
        echo "Mettre à jour :  update  puis  just diff  puis  rebuild"
      } >> "$REPORT"

      if command -v notify-send >/dev/null; then
        notify-send -u normal -a "NixOS" \
          "Mise à jour système disponible" \
          "nixpkgs a ''${age_days} j de retard. « just update-preview » pour voir. Aucune action automatique."
      fi
    '';
  };
in
{
  home.packages = [ updateCheck pkgs.libnotify ];

  # Le service : exécute la vérification une fois.
  systemd.user.services.nixos-update-check = {
    Unit.Description = "Veille des mises à jour nixpkgs (notification seule)";
    Service = {
      Type = "oneshot";
      ExecStart = "${updateCheck}/bin/nixos-update-check";
      TimeoutStartSec = "120";
    };
  };

  # Le minuteur : hebdomadaire, rattrapé si la machine était éteinte.
  systemd.user.timers.nixos-update-check = {
    Unit.Description = "Déclenche la veille des mises à jour nixpkgs";
    Timer = {
      OnCalendar = "Mon 11:00"; # lundi matin ; adapte à ta convenance
      Persistent = true;
      RandomizedDelaySec = "2h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
