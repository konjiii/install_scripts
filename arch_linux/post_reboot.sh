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


# setup chezmoi
chezmoi init --apply https://github.com/konjiii/dotfiles.git

# remove post reboot script
rm /post_reboot.sh

# reboot to finish installation
reboot
