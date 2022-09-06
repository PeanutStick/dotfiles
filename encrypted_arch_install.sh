# == MY ARCH SETUP INSTALLER == #e
#part1
printf '\033c'
echo "Welcome to bugswriter's arch installer script"
echo "Forked by Peanutstick"

sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
pacman --noconfirm -Sy archlinux-keyring
loadkeys fr
timedatectl set-ntp true

modprobe dm-crypt
modprobe dm-mod
lsblk
echo "Enter the drive: "
read drive

fdisk -l $drive |grep 'EFI' 
if [ $? == 1 ];then
        echo "You don't have EFI partition on "$drive
        efi=""
        
else
        echo "There is an EFI partition on "$drive
        efi="\n"
fi

read -p "Do you want to create efi partition? [y/n]" answer
if [[ $answer = y ]] ; then
	echo -e "n\np\n\n\n+250M\nt"$efi"\nef\nw" | fdisk $drive # EFI
fi
echo "Create the main partition with the remaining space on the disk."
sleep 1
fdisk $drive << FDISK_CMDS
n
p



t

8e
w
FDISK_CMDS
number_of_lvm=$(fdisk -l $drive |grep 'LVM' |wc -l)
if [ $number_of_lvm == 1 ];then
		lvm_partiton=$(fdisk -l $drive |grep 'LVM' | awk '{print $1;}')
        echo "let's encrypt the LVM partiton "$lvm_partiton
else
        echo "You have "$number_of_lvm" LVM partition"
        echo "You have to select the one you want to encrypt:"
        fdisk -l $drive |grep 'LVM' | awk '{print $1;}'
        echo "example: /dev/sda2, "
        echo "!!! If you are not sure, mount the partiton to see if it's empty (ctrl+c). !!!"
        read lvm_partiton
fi

cryptsetup luksFormat $lvm_partiton
cryptsetup open $lvm_partiton cryptlvm
pvcreate /dev/mapper/cryptlvm
vgcreate u01 /dev/mapper/cryptlvm
while true; do
        read -p "Space for swap partition: [4G/no]" swap_size
        if [[ $swap_size =~ ^[0-9]+G ]]
        then
		        lvcreate -L $swap_size u01 -n swap
		        mkswap /dev/u01/swap
                break
        elif [[ $swap_size == "no" ]]
        then
                break
        else
                echo "Not a valid value"
        fi
done
while true; do
		echo "If you choose \"all\" you will have the home in your root partition."
        read -p "Space for root partition: [40G/all]" root_size
        if [[ $root_size =~ ^[0-9]+G ]]
        then
		        lvcreate -L $root_size u01 -n root
		        lvcreate -l +100%FREE u01 -n home
		        mkfs.ext4 /dev/u01/home
                break
        elif [[ $root_size == "all" ]]
        then
		        lvcreate -l +100%FREE u01 -n root
                break
        else
                echo "Not a valid value"
        fi
done
efi_partition=$(fdisk -l $drive |grep 'EFI' | awk '{print $1;}')
mkfs.fat -F32 $efi_partition
mkfs.ext4 /dev/u01/root


mount /dev/u01/root /mnt
mkdir /mnt/home
mount /dev/u01/home /mnt/home
mkdir /mnt/boot
mount $efi_partition /mnt/boot
mkswap /dev/u01/swap
swapon /dev/u01/swap

pacstrap /mnt base base-devel linux linux-firmware lvm2
genfstab -U /mnt >> /mnt/etc/fstab
sed -i "s/block/block encrypt lvm2/" /mnt/etc/mkinitcpio.conf
sed -i "s/keyboard/keyboard keymap/" /mnt/etc/mkinitcpio.conf
sed '1,/^#part2$/d' `basename $0` > /mnt/arch_install2.sh
chmod +x /mnt/arch_install2.sh
arch-chroot /mnt ./arch_install2.sh
exit

#part2
printf '\033c'
pacman -S --noconfirm sed
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr-latin1" > /etc/vconsole.conf
echo "Hostname: "
read hostname
echo "Root password: "
passwd
echo $hostname > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >> /etc/hosts
mkinitcpio -p linux
lscpu |grep 'AMD' &> /dev/null
if [ $? == 0 ];then
        cpu_ucode="amd-ucode"
else
        cpu_ucode="intel-ucode"
fi
pacman -S --noconfirm xorg-server xorg-xinit xorg-xkill xorg-xsetroot xorg-xbacklight xorg-xprop \
noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-jetbrains-mono ttf-joypixels ttf-font-awesome \
sxiv mpv ffmpeg imagemagick \
fzf man-db feh python-pywal unclutter xclip maim \
zip unzip unrar p7zip xdotool \
dosfstools ntfs-3g git sxhkd bspwm feh zsh kitty pipewire pipewire-pulse pipewire-jack \
picom libnotify dunst slock jq aria2 firefox \
networkmanager openssh pamixer \
lightdm-gtk-greeter lightdm $cpu_ucode \
vim dmenu polybar grub efibootmgr os-prober base-devel linux-headers \
mtools dosfstools reflector rsync nemo flameshot

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 
sed -i 's/quiet/pci=noaer/g' /etc/default/grub

uid=$(blkid |grep crypto_LUKS | awk '{print $2}' | cut -c7-42)
sed -i 's#GRUB_CMDLINE_LINUX=""#GRUB_CMDLINE_LINUX="cryptdevice=UUID='$uid':cryptlvm root=/dev/u01/root"#g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg


systemctl enable NetworkManager.service
systemctl enable lightdm

echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "Enter Username: "
read username
useradd -m -G wheel -s /bin/zsh $username
passwd $username
echo "Pre-Installation Finish Reboot now"

ai3_path=/home/$username/arch_install3.sh

sed '1,/^#part3$/d' arch_install2.sh > $ai3_path

chown $username:$username $ai3_path

chmod +x $ai3_path

su -c $ai3_path -s /bin/sh $username

exit

#part3

printf '\033c'

cd $HOME
### The minimum if you can't fetch your dotfiles
install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc .config/bspwm/bspwmrc

install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc .config/sxhkd/sxhkdrc

cp /etc/X11/xinit/xinitrc .xinitrc
echo "exec bspwm" >> .xinitrc
echo "xrandr -s 1920x1080" > .xprofile
echo "polybar" >> .config/bspwm/bspwmrc
sed -i "s/urxvt/kitty/g" .config/sxhkd/sxhkdrc
mkdir .local/bin
echo "export PATH='$PATH:/home/tomahawk/tools/jdk1.8.0_92/bin'" >> .profile


### install yay
sudo git clone https://aur.archlinux.org/yay.git
sudo chown -R  $USER yay
cd yay
makepkg -si
### install themes polybar
# For the fonts cuz I don't know wish one I should take.
cd $HOME
git clone --depth=1 https://github.com/adi1090x/polybar-themes.git

cd polybar-themes
chmod +x setup.sh
./setup.sh



### fetch the dotsfiles
cd $HOME
git clone --separate-git-dir=$HOME/.dotfiles https://github.com/Peanutstick/dotfiles.git tmpdotfiles

rsync --recursive --verbose --exclude '.git' tmpdotfiles/ $HOME/

rm -r tmpdotfiles

# zshrc
mv zshrc .zshrc

# walp


sudo git clone --depth=1 https://github.com/PeanutStick/rwalp.git /usr/local/bin/

sudo chmod +x /usr/local/bin/*
chmod +x .config/polybar/*
echo "rwalp" >> .config/bspwm/bspwmrc
### Oh my zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
exit
