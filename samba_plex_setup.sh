#!/bin/bash

read -p 'Enter SMB user name: ' smbu
echo "$smbu"
read -p 'Enter SMB user password: ' smbp
echo "$smbp"
smbg=smb_group
echo "$smbg"

if [ 'yum list installed' | grep 'nano' -ne 'nano' ]
then
    yum install -y nano
    echo "Nano editor has been installed"
fi

yum update -y

// Add repo
dnf -y install almalinux-release-devel
dnf -y install nano
dnf -y install net-tools
dnf config-manager --set-enabled powertools
dnf config-manager --set-enabled crb


// Install wget
if [ 'yum list installed' | grep 'nano' -ne 'wget' ]
    then
    dnf -y install wget
    echo "WGET has been installed"
fi


// Create Samba user and groups
useradd $smbu
(echo SambaShare; echo SambaShare ) | smbpasswd -s $smbu $smbp
groupadd @smbg
usermod -g @smbg @smbu

//Setup file shares and folder with permissions

mkdir /mnt/Winshare
chmod -R 755 /mnt/Winshare
chown -R nobody:@smbg /mnt/Winshare
chcon -t samba_share_t /mnt/Winshare
mkdir /mnt/Data
chmod -R 755 /mnt/Data
chown -R nobody:@smbg /mnt/Data
chcon -t samba_share_t /mnt/Data

//Setup file shares and plex media folder
chcon -t samba_share_t /mnt/Data
cp /etc/samba/smb.conf /etc/samba/smb.conf.bk
nano /etc/samba/smb.conf
cat > /etc/samba/smb.conf <<-EOF
 [Data]
        path = /mnt/Data
        valid users = @smb_group
        browsable = yes
        writable = yes
        guest ok = yes
        read only = no

firewall-cmd --permanent --add-service=samba
firewall-cmd --zone=public --add-port=80/udp --permanent
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=137/udp --permanent
firewall-cmd --zone=public --add-port=137/tcp --permanent
firewall-cmd --zone=public --add-port=138/udp --permanent
firewall-cmd --zone=public --add-port=138/tcp --permanent
firewall-cmd --zone=public --add-port=139/udp --permanent
firewall-cmd --zone=public --add-port=139/tcp --permanent
firewall-cmd --zone=public --add-port=137/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --zone=public --add-port=445/tcp --permanent
firewall-cmd --zone=public --add-port=445/tcp --permanent
firewall-cmd --zone=public --add-port=3389/tcp --permanent
firewall-cmd --reload
firewall-cmd --list-all

//Windows fileshare mount utility install
dng -y install cifs-utils
cat > /etc/fstab <<-EOF
//192.168.0.28/d /mnt/Winshare                     cifs    _netdev,credentials=/etc/.credfile,dir_mode=0755,file_mode=0755,uid=500,gid=500 0 0
cat > /etc/.credfile <<-EOF
 username=[YourUserName]
 password=[YourUserPassword]
 domain=[YourDomain]

// Plex setup
sudo wget https://downloads.plex.tv/plex-media-server-new/1.32.5.7349-8f4248874/redhat/plexmediaserver-1.32.5.7349-8f4248874.x86_64.rpm
firewall-cmd --zone=public --add-port=32400/tcp --permanent
firewall-cmd --reload
firewall-cmd --list-all


systemctl enable plexmediaserver
systemctl start plexmediaserver
firewall-cmd --add-service=plex --zone=public --permanent
firewall-cmd --reload



// Configure Apache as a Reverse Proxy for Plex

dnf install httpd -y
sudo systemctl enable --now httpd
sudo setsebool -P httpd_can_network_connect on

cat > /etc/httpd/conf.d/plexmedia.conf <<-EOF
 <VirtualHost *:80>
   ServerName example.com
   ErrorDocument 404 /404.html

   #HTTP proxy
   ProxyPreserveHost On
   ProxyPass / http://localhost:32400/
   ProxyPassReverse / http://localhost:32400/

   #Websocket proxy
   <Location /:/websockets/notifications>
        ProxyPass wss://localhost:32400/:/websockets/notifications
        ProxyPassReverse wss://localhost:32400/:/websockets/notifications
   </Location>
 </VirtualHost>

apachectl -t
sudo systemctl reload httpd

reboot
