#!/bin/bash -x

# To do list:
#------------
# 1. Implement zswap into script

TGTDSK="/dev/sda"

pause() {
    # Pause until enter key is pressed
    read -p "Press [Enter] key to continue..."
}

echo "Run as $USER"

# 1. Install Void from .iso

# Display disk
lsblk -f $TGTDSK
pause

# Wipe the disk and create a fresh GPT layout
sudo sgdisk -Z $TGTDSK
pause
# Create a new empty GPT
sudo sgdisk -og $TGTDSK
pause

# Create 1st partition starting at beginning of disk for a size
# of one GB and with a type of "EFI system partition"
sudo sgdisk -n 1:0:+1G -t 1:ef00 $TGTDSK
pause

# Create 2nd partition for the remaining size and with a type of
# "Linux filesystem"
sudo sgdisk -n 2:: -t 2:8300 $TGTDSK
pause

# print parition table for $TGTDSK
sudo sgdisk -p /dev/sda
pause

# Format 1st partition as FAT32
sudo mkfs.vfat -F32 -n EFI ${TGTDSK}1
pause

# Format 2nd partition as BTRFS
sudo mkfs.btrfs -L VOID ${TGTDSK}2
pause

sudo btrfs subvolume list /
pause

sudo xbps-install -Su
pause

sudo xbps-install -S vim git inotify-tools make
pause

# sudo reboot?

# 2. Create the Additional Subvolumes

# Mount the Btrfs root

mount -v ${TGTDSK}2 /mnt

sudo mkdir -vp /mnt/var/lib/libvirt

ROOT_UUID="$(sudo grub2-probe --target=fs_uuid /)" ; echo $ROOT_UUID

OPTIONS="$(grep '/home' /etc/fstab \
    | awk '{print $4}' \
    | cut -d, -f2-)" \
    ; echo $OPTIONS
compress=zstd:1

SUBVOLUMES=(
    "opt"
    "var/cache"
    "var/crash"
    "var/lib/AccountsService"
    "var/lib/sddm"
    "var/lib/libvirt/images"
    "var/log"
    "var/spool"
    "var/tmp"
    "var/www"
    "home/$USER/.mozilla"
    "home/$USER/.config/google-chrome"
    "home/$USER/.config/BraveSoftware"
    "home/$USER/.thunderbird"
    "home/$USER/.ssh"
)

printf '%s\n' "${SUBVOLUMES[@]}"
pause

MAX_LEN="$(printf '/%s\n' "${SUBVOLUMES[@]}" | wc -L)" ; echo $MAX_LEN

sudo btrfs subvolume create /mnt/@ # Root filesystem

for dir in "${SUBVOLUMES[@]}" ; do
    if [[ -d "/${dir}" ]] ; then
        sudo mv -v "/${dir}" "/${dir}-old"
        sudo btrfs subvolume create "/${dir}"
        sudo cp -ar "/${dir}-old/." "/${dir}/"
    else
        sudo btrfs subvolume create "/${dir}"
    fi
    printf "%-41s %-${MAX_LEN}s %-5s %-s %-s\n" \
        "UUID=${ROOT_UUID}" \
        "/${dir}" \
        "btrfs" \
        "subvol=${dir},${OPTIONS}" \
        "0 0" | \
        sudo tee -a /etc/fstab
done
pause

sudo chown -cR $USER:$USER ~/$(ls -A)
pause

sudo chmod -R 0700 ~/.ssh
pause

cat /etc/fstab
pause

sudo mount -a
pause

sudo btrfs subvolume list /
pause

lsblk -p $TGTDSK
pause

for dir in "${SUBVOLUMES[@]}" ; do
    if [[ -d "/${dir}-old" ]] ; then
        sudo rm -rf "/${dir}-old"
    fi
done
pause

# 3. Install and Configure Snapper

sudo dnf install snapper btrfs-progs # replace btrfs-progs with libdnf5-plugin-actions if Fedora 41+
pause

sudo bash -c "cat > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions" <<'EOF'
# Get snapshot description
pre_transaction::::/usr/bin/sh -c echo\ "tmp.cmd=$(ps\ -o\ command\ --no-headers\ -p\ '${pid}')"

# Creates pre snapshot before the transaction and stores the snapshot number in the "tmp.snapper_pre_number"  variable.
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=$(snapper\ create\ -t\ pre\ -c\ number\ -p\ -d\ '${tmp.cmd}')"

