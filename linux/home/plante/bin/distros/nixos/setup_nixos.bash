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

# Configuration.nix
cat << EOF > configuration.nix
{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  services.displayManager.ly.enable = true;

  services = {
    desktopManager.plasma6.enable = true;
    displayManager.plasma-login-manager.enable = true;
  };

  users.users.plante = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = with pkgs; [
      tree
    ];
  };

  programs.firefox.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    alacritty
    git
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "26.05";

}
EOF
pause

# Home.nix
cat << EOF > home.nix
{ config, pkgs, ... }:

{
  home.username = "plante";
  home.homeDirectory = "/home/plante";
  programs.git.enable = true;
  home.stateVersion = "26.05";
  programs.bash = {
    enable = true;
    };
  };
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
