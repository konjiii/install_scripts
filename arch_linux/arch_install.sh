#!/usr/bin/env bash

# create partitions
lsblk

echo "enter disk:"
read DISK
cfdisk /dev/$DISK

# ask required information
while :
do
    echo "CPU: intel/amd?"
    read CPU
    
    if [ "$CPU" == "intel" ] || [ "$CPU" == "amd" ];
    then
        break
    else
        echo "invalid input"
    fi
done

while :
do
    echo "GPU: nvidia/amd/intel?"
    read GPU
    if [ "$GPU" == "nvidia" ] || [ "$GPU" == "amd" ] || [ "$GPU" == "intel" ];
    then
        break
    else
        echo "invalid input"
    fi
done

while :
do
    echo "laptop/desktop?"
    read DEVICE
    if [ "$DEVICE" == "laptop" ] || [ "$DEVICE" == "desktop" ];
    then
        break
    else
        echo "invalid input"
    fi
done

lsblk

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

    if [ "$PASS" == "$PASS2" ];
    then
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

# turn on parallel downloads
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5/" /etc/pacman.conf

# install packages
pacstrap -K /mnt base base-devel linux-lts linux-lts-headers linux linux-firmware git sudo\
    neofetch htop $CPU-ucode ark bluez bluez-utils btop chezmoi clang cmake copyq discord\
    dosfstools dunst dust efibootmgr feh firewalld fuse2 gimp git\
    github-cli go grub htop i3-wm i3lock imagemagick ipython kitty krita\
    libqalculate libreoffice-fresh lightdm lightdm-slick-greeter links maim\
    mtools neofetch neovim networkmanager notification-daemon noto-fonts noto-fonts-cjk\
    noto-fonts-emoji npm okular os-prober p7zip pacman-contrib pamixer papirus-icon-theme\
    pavucontrol pipewire-pulse polybar python-gobject qbittorrent rofi spotify-launcher\
    sudo telegram-desktop texlive thefuck tldr torbrowser-launcher translate-shell\
    trash-cli ttf-cascadia-code-nerd ttf-dejavu ttf-font-awesome vim virtualbox\
    wget xclip xcolor xorg zbar

genfstab -U /mnt >> /mnt/etc/fstab

cat /mnt/etc/fstab
while :
do
    echo "was the fstab generated correctly? (yes/no)"
    read ANSW

    if [ "$ANSW" == "yes" ] || [ "$ANSW" == "y" ];
    then
        break
    elif [ "$ANSW" == "no" ] || [ "$ANSW" == "n" ];
    then
        echo "please correct the errors"
        read _
        nvim /mnt/etc/fstab
        break
    else
        echo "invalid input"
    fi
done

arch-chroot /mnt

echo "lol"
