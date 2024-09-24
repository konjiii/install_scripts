#!/usr/bin/env bash

echo "enabling os-prober in grub"
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

echo "mounting windows EFI partition (/dev/$WIN_EFI) to /boot/EFI"
sudo mount /dev/$WIN_EFI /boot/EFI

echo "setting systemd boot log to verbose"
sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3\"/" /etc/default/grub

echo "updating the default kernel"
# make linux (non lts) the default kernel
sudo sed -i "s/version_sort -r/version_sort -V/" /etc/grub.d/10_linux

echo "enabling grub recovery mode menu entries"
# turn on generation of recovery mode menu entries
sudo sed -i "s/GRUB_DISABLE_RECOVERY=true/#GRUB_DISABLE_RECOVERY=true/" /etc/default/grub

echo "rebuilding grub config"
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "installing rustup"
# install rustup and rust-analyzer
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
echo "installing rust-analyzer"
rustup component add rust-analyzer

# setup paru
cd /home/$USER
echo "downloading paru from AUR"
git clone https://aur.archlinux.org/paru.git
echo "changing directory to paru"
cd paru
echo "installing paru"
makepkg -si --needed
echo "exiting paru directory"
cd ..
echo "removing paru git repository"
rm -rf paru
echo "changing directory to root"

echo "installing AUR packages"
# install AUR packages using paru
paru -Syu $(curl https://raw.githubusercontent.com/konjiii/install_scripts/master/arch_linux/laptop/packages/aur) --needed

echo "initializing chezmoi and applying dotfiles from \
 https://github.com/konjiii/dotfiles.git"
# setup chezmoi
chezmoi init --apply https://github.com/konjiii/dotfiles.git

cd ~/
echo "installing acer-wmi-battery"
git clone https://github.com/frederik-h/acer-wmi-battery.git
cd acer-wmi-battery
make

echo "turning on acer battery health mode"
sudo insmod acer-wmi-battery.ko enable_health_mode=1

cd ~/
rm -rf acer-wmi-battery

echo "setting dark mode"
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

echo "installing tpm for tmux package management"
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

echo "removing current script"
# remove post reboot script
rm ~/post_reboot.sh

echo "post reboot configuration complete, rebooting in 5 seconds"
sleep 5
echo "rebooting"
# reboot to finish installation
reboot
