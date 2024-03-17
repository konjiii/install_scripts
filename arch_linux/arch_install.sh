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
    echo "GPU: nvidia/amd/intel/none?"
    read GPU
    if [ "$GPU" == "nvidia" ] || [ "$GPU" == "amd" ] || [ "$GPU" == "intel" ] || [ "$GPU" == "none" ];
    then
        break
    else
        echo "invalid input"
    fi
done

while :
do
    echo "Do you have integrated graphics? yes/no"
    read INTEGRATED
    if [ "$INTEGRATED" == "yes" ] || [ "$INTEGRATED" == "no" ];
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
pacstrap -K /mnt base base-devel linux-lts linux linux-headers linux-firmware git sudo\
    neofetch htop $CPU-ucode ark atuin biber bluez bluez-utils btop chezmoi clang cmake copyq discord\
    dosfstools dunst dust efibootmgr feh fuse2 gimp git\
    github-cli go grub htop i3-wm i3lock imagemagick ipython kitty krita\
    libqalculate libreoffice-fresh links maim\
    mpv mtools neofetch neovim networkmanager notification-daemon noto-fonts noto-fonts-cjk\
    noto-fonts-emoji npm okular os-prober p7zip pacman-contrib pamixer papirus-icon-theme\
    pavucontrol pipewire-pulse playerctl python-gobject qbittorrent rofi speedtest-cli spotify-launcher\
    starship sudo telegram-desktop texlive thefuck tldr torbrowser-launcher translate-shell\
    trash-cli ttf-cascadia-code-nerd ttf-dejavu ttf-font-awesome ufw unarchiver usbutils vim virtualbox\
    wget xclip xcolor xorg xorg-xinit yazi zbar zsh

# generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

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

# set keyboard config
cat <<KEYBOARD > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "us"
        Option "XkbModel" "pc105"
        Option "XkbVariant" ",qwerty"
        Option "XkbOptions" "caps:escape,altwin:swap_lalt_lwin"
EndSection
KEYBOARD

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
useradd -m -G users,wheel,video,audio,games -s /bin/zsh $USER
echo $USER:$PASS | chpasswd

# give sudo access to wheel group
sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

# install grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# change pacman configuration
sed -i "s/#Color/Color/" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5\nILoveCandy/" /etc/pacman.conf
sed -i "s/#\[multilib\]/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/" /etc/pacman.conf

# change makepkg configuration
sed -i "s/^OPTIONS=.*/OPTIONS=(strip docs !libtool !staticlibs !emptydirs zipman purge\
 !debug lto)/" /etc/makepkg.conf

# install packages depending on device
if [ "$DEVICE" == "laptop" ];
then
    pacman -Syu tlp tlp-rdw smartmontools brightnessctl powertop\
        wifi-qr i3status --noconfirm --needed
elif [ "$DEVICE" == "desktop" ];
then
    pacman -Syu picom polybar --noconfirm --needed
fi
if [ "$CPU" == "intel" ] && [ "$INTEGRATED" == "yes" ];
then
    pacman -Syu vulkan-intel intel-media-driver libva-utils mesa --noconfirm --needed
fi
if [ "$GPU" == "nvidia" ];
then
    pacman -Syu nvidia nvidia-settings --noconfirm --needed
fi

# enable services
systemctl enable NetworkManager
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

# setup ufw
systemctl enable ufw
systemctl start ufw
ufw default deny
ufw allow from 192.168.0.0/24
ufw limit ssh
ufw enable

# accept forwarding in ufw for vpns
sed -i "s/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/" /etc/default/ufw
sed -i "s%^#net/ipv4/ip_forward=1%net/ipv4/ip_forward=1%" /etc/ufw/sysctl.conf
sed -i "s%^#net/ipv6/conf/default/forwarding=1%net/ipv6/conf/default/forwarding=1%" /etc/ufw/sysctl.conf
sed -i "s%^#net/ipv6/conf/all/forwarding=1%net/ipv6/conf/all/forwarding=1%" /etc/ufw/sysctl.conf

if [ "$DEVICE" == "laptop" ];
then
    # turn off graphics card
    cat <<BLACKLIST > /etc/modprobe.d/blacklist-nouveau.conf
    blacklist nouveau
    options nouveau modeset=0
BLACKLIST

    cat <<REMOVE > /etc/udev/rules.d/00-remove-nvidia.rules
    # Remove NVIDIA USB xHCI Host Controller devices, if present
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"

    # Remove NVIDIA USB Type-C UCSI devices, if present
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"

    # Remove NVIDIA Audio devices, if present
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"

    # Remove NVIDIA VGA/3D controller devices
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
REMOVE
fi

curl https://raw.githubusercontent.com/konjiii/install_scripts/master/arch_linux/post_reboot.sh\
    > /home/$USER/post_reboot.sh

# remove post chroot script
rm /post_chroot.sh
EOF

# chroot into the new system
arch-chroot /mnt sh /post_chroot.sh

# unmount and reboot
umount -R /mnt
echo "installation complete, rebooting in 5 seconds"
sleep 5
reboot
