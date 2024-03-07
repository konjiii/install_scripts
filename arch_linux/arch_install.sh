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

echo "enter timezone:"
read TIMEZONE

# format partitions
mkfs.fat -F32 /dev/$EFI
mkfs.ext4 /dev/$ROOT
mkswap /dev/$SWAP

# mount partitions
mount /dev/$ROOT /mnt
mount --mkdir /dev/$EFI /mnt/boot
swapon /dev/$SWAP

# turn on parallel downloads and multilib
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5/" /etc/pacman.conf
sed -i "s/#\[multilib\]\n#Include.*/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/" /etc/pacman.conf

# install packages
pacstrap -K /mnt base base-devel linux-lts linux-lts-headers linux linux-firmware git sudo\
    neofetch htop $CPU-ucode ark bluez bluez-utils btop chezmoi clang cmake copyq discord\
    dosfstools dunst dust efibootmgr feh firewalld fuse2 gimp git\
    github-cli go grub htop i3-wm i3lock imagemagick ipython kitty krita\
    libqalculate libreoffice-fresh lightdm lightdm-slick-greeter links maim\
    mpv mtools neofetch neovim networkmanager notification-daemon noto-fonts noto-fonts-cjk\
    noto-fonts-emoji npm okular os-prober p7zip pacman-contrib pamixer papirus-icon-theme\
    pavucontrol pipewire-pulse polybar python-gobject qbittorrent rofi spotify-launcher\
    sudo telegram-desktop texlive thefuck tldr torbrowser-launcher translate-shell\
    trash-cli ttf-cascadia-code-nerd ttf-dejavu ttf-font-awesome vim virtualbox\
    wget xclip xcolor xorg zbar

# generate fstab
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
        vim /mnt/etc/fstab
        break
    else
        echo "invalid input"
    fi
done

# make the script that runs after chrooting
cat <<EOF > /mnt/post_chroot.sh
# set timezone
TIMEZONE=$(find /usr/share/zoneinfo/ -maxdepth 2 -name $TIMEZONE)
ln -sf $TIMEZONE /etc/localtime
hwclock --systohc
systemctl enable systemd-timesyncd

# set and generate locales
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# set hostname and hosts
echo "archlinux" > /etc/hostname

cat <<HOSTS > /etc/hosts
# Static table lookup for hostnames.
# See hosts(5) for details.


127.0.0.1		localhost
::1			    localhost
127.0.1.1		archlinux.localdomain		archlinux
HOSTS

# set root passwd
echo root:$PASS | chpasswd

# create user
useradd -m -G wheel,video -s /bin/bash $USER
echo $USER:$PASS | chpasswd

# give sudo access to wheel group
sed -i "s/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/" /etc/sudoers

# install grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# change pacman configuration
sed -i "s/#Color/Color/" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5\nILoveCandy/" /etc/pacman.conf
sed -i "s/#\[multilib\]\n#Include.*/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/" /etc/pacman.conf

# change lightdm configuration
sed -i "s/^#greeter-session=.*/greeter-session=lightdm-slick-greeter/" /etc/lightdm/lightdm.conf
cat <<GREETER > /etc/lightdm/slick-greeter.conf
[Greeter]
icon-theme-name=Papirus-Dark
clock-format=%H:%M:%S
draw-grid=false
GREETER

# change makepkg configuration
sed -i "s/^OPTIONS=.*/OPTIONS=(strip docs !libtool !staticlibs !emptydirs zipman purge\
    !debug lto)/" /etc/makepkg.conf

# setup yay
git clone https://aur.archlinux.org/yay.git
cd yay
sudo -H -u $USER bash -c makepkg -si
cd ..
rm -rf yay

# install yay packages
yay -Syu eclipse-java floorp-bin github-desktop miniconda3 qrcp tdrop-git\
    visual-studio-code-insiders-bin nordvpn-bin

# install packages depending on device
if [ "$DEVICE" == "laptop" ];
then
    pacman -Syu tlp tlp-rdw smartmontools brightnessctl powertop\
        wifi-qr
    yay -S optimus-manager optimus-manager-qt
elif [ "$DEVICE" == "desktop" ];
then
    pacman -S picom
fi
if [ "$CPU" == "intel" ];
then
    pacman -S intel-media-driver libva-utils
fi
if [ "$GPU" == "nvidia" ];
then
    pacman -S nvidia-lts nvidia-settings
fi

# enable services
systemctl enable NetworkManager
systemctl enable lightdm
systemctl enable firewalld
systemctl enable bluetooth
if [ "$DEVICE" == "laptop" ];
then
    systemctl enable tlp

    # enable i3lock on suspend
    cat <<I3LOCK > /etc/systemd/system/i3lock.service
    [Unit]
    Description=i3lock on suspend
    Before=sleep.target

    [Service]
    User=$USER
    Type=forking
    Environment=DISPLAY=:0
    ExecStart=/usr/bin/i3lock -c 141413

    [Install]
    WantedBy=sleep.target
I3LOCK
    
    # enable powertop auto-tune on boot
    cat <<POWERTOP > /etc/systemd/system/powertop.service
    [Unit]
    Description=Powertop auto-tune

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/bin/powertop --auto-tune

    [Install]
    WantedBy=multi-user.target
POWERTOP

    systemctl enable i3lock
    systemctl enable powertop
fi

systemctl enable post_reboot

# remove post chroot script
rm /post_chroot.sh
EOF

# make the script that runs after rebooting
cat <<EOF > /mnt/post_reboot.sh
# set up optimus-manager
if [ "$DEVICE" == "laptop" ];
then
    sed -i "s/^startup_mode=.*/startup_mode=auto/" /etc/optimus-manager/optimus-manager.conf
fi

# add windows to grub menu
sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=20/" /etc/default/grub
sed -i "s/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/" /etc/default/grub

sudo grub-mkconfig -o /boot/grub/grub.cfg

# setup chezmoi
chezmoi init --apply https://github.com/konjiii/dotfiles.git

# remove post reboot script
systemctl disable post_reboot
rm /etc/systemd/system/post_reboot.service
rm /post_reboot.sh

# reboot to finish installation
reboot
EOF

# add service to run post_reboot.sh on startup
cat <<EOF > /mnt/etc/systemd/system/post_reboot.service
[Unit]
Description=Run post_reboot.sh

[Service]
Type=oneshot
ExecStart=/bin/bash /post_reboot.sh

[Install]
WantedBy=multi-user.target
EOF

# chroot into the new system
arch-chroot /mnt sh /post_chroot.sh

# unmount and reboot
umount -R /mnt
echo "installation complete, rebooting in 5 seconds"
sleep 5
reboot