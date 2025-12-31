
# Azure Linux login failure  or Permission denied or Access denied
# SSH is working but authentication failure or no authentication

# to verify the pv scan and vg scan 
sudo pvscan
sudo vgscan

# To verify the mount and disk state
lsblk -f
cat /etc/fstab
sudo fdisk -l /dev/sdc
sudo parted /dev/sdc print

# steps to recover
sudo mkdir -p /mnt/rescue
sudo mount /dev/mapper/vg0-root /mnt/rescue
ls /mnt/rescue
sudo chroot /mnt/rescue  	<-- this will behave like your on broken VM
useradd -m -s /bin/bash azurefix
passwd azurefix
usermod -aG sudo azurefix
exit
sudo umount /mnt/rescue


