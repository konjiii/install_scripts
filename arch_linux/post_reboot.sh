#!/usr/bin/env bash

# set up optimus-manager
if [ "$DEVICE" == "laptop" ];
then
    sudo sed -i "s/^startup_mode=.*/startup_mode=auto/" /etc/optimus-manager/optimus-manager.conf
fi

# add windows to grub menu
sudo sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=20/" /etc/default/grub
sudo sed -i "s/^#GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/" /etc/default/grub

sudo grub-mkconfig -o /boot/grub/grub.cfg

# setup yay
cd /home/$USER
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm --needed
cd ..
rm -rf yay
cd /

# install yay packages
yay -Syu eclipse-java floorp-bin github-desktop miniconda3 qrcp tdrop-git\
    visual-studio-code-insiders-bin nordvpn-bin --noconfirm --needed

if [ "$DEVICE" == "laptop" ];
then
    yay -Syu optimus-manager optimus-manager-qt --noconfirm --needed
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

sudo sh -c 'cat <<EOF > /etc/udev/rules.d/50-wake-on-device.rules
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="$idVendor", \
ATTRS{idProduct}=="$idProduct", ATTR{power/wakeup}="disabled", \
ATTR{driver/$usbController/power/wakeup}="disabled"
EOF'

# remove post reboot script
rm ~/post_reboot.sh

# reboot to finish installation
reboot
