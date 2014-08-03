#!/bin/bash

#install the necessary packages - Apache, unzip tool and Java Runtime Environvent
yum install httpd unzip java-1.7.0-openjdk.x86_64 -y 

#download the tools for remote installation
wget http://hatax.home.comcast.net/~hatax/bb/Playbook_Tools.zip

#create our working directory and unzip the tools into it 
mkdir /etc/bar
unzip Playbook_Tools.zip -d /etc/bar

#move the files to only one directory to make things easier
mv /etc/bar/lib/* /etc/bar/

#remove the directory and the downloaded file we no longer need
rm -rf /etc/bar/lib
rm -f Playbook_Tools.zip

#change ownership if the working directory and make the file executable
chown apache:apache /etc/bar
chmod +x /etc/bar/BarDeploy.jar

#create and populate the bar installation script
cat > /etc/bar/install.sh <<CONTENT
#!/bin/bash

device=$1
password=$2
file=$3

cd /etc/bar
if [[ $file == *http://* || $file == *https://* ]]
   then
      filename="${file##*/}"
      if [[ ! -f $filename ]]
         then
         wget $file -O $filename
      fi
fi

if [[ -n "$filename" ]]
   then
      java -Xmx64M -jar BarDeploy.jar -installApp -device $device -password $password $filename
   else
      java -Xmx64M -jar BarDeploy.jar -installApp -device $device -password $password $file
fi
exit
CONTENT

#change ownership of the script and make it executable
chown apache:apache /etc/bar/install.sh
chmod +x /etc/bar/install.sh

#create and populate the php file responsible for communication between the app and the bar installation software
cat > /var/www/html/install.php <<CONTENT
<?php
$device = $_POST['device'];
$password = $_POST['password'];
$file = $_POST['file'];
echo "Installing the app. Please wait a little...";
echo "\n";
echo exec("/etc/bar/install.sh $device $password $file");
echo "\n";
?>
CONTENT

#change ownership and make the php file executable
chown apache:apache /var/www/html/install.php
chmod +x /var/www/html/install.php

#open port 80 on firewall, save and restart it
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
service iptables save
service iptables restart

exit