#!/bin/bash

#install the necessary packages - Apache, unzip tool and Java Runtime Environvent
yum install httpd php unzip java-1.7.0-openjdk.x86_64 -y 

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

#make the file executable
chmod +x /etc/bar/BarDeploy.jar

#create and populate the bar installation script
cat > /etc/bar/install.sh <<'CONTENT'
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

#make the script executable and change ownership of directory
chmod +x /etc/bar/install.sh
chown -R apache:apache /etc/bar


#create and populate the php file responsible for communication between the app and the bar installation software
cat > /var/www/html/install.php <<'CONTENT'
<?php

if (preg_match('/;/i', $_REQUEST["device"]) || preg_match('/;/i', $_REQUEST["password"]) || preg_match('/;/i', $_REQUEST["file"])) {
	die("No way! No malicious actions, please.\n");
}
else {
	$device = $_POST['device'];
	$password = $_POST['password'];
	$file = $_POST['file'];
	echo "Installing the app. Please wait a little...";
	echo "\n";
	echo exec("/etc/bar/install.sh $device $password $file");
	echo "\n";
}

?>
CONTENT

#create and populate the php file responsible for retrieving list of bar files from the server
cat > /var/www/html/list.php <<'CONTENT'
<?php
echo "Retrieving information...";
echo "\n";
$files = array();
foreach (glob("/etc/bar/*.bar") as $file) {
  $name = pathinfo($file);  
  echo $files[] = $name['basename'];
  echo "\n";
}
?>
CONTENT

#change ownership and make the php files executable
chown apache:apache /var/www/html/install.php
chown apache:apache /var/www/html/list.php
chmod +x /var/www/html/install.php
chmod +x /var/www/html/list.php

#open port 80 on firewall, save and restart it
iptables -I INPUT -p tcp --dport 80 -j ACCEPT
service iptables save
service iptables restart

#start Apache and make it start at server boot time
service httpd start
chkconfig httpd on

exit
