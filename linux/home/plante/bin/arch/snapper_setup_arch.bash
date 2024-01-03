#!/usr/bin/bash -x

# run after archinstall with btrfs subvolumes installed

paru -S snapper-support
sudo umount /.snapshots
sudo rm -r /.snapshots
sudo snapper -c root create-config /
sudo btrfs subvol list /
sudo btrfs subvol delete /.snapshots
sudo mkdir /.snapshots
sudo mount -a
sudo btrfs subvol get default /
sudo btrfs subvol set-def 256 /
sudo btrfs subvol list /
sudo cp -p /etc/snapper/configs/roots /etc/snapper/configs/roots.bak
sudo sed -i \
-e 's/ALLOW_GROUPS=""/ALLOW_GROUPS="wheel"/' \
-e 's/TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' \
-e 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' \
-e 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="5"/' \
-e 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="0"/' \
-e 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' \
 /etc/snapper/configs/roots
sudo chown -R :wheel /.snapshots
sudo snapper -c root create -d "***System Installed***"
