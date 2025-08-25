#!/usr/bin/bash

sudo virt-install --name lmde \
--description "Linux Mint Debian Edition" \
--os-variant=debian12 \
--ram=4096 \
--vcpus=2 \
--disk path=/mnt/raid1/storepool1/lmde.qcow2,bus=virtio,size=50 \ # size in GB
--graphics=vnc \
--cdrom /tmp/lmde-6-cinnamon-64bit-beta.iso \
--network network=default


# osinfo-query os ### --get Short ID name to use in os-variant specification

# --cdrom /mnt/plantenas/USC2/template/iso/lmde-6-cinnamon-64bit-beta.iso \
