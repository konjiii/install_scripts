#!/usr/bin/env bash

# create partitions
lsblk

# ask required information
echo "enter disk:"
read DISK
cfdisk /dev/$DISK

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

ls /usr/share/zoneinfo/

while :
do
    echo "enter timezone:"
    read TIMEZONE

    if [[ "$(file /usr/share/zoneinfo/$TIMEZONE)" == *"cannot open"* ]]; 
    then
        echo "invalid timezone"
    else
        break
    fi
done

if [[ "$(file /usr/share/zoneinfo/$TIMEZONE)" == *"directory"* ]]; 
then
    ls /usr/share/zoneinfo/$TIMEZONE
    while :
    do
        echo "enter city:"
        read CITY
        if [[ "$(file /usr/share/zoneinfo/$TIMEZONE/$CITY)" == *"No such file or directory"* ]]; 
        then
            echo "invalid city"
        else
            TIMEZONE="$TIMEZONE/$CITY"
            break
        fi
    done
fi

echo "timezone: $TIMEZONE"

echo "formatting partitions"
# format partitions
mkfs.fat -F32 /dev/$EFI
mkfs.btrfs /dev/$ROOT
mkswap /dev/$SWAP

echo "mounting partitions"
# mount partitions
mount /dev/$ROOT /mnt
mount --mkdir /dev/$EFI /mnt/boot
swapon /dev/$SWAP

echo "enabling parallel downloads and multilib"
# turn on parallel downloads and multilib
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5/" /etc/pacman.conf
sed -i "s&#\[multilib\]&\[multilib\]\nInclude = /etc/pacman.d/mirrorlist&" /etc/pacman.conf

echo "installing base packages"
# install packages
pacstrap -K /mnt base base-devel linux-lts linux linux-firmware sudo intel-ucode
    
echo "generating file system table"
# generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo "generating post chroot script (post_chroot.sh)"
# make the script that runs after chrooting
cat <<EOF > /mnt/post_chroot.sh
echo "setting timezone"
# set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc
systemctl enable systemd-timesyncd

echo "generating locales"
# set and generate locales
sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "setting hostname and hosts"
# set hostname and hosts
echo "archlaptop" > /etc/hostname

cat <<HOSTS > /etc/hosts
# Static table lookup for hostnames.
# See hosts(5) for details.


127.0.0.1		localhost
::1			    localhost
127.0.1.1		archlaptop.localdomain		archlaptop
HOSTS

echo "setting root passwd and creating user"
# set root passwd
echo root:$PASS | chpasswd

# create user
useradd -m -G users,wheel,video,audio,games -s /bin/zsh $USER
echo $USER:$PASS | chpasswd

echo "giving sudo access to wheel group"
# give sudo access to wheel group
sed -i "s/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

echo "changing pacman configuration"
# change pacman configuration
sed -i "s/#Color/Color/" /etc/pacman.conf
sed -i "s/#ParallelDownloads = 5/ParallelDownloads = 5\nILoveCandy/" /etc/pacman.conf
sed -i "s/#\[multilib\]/\[multilib\]\nInclude = \/etc\/pacman.d\/mirrorlist/" /etc/pacman.conf

echo "changing makepkg configuration"
# change makepkg configuration
sed -i "s/^OPTIONS=.*/OPTIONS=(strip docs !libtool !staticlibs !emptydirs zipman purge\
    !debug lto)/" /etc/makepkg.conf

echo "installing native packages"
pacman -Syu \$(curl https://raw.githubusercontent.com/konjiii/install_scripts/master/arch_linux/laptop/packages/pacman) --needed

echo "installing grub"
# install grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
echo "generating grub configuration"
grub-mkconfig -o /boot/grub/grub.cfg

echo "enabling general services"
# enable services
systemctl enable NetworkManager
echo "enabling laptop services"
systemctl enable tlp

echo "making powertop service"
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

echo "enabling powertop services"
systemctl enable powertop

echo "enabling and starting uncomplicated firewall"
# setup ufw
systemctl enable ufw
systemctl start ufw
echo "setting ufw rules"
ufw default deny
ufw allow from 192.168.0.0/24
ufw limit ssh
ufw enable

echo "allowing forwarding in ufw"
# accept forwarding in ufw for vpns
sed -i "s/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY=\"ACCEPT\"/" /etc/default/ufw
sed -i "s%^#net/ipv4/ip_forward=1%net/ipv4/ip_forward=1%" /etc/ufw/sysctl.conf
sed -i "s%^#net/ipv6/conf/default/forwarding=1%net/ipv6/conf/default/forwarding=1%" /etc/ufw/sysctl.conf
sed -i "s%^#net/ipv6/conf/all/forwarding=1%net/ipv6/conf/all/forwarding=1%" /etc/ufw/sysctl.conf

echo "blacklisting nvidia drivers"
# turn off graphics card
cat <<BLACKLIST > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
BLACKLIST

echo "adding udev rules to turn off nvidia gpu"
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

echo "downloading post reboot script (post_reboot.sh)"
curl https://raw.githubusercontent.com/konjiii/install_scripts/master/arch_linux/laptop/post_reboot.sh\
    > /home/$USER/post_reboot.sh

echo "removing current script"
# remove post chroot script
rm /post_chroot.sh
EOF

echo "changing root to /mnt and executing post_chroot.sh"
# chroot into the new system
arch-chroot /mnt sh /post_chroot.sh

# unmount and reboot
echo "installation complete, rebooting in 5 seconds"
sleep 5
echo "unmounting partitions"
umount -R /mnt
echo "rebooting"
reboot
