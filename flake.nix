{
  description = "RasPi NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-24.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, home-manager, ... }@inputs: {
    # Please replace my-nixos with your hostname
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        nixos-hardware.nixosModules.raspberry-pi-4

        ({ config, lib, pkgs, ... }: 
        {
          system.stateVersion = "24.11";
          nix.settings.experimental-features = [ "nix-command" "flakes" ];

          imports =
            [
              ./hardware-configuration.nix
            ];
          
          hardware = {
            raspberry-pi."4".apply-overlays-dtmerge.enable = true;
            deviceTree = {
              enable = true;
              filter = "*rpi-4-*.dtb";
            };
          };

          boot.loader.grub.enable = false;
          boot.loader.generic-extlinux-compatible.enable = true;

	  boot = {
	    kernelPackages = pkgs.linuxPackages_rpi4;
	    # tmpOnTmpfs = true; # See note
	    kernelParams = [
	      "8250.nr_uarts=1"
	      "console=ttyAMA0,115200"
	      "console=tty1"
	      "cma=128M"
	    ];
	  };

	  networking.hostName = "nixos"; # Define your hostname.
          networking.wireless.enable = true;
	  networking.wireless.secretsFile = "/run/secrets/wireless.conf";
          networking.wireless.networks = {
            OpenWrt24g2.pskRaw = "ext:psk_wifi";
          };
	  networking.wireless.extraConfig = "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel";
	  # output ends up in /run/wpa_supplicant/wpa_supplicant.conf
	  networking.networkmanager.enable = false;
	  networking.networkmanager.wifi.powersave = false;

	  time.timeZone = "Asia/Tokyo";

	  users.users.nixos = {
	    isNormalUser = true;
	    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
	    packages = with pkgs; [
	      tree
	    ];
	  };

	  environment.systemPackages = with pkgs; [
	    vim
	    wget
	    git
	    libraspberrypi
	    raspberrypi-eeprom
	  ];
	  environment.variables.EDITOR = "vim";

	  services.openssh.enable = true;

        })

        # make home-manager as a module of nixos
        # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.nixos = import ./home.nix;
          # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
        }
      ];
    };
  };
}
