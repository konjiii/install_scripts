#!/usr/bin/env bash

# set up optimus-manager
if [ "$DEVICE" == "laptop" ];
then
    sudo sed -i "s/^startup_mode=.*/startup_mode=auto/" /etc/optimus-manager/optimus-manager.conf
fi

# add windows to grub menu
sudo sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=20/" /etc/default/grub
sudo sed -i "s/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/" /etc/default/grub

lsblk

while :
do
    echo "enter windows EFI partition:"
    read WIN_EFI
    echo "you entered $WIN_EFI, is this correct? (y/n)"
    read ans
    if [ "$ans" == "y" ];
    then
        break
    fi
done

sudo mount /dev/$WIN_EFI /boot/EFI

sudo grub-mkconfig -o /boot/grub/grub.cfg

# setup paru
cd /home/$USER
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm --needed
cd ..
rm -rf paru
cd /

# install paru packages
paru -Syu eclipse-java floorp-bin github-desktop miniconda3 qrcp tdrop-git\
    visual-studio-code-insiders-bin nordvpn-bin --noconfirm --needed

if [ "$DEVICE" == "laptop" ];
then
    paru -Syu optimus-manager optimus-manager-qt --noconfirm --needed
fi

# install rustup and rust-analyzer
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
rustup component add rust-analyzer

# setup chezmoi
chezmoi init --apply https://github.com/konjiii/dotfiles.git

# turn off wake on mouse
attrs=$(lsusb | grep Logitech | awk '{print $6;}')
idVendor=$(echo $attrs | cut -d':' -f1)
idProduct=$(echo $attrs | cut -d':' -f2)
usbController=$(grep $idProduct /sys/bus/usb/devices/*/idProduct | cut -d'/' -f6)

cat <<EOF > ./mouse_wake.sh
cat <<MOUSE > /etc/udev/rules.d/50-wake-on-device.rules
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="$idVendor", \
ATTRS{idProduct}=="$idProduct", ATTR{power/wakeup}="disabled", \
ATTR{driver/$usbController/power/wakeup}="disabled"
MOUSE
EOF

sudo sh ./mouse_wake.sh

rm ./mouse_wake.sh

# remove post reboot script
rm ~/post_reboot.sh

# reboot to finish installation
reboot
