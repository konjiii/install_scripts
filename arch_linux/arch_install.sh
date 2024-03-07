#!/usr/bin/env bash

# create partitions
lsblk

echo "enter disk:"
read DISK
cfdisk /dev/$DISK

lsblk

# ask required information
while :
do
    echo "intel/amd?"
    read CPU
    
    if [ "$CPU" == "intel" ] || [ "$CPU" == "amd" ]; then
        break
    else
        echo "invalid input"
    fi
done

echo "enter EFI partition:"
read EFI

echo "enter root partition:"
read ROOT

echo "enter swap partition:"
read SWAP

echo "enter username:"
read USER

while :
do
    echo "enter password for $USER:"
    read -s PASS

    echo "re-enter password for $USER:"
    read -s PASS2

    if [ "$PASS" == "$PASS2" ]; then
        break
    else
        echo "passwords do not match"
    fi
done

# format partitions
mkfs.fat -F32 /dev/$EFI
mkfs.ext4 /dev/$ROOT
mkswap /dev/$SWAP

# mount partitions
mount /dev/$ROOT /mnt
mount --mkdir /dev/$EFI /mnt/boot
swapon /dev/$SWAP

# install base packages
pacstrap -K /mnt base linux-lts linux-lts-headers linux linux-firmware git sudo\
    neofetch htop $CPU-ucode
