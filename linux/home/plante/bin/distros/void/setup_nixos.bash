#!/bin/bash -x

# Fix/To do list:
#----------------
# 1.

TGTDSK="/dev/vda"

pause() {
    # Pause until enter key is pressed
    read -p "Press [Enter] key to continue..."
}

# 1. Boot and install from nixos-minimal-dd.mm.9999.a00000000000-x86_64-linux.iso

echo "Run as root"
sudo -i

# Display disk
lsblk $TGTDSK
pause

# Wipe the disk and create a fresh GPT layout
parted $TGTDSK -- mklabel gpt

# Create 1st partition starting at beginning of disk for a size
# of one percent and with a type of "EFI system partition"
parted $TGTDSK -- mkpart primary fat32 0% 1%
pause

# Create 2nd partition for the remaining size and with a type of
# "Linux filesystem"
parted $TGTDSK -- mkpart primary ext4 1% 100%
pause

# print parition table for $TGTDSK
parted $TGTDSK print
pause

# Format 1st partition as FAT32
sudo mkfs.vfat -F32 -n EFI ${TGTDSK}1
pause

# Format 2nd partition as ext4
sudo mkfs.ext4 -L NIXOS ${TGTDSK}2
pause

# Mount the fat32 boot
mount --mkdir ${TGTDSK}1 /mnt/boot
pause

# Mount the ext4 root
mount ${TGTDSK}2 /mnt
pause

# Display disk
lsblk $TGTDSK
pause

# Configure the nix filesystem
nixos-generate-config --root /mnt
cd /mnt/etc/nixos/
#touch flake.nix home.nix
pause

# Flake.nix
cat << EOF > flake.nix
{
  description = "NixOS";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.plante = import ./home.nix;
            backupFileExtension = "backup";
          };
        }
      ];
    };
  };
}
EOF
pause

# hardware-configuration.nix
cat << EOF >> hardware-configuration.nix
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/7a26c6bd-c173-4fa7-84c6-439ce67d2f7e";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/F1FB-9BAC";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
EOF
pause

# Configuration.nix
cat << EOF > configuration.nix
{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."plante" = {
    isNormalUser = true;
    description = "Plante";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
      kdePackages.kate
      neovim
      fastfetch
      micro
      btop
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;
  programs.thunderbird.enable = true;
  programs.fish.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  curl
  wget
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
EOF
pause

# Install
nixos-install --flake /mnt/etc/nixos#nixos
pause

# Type your password
nixos-enter --root /mnt -c 'passwd plante'
pause

# Reboot
reboot

exit