# If the variable "tmp.snapper_pre_number" exists, it creates post snapshot after the transaction and removes the variable "tmp.snapper_pre_number".
post_transaction::::/usr/bin/sh -c [\ -n\ "${tmp.snapper_pre_number}"\ ]\ &&\ snapper\ create\ -t\ post\ --pre-number\ "${tmp.snapper_pre_number}"\ -c\ number\ -d\ "${tmp.cmd}"\ ;\ echo\ tmp.snapper_pre_number\ ;\ echo\ tmp.cmd
EOF
pause

sudo snapper -c root create-config /
sudo snapper -c home create-config /home
pause

sudo snapper list-configs
pause

sudo snapper -c root set-config ALLOW_USERS=$USER SYNC_ACL=yes
sudo snapper -c home set-config ALLOW_USERS=$USER SYNC_ACL=yes
pause

ROOT_UUID="$(sudo grub2-probe --target=fs_uuid /)"

MAX_LEN="$(cat /etc/fstab | awk '{print $2}' | wc -L)"

OPTIONS="$(grep '/opt' /etc/fstab \
    | awk '{print $4}' \
    | cut -d, -f2-)"

for dir in '.snapshots' 'home/.snapshots' ; do
    printf "%-41s %-${MAX_LEN}s %-5s %-s %-s\n" \
        "UUID=${ROOT_UUID}" \
        "/${dir}" \
        "btrfs" \
        "subvol=${dir},${OPTIONS}" \
        "0 0" | \
        sudo tee -a /etc/fstab
done
pause

cat /etc/fstab
pause

sudo mount -a
pause

sudo btrfs subvolume list /
pause

echo 'PRUNENAMES = ".snapshots"' | sudo tee -a /etc/updatedb.conf

echo 'SUSE_BTRFS_SNAPSHOT_BOOTING="true"' | sudo tee -a /etc/default/grub

sudo sed -i.bkp1 '1i set btrfs_relative_path="yes"' /boot/efi/EFI/fedora/grub.cfg
pause

sudo grub2-mkconfig -o /boot/grub2/grub.cfg
pause

snapper ls
snapper -c home ls
pause

# 4. Install and Configure Grub-Btrfs

git clone https://github.com/Antynea/grub-btrfs
cd grub-btrfs
sed -i.bkp \
-e '/#GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS/a \
GRUB_BTRFS_SNAPSHOT_KERNEL_PARAMETERS="systemd.volatile=state"' \
-e '/#GRUB_BTRFS_GRUB_DIRNAME/a \
GRUB_BTRFS_GRUB_DIRNAME="/boot/grub2"' \
-e '/#GRUB_BTRFS_MKCONFIG=/a \
GRUB_BTRFS_MKCONFIG=/usr/sbin/grub2-mkconfig' \
-e '/#GRUB_BTRFS_SCRIPT_CHECK=/a \
GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check' \
config
sudo make install
pause

sudo grub2-mkconfig -o /boot/grub2/grub.cfg
#sudo systemctl enable --now grub-btrfsd.service
pause

cd ..
rm -rvf grub-btrfs

# 5. Create a System Root Snapshot and Set It as the Default

sudo mkdir -v /.snapshots/1

sudo bash -c "cat > /.snapshots/1/info.xml" <<EOF
<?xml version="1.0"?>
<snapshot>
  <type>single</type>
  <num>1</num>
  <date>$(date -u +"%F %T")</date>
  <description>first root subvolume</description>
</snapshot>
EOF

cat /.snapshots/1/info.xml

sudo btrfs subvolume snapshot / /.snapshots/1/snapshot

SNAP_1_ID="$(sudo btrfs inspect-internal rootid /.snapshots/1/snapshot)"

echo ${SNAP_1_ID}

sudo btrfs subvolume set-default ${SNAP_1_ID} /

sudo btrfs subvolume get-default /

sudo reboot

snapper ls

# 7. Enable Automatic Timeline Snapshots

sudo snapper -c home set-config TIMELINE_CREATE=no
#sudo systemctl enable --now snapper-timeline.timer
#sudo systemctl enable --now snapper-cleanup.timer

snapper ls

#sudo systemctl disable --now snapper-timeline.timer
#sudo systemctl disable --now snapper-cleanup.timer

# 6. The end
