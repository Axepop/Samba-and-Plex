#!/bin/bash

# Update the system
sudo dnf update -y

# Install required dependencies
sudo dnf install -y epel-release
sudo dnf install -y dkms kernel-devel kernel-headers make bzip2 perl gcc

# Add VirtualBox repository for VirtualBox 7
sudo wget https://download.virtualbox.org/virtualbox/rpm/el/virtualbox.repo -O /etc/yum.repos.d/virtualbox.repo

# Import Oracle public key
sudo rpm --import https://www.virtualbox.org/download/oracle_vbox.asc

# Install VirtualBox 7
sudo dnf install -y VirtualBox-7.0

# Setup vboxdrv
sudo /usr/lib/virtualbox/vboxdrv.sh setup

# Add user to vboxusers group
sudo usermod -aG vboxusers $(whoami)

# Create a post-reboot script
cat << 'EOF' | sudo tee /root/post_reboot_virtualbox.sh
#!/bin/bash
# This script will run after reboot to finalize VirtualBox installation

# Load vboxdrv module
sudo /usr/lib/virtualbox/vboxdrv.sh setup

# Remove the cron job to prevent it from running again
(crontab -l | grep -v "@reboot /root/post_reboot_virtualbox.sh") | crontab -

# Remove this script
sudo rm -- "$0"
EOF

# Make the post-reboot script executable
sudo chmod +x /root/post_reboot_virtualbox.sh

# Schedule the post-reboot script to run on reboot using cron
(crontab -l ; echo "@reboot /root/post_reboot_virtualbox.sh") | crontab -

# Reboot to load the new kernel modules
echo "Rebooting the system to load the new kernel modules and complete installation..."
sudo reboot
