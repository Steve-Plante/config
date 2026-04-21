#!/bin/bash

echo "Run as $USER"

# 2. Install Fedora Workstation 41

sudo grub2-editenv - unset menu_auto_hide

sudo btrfs filesystem label / FEDORA

lsblk -p /dev/vda

sudo btrfs subvolume list /

sudo dnf install vim git inotify-tools make

sudo dnf update

sudo reboot

# 3. Create the Additional Subvolumes

sudo mkdir -vp /var/lib/libvirt

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

MAX_LEN="$(printf '/%s\n' "${SUBVOLUMES[@]}" | wc -L)" ; echo $MAX_LEN

for dir in "${SUBVOLUMES[@]}" ; do
    if [[ -d "/${dir}" ]] ; then
        sudo mv -v "/${dir}" "/${dir}-old"
        sudo btrfs subvolume create "/${dir}"
        sudo cp -ar "/${dir}-old/." "/${dir}/"
    else
        sudo btrfs subvolume create "/${dir}"
    fi
    sudo restorecon -RF "/${dir}"
    printf "%-41s %-${MAX_LEN}s %-5s %-s %-s\n" \
        "UUID=${ROOT_UUID}" \
        "/${dir}" \
        "btrfs" \
        "subvol=${dir},${OPTIONS}" \
        "0 0" | \
        sudo tee -a /etc/fstab
done

sudo chown -cR $USER:$USER ~/$(ls -A)
sudo restorecon -vRF ~/$(ls -A)

sudo chmod -vR 0700 ~/.ssh

cat /etc/fstab

sudo systemctl daemon-reload

sudo mount -va

sudo btrfs subvolume list /

lsblk -p /dev/vda

for dir in "${SUBVOLUMES[@]}" ; do
    if [[ -d "/${dir}-old" ]] ; then
        sudo rm -rvf "/${dir}-old"
    fi
done

# 4. Install and Configure Snapper

sudo dnf install snapper libdnf5-plugin-actions

sudo bash -c "cat > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions" <<'EOF'
# Get snapshot description
pre_transaction::::/usr/bin/sh -c echo\ "tmp.cmd=$(ps\ -o\ command\ --no-headers\ -p\ '${pid}')"

# Creates pre snapshot before the transaction and stores the snapshot number in the "tmp.snapper_pre_number"  variable.
pre_transaction::::/usr/bin/sh -c echo\ "tmp.snapper_pre_number=$(snapper\ create\ -t\ pre\ -c\ number\ -p\ -d\ '${tmp.cmd}')"

# If the variable "tmp.snapper_pre_number" exists, it creates post snapshot after the transaction and removes the variable "tmp.snapper_pre_number".
post_transaction::::/usr/bin/sh -c [\ -n\ "${tmp.snapper_pre_number}"\ ]\ &&\ snapper\ create\ -t\ post\ --pre-number\ "${tmp.snapper_pre_number}"\ -c\ number\ -d\ "${tmp.cmd}"\ ;\ echo\ tmp.snapper_pre_number\ ;\ echo\ tmp.cmd
EOF

sudo snapper -c root create-config /
sudo snapper -c home create-config /home

sudo snapper list-configs

sudo snapper -c root set-config ALLOW_USERS=$USER SYNC_ACL=yes
sudo snapper -c home set-config ALLOW_USERS=$USER SYNC_ACL=yes

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

cat /etc/fstab

sudo systemctl daemon-reload
sudo mount -va

sudo btrfs subvolume list /

echo 'PRUNENAMES = ".snapshots"' | sudo tee -a /etc/updatedb.conf

echo 'SUSE_BTRFS_SNAPSHOT_BOOTING="true"' | sudo tee -a /etc/default/grub

sudo sed -i.bkp1 '1i set btrfs_relative_path="yes"' /boot/efi/EFI/fedora/grub.cfg

sudo grub2-mkconfig -o /boot/grub2/grub.cfg

snapper ls

snapper -c home ls

# 5. Install and Configure Grub-Btrfs

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

sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo systemctl enable --now grub-btrfsd.service

cd ..
rm -rvf grub-btrfs

# 6. Create a System Root Snapshot and Set It as the Default

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
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer

snapper ls

sudo systemctl disable --now snapper-timeline.timer
sudo systemctl disable --now snapper-cleanup.timer

# The end
