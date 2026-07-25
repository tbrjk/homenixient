{
  # ===========================================================================
  #  homenixient — base NixOS stable & sécurisée.
  #
  #  Un flake, c'est simplement le point d'entrée de toute la configuration :
  #    - `inputs`  = les dépendances (d'où vient le code : nixpkgs, etc.)
  #    - `outputs` = ce que le flake produit (ici : la définition de la machine)
  #
  #  Toutes les dépendances sont ÉPINGLÉES dans `flake.lock` : la même config
  #  produit toujours exactement le même système. Rien ne bouge tant que tu ne
  #  lances pas `nix flake update`.
  # ===========================================================================
  description = "homenixient — base NixOS stable, chiffrée, prête pour la virtualisation";

  inputs = {
    # Canal STABLE (figé tous les 6 mois, correctifs de sécurité rétroportés).
    # C'est la base du système : on privilégie la stabilité, pas la nouveauté.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Canal UNSTABLE (rolling), exposé plus bas sous `pkgs.unstable.*`.
    # Sert à piocher UN paquet récent au cas par cas SANS passer tout le
    # système en rolling. Ex : `pkgs.unstable.firefox` dans un module.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # home-manager gère la config de TON utilisateur (dotfiles, zsh, git…)
    # de façon déclarative, comme NixOS gère le système. On l'aligne sur la
    # même branche stable que nixpkgs (`follows`) pour éviter les décalages.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # disko : partitionnement + chiffrement + systèmes de fichiers DÉCLARATIFS.
    # Permet une installation chiffrée reproductible (cf. INSTALL.md).
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Profils matériels prêts à l'emploi (ThinkPad, Framework, Dell…).
    # Optionnel : on décommente le profil de sa machine dans le host.
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs =
    { self
    , nixpkgs
    , nixpkgs-unstable
    , home-manager
    , disko
    , nixos-hardware
    , ...
    }@inputs:
    let
      system = "x86_64-linux";

      # TES réglages perso (nom, machine, disque…) — le seul fichier à éditer.
      # Généré par ./install.sh, lu par toute la config.
      userSettings = import ./settings.nix;

      # Overlay : ajoute `pkgs.unstable` = l'intégralité du canal unstable,
      # accessible partout dans la config. On ne s'en sert qu'au cas par cas.
      overlayUnstable = _final: _prev: {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };
    in
    {
      # -----------------------------------------------------------------------
      #  LA machine. On la construit avec :
      #     sudo nixos-rebuild switch --flake .#homenixient
      #  Le `#homenixient` = le nom de cet attribut.
      # -----------------------------------------------------------------------
      nixosConfigurations.homenixient = nixpkgs.lib.nixosSystem {
        inherit system;

        # `specialArgs` passe des valeurs aux modules. On transmet les inputs
        # (pour `inputs.nixos-hardware…`) et tes réglages (`userSettings`).
        specialArgs = { inherit inputs userSettings; };

        modules = [
          # allowUnfree : requis pour l'extension pack VirtualBox et certains
          # firmwares. L'overlay unstable est branché ici.
          {
            nixpkgs.overlays = [ overlayUnstable ];
            nixpkgs.config.allowUnfree = true;
          }

          # Le module disko (fournit les options de partitionnement).
          disko.nixosModules.disko

          # La définition de notre machine (importe tous les autres modules).
          ./hosts/homenixient

          # Intégration de home-manager comme module NixOS : système + user
          # sont construits ensemble, dans la même génération.
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # Renomme un fichier en conflit au lieu de faire échouer le switch.
            home-manager.backupFileExtension = "hm-bak";
            home-manager.extraSpecialArgs = { inherit inputs userSettings; };
            # Le compte de l'utilisateur est nommé d'après settings.nix.
            home-manager.users.${userSettings.username} = import ./home/user;
          }
        ];
      };

      # `nix fmt` : formate tous les fichiers .nix du dépôt.
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
