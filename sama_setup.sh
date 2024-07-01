#!/bin/bash

# Prompt for SMB user name and password
read -p 'Enter SMB user name: ' smbu
echo "$smbu"
read -p 'Enter SMB user password: ' smbp
echo "$smbp"
smbg=smb_group
echo "$smbg"

# Check if nano is installed, if not install it
if ! yum list installed | grep -q 'nano'; then
    sudo yum install -y nano
    echo "Nano editor has been installed"
fi

# Update the system
sudo yum update -y

# Add repository
sudo dnf -y install almalinux-release-devel
sudo dnf -y install nano
sudo dnf -y install net-tools
sudo dnf config-manager --set-enabled powertools
sudo dnf config-manager --set-enabled crb

# Install wget if not installed
if ! yum list installed | grep -q 'wget'; then
    sudo dnf -y install wget
    echo "WGET has been installed"
fi

# Create Samba user and group
sudo useradd "$smbu"
(echo "$smbp"; echo "$smbp") | sudo smbpasswd -s -a "$smbu"
sudo groupadd "$smbg"
sudo usermod -aG "$smbg" "$smbu"

# Setup file shares and folders with permissions
sudo mkdir /mnt/Winshare
sudo chmod -R 755 /mnt/Winshare
sudo chown -R nobody:"$smbg" /mnt/Winshare
sudo chcon -t samba_share_t /mnt/Winshare
sudo mkdir /mnt/Data
sudo chmod -R 755 /mnt/Data
sudo chown -R nobody:"$smbg" /mnt/Data
sudo chcon -t samba_share_t /mnt/Data

# Setup file shares in Samba configuration
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bk
sudo nano /etc/samba/smb.conf
cat <<-EOF | sudo tee -a /etc/samba/smb.conf
[Data]
    path = /mnt/Data
    valid users = @$smbg
    browsable = yes
    writable = yes
    guest ok = yes
    read only = no
EOF

# Configure firewall for Samba and other services
sudo firewall-cmd --permanent --add-service=samba
sudo firewall-cmd --zone=public --add-port=80/udp --permanent
sudo firewall-cmd --zone=public --add-port=80/tcp --permanent
sudo firewall-cmd --zone=public --add-port=137/udp --permanent
sudo firewall-cmd --zone=public --add-port=137/tcp --permanent
sudo firewall-cmd --zone=public --add-port=138/udp --permanent
sudo firewall-cmd --zone=public --add-port=138/tcp --permanent
sudo firewall-cmd --zone=public --add-port=139/udp --permanent
sudo firewall-cmd --zone=public --add-port=139/tcp --permanent
sudo firewall-cmd --zone=public --add-port=443/tcp --permanent
sudo firewall-cmd --zone=public --add-port=445/tcp --permanent
sudo firewall-cmd --zone=public --add-port=3389/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-all

# Install CIFS utilities
sudo dnf -y install cifs-utils
cat <<-EOF | sudo tee -a /etc/fstab
//192.168.0.28/d /mnt/Winshare cifs _netdev,credentials=/etc/.credfile,dir_mode=0755,file_mode=0755,uid=500,gid=500 0 0
EOF

cat <<-EOF | sudo tee /etc/.credfile
username=[YourUserName]
password=[YourUserPassword]
domain=[YourDomain]
EOF

# Plex setup
sudo wget https://downloads.plex.tv/plex-media-server-new/1.32.5.7349-8f4248874/redhat/plexmediaserver-1.32.5.7349-8f4248874.x86_64.rpm
sudo dnf install -y plexmediaserver-1.32.5.7349-8f4248874.x86_64.rpm
sudo firewall-cmd --zone=public --add-port=32400/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-all

sudo systemctl enable plexmediaserver
sudo systemctl start plexmediaserver
sudo firewall-cmd --add-service=plex --zone=public --permanent
sudo firewall-cmd --reload

# Configure Apache as a Reverse Proxy for Plex
sudo dnf install httpd -y
sudo systemctl enable --now httpd
sudo setsebool -P httpd_can_network_connect on

cat <<-EOF | sudo tee /etc/httpd/conf.d/plexmedia.conf
<VirtualHost *:80>
    ServerName example.com
    ErrorDocument 404 /404.html

    # HTTP proxy
    ProxyPreserveHost On
    ProxyPass / http://localhost:32400/
    ProxyPassReverse / http://localhost:32400/

    # Websocket proxy
    <Location /:/websockets/notifications>
        ProxyPass wss://localhost:32400/:/websockets/notifications
        ProxyPassReverse wss://localhost:32400/:/websockets/notifications
    </Location>
</VirtualHost>
EOF

sudo apachectl -t
sudo systemctl reload httpd

# Reboot the system
sudo reboot
