#!/bin/sh
# Author: Aaron K. Nall

apt-get update; apt-get upgrade -y; apt-get install -y fail2ban ufw;
# SSH, HTTP and HTTPS
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 'OpenSSH'
sudo ufw allow 9000
sudo ufw allow 8000
sudo ufw allow from 104.9.17.32

# Skip the following 3 lines if you do not plan on using FTP
#ufw allow 21
#ufw allow 50000:50099/tcp
#ufw allow out 20/tcp

# Show the new ufw status
sudo ufw status

# And lastly we activate UFW
sudo ufw --force enable

while [ "$selectedTimezone" = "" ]
do
        echo "Please enter your timezone as TZ database name"
        echo "  Reference https://en.wikipedia.org/wiki/List_of_tz_database_time_zones):"
        read selectedTimezone
done
	selectedTimezone="$selectedTimezone"
echo "Selected Timezone: $selectedTimezone"

#Add some PPAs to stay current
#apt-get install -y software-properties-common
#apt-add-repository ppa:ondrej/apache2 -y
apt-add-repository ppa:ondrej/nginx-mainline -y
apt-add-repository ppa:ondrej/php -y

#Install base packages
sudo apt-get update; sudo apt-get install -y build-essential curl nano wget lftp unzip bzip2 arj nomarch lzop htop openssl gcc git binutils libmcrypt4 libpcre3-dev make python3 python3-pip supervisor unattended-upgrades whois zsh imagemagick uuid-runtime net-tools

#Set the timezone to $selectedTimezone
ln -sf /usr/share/zoneinfo/$selectedTimezone /etc/localtime

sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx

sudo chown www-data:www-data /usr/share/nginx/html -R
sudo chown www-data:www-data /var/www/ -R

#Install PHP7.4 and common PHP packages
echo "Installing PHP 7.4..."

sudo apt install -y php7.4 php7.4-fpm php7.4-mysql php-common php7.4-cli php7.4-common php7.4-json php7.4-opcache php7.4-readline php7.4-mbstring php7.4-xml php7.4-gd php7.4-curl


sudo systemctl enable php7.4-fpm
sudo systemctl start php7.4-fpm


#Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

#Install and configure Memcached
apt-get install -y memcached
sed -i 's/-l 0.0.0.0/-l 127.0.0.1/' /etc/memcached.conf
systemctl restart memcached



#Update PHP CLI configuration
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.4/cli/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.4/cli/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.4/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = $selectedTimezone/" /etc/php/7.4/cli/php.ini

#Configure sessions directory permissions
chmod 733 /var/lib/php/sessions
chmod +t /var/lib/php/sessions


#Tweak PHP-FPM settings
sed -i "s/error_reporting = .*/error_reporting = E_ALL \& ~E_NOTICE \& ~E_STRICT \& ~E_DEPRECATED/" /etc/php/7.4/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = Off/" /etc/php/7.4/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.4/fpm/php.ini
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 256M/" /etc/php/7.4/fpm/php.ini
sed -i "s/post_max_size = .*/post_max_size = 256M/" /etc/php/7.4/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = $selectedTimezone/" /etc/php/7.4/fpm/php.ini

#Tune PHP-FPM pool settings

sed -i "s/;listen\.mode =.*/listen.mode = 0666/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/;request_terminate_timeout =.*/request_terminate_timeout = 60/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/pm\.max_children =.*/pm.max_children = 70/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/pm\.start_servers =.*/pm.start_servers = 20/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/pm\.min_spare_servers =.*/pm.min_spare_servers = 20/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/pm\.max_spare_servers =.*/pm.max_spare_servers = 35/" /etc/php/7.4/fpm/pool.d/www.conf
sed -i "s/;pm\.max_requests =.*/pm.max_requests = 500/" /etc/php/7.4/fpm/pool.d/www.conf

#Tweak Nginx settings

sed -i "s/worker_processes.*/worker_processes auto;/" /etc/nginx/nginx.conf
sed -i "s/# multi_accept.*/multi_accept on;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 128;/" /etc/nginx/nginx.conf
sed -i "s/# server_tokens off/server_tokens off/" /etc/nginx/nginx.conf

#Configure Gzip for Nginx

cat > /etc/nginx/conf.d/gzip.conf << EOF
gzip_comp_level 5;
gzip_min_length 256;
gzip_proxied any;
gzip_vary on;
gzip_types
application/atom+xml
application/javascript
application/json
application/rss+xml
application/vnd.ms-fontobject
application/x-web-app-manifest+json
application/xhtml+xml
application/xml
font/otf
font/ttf
image/svg+xml
image/x-icon
text/css
text/plain;
EOF

#Install latest NodeJS LTS
#curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
#apt-get install -y nodejs


#Install MySQL and set a strong root password

echo "Installing MySQL Server..."
sudo apt install -y mysql-server

#Secure your MySQL installation

MYSQL_ROOT_PASSWORD=$(date +%s|sha256sum|base64|head -c 128) #openssl rand -hex >
MODXDB_PASSWORD=$(date +%s+%m|sha256sum|base64|head -c 37) #openssl rand -hex 12
DB_OBF=$(date +%s+%m|sha256sum|base64|head -c 8)
MODXDB="modx_db_$DB_OBF"
MODXDBUSER="modx_dbu_$DB_OBF"

sudo mysql -uroot <<MYSQL_SCRIPT
UPDATE mysql.user SET Password=PASSWORD('$MYSQL_ROOT_PASSWORD') WHERE User='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo $MYSQL_ROOT_PASSWORD
echo $MODX_PASSWORD

#We will install phpMyAdmin using Composer as Ubuntu packages are no longer being maintained.
sudo mkdir -pv /var/www/
cd /var/www
sudo composer create-project phpmyadmin/phpmyadmin
sudo cp /var/www/phpmyadmin/config.sample.inc.php /var/www/phpmyadmin/config.inc.php
sudo mysql -u root -p $MYSQL_ROOT_PASSWORD < /var/www/phpmyadmin/sql/create_tables.sql
sudo sed -i "s/\$cfg\['blowfish_secret'\] = '';.*/\$cfg\['blowfish_secret'\] = '$(uuidgen)';/" /var/www/phpmyadmin/config.inc.php
sudo mkdir -pv /var/www/phpmyadmin/tmp; sudo chown www-data:www-data /var/www/phpmyadmin/tmp;

#Symlink phpMyAdmin, create logs dir and set permissions and ownership on /var/www
sudo ln -s /var/www/phpmyadmin/ /var/www/html/phpmyadmin; sudo mkdir -pv /var/www/logs; sudo chown -R www-data:www-data /var/www; sudo chmod -R g+rw /var/www;

#Create Nginx virtual host config

newdomain=""
domain=$1
rootPath=$2
sitesEnable='/etc/nginx/sites-enabled/'
sitesAvailable='/etc/nginx/sites-available/'
serverRoot='/var/www/'
domainRegex="^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$"

while [ "$domain" = "" ]
do
        echo "Please provide your PRIMARY domain (sub domain not required):"
        read domain
done

until [[ $domain =~ $domainRegex ]]
do
        echo "Enter valid domain:"
        read domain
done

echo "Enter sub domain:"
        read subdomain

if [ -z "$subdomain" ]
then
		newdomain="$domain"
echo $newdomain
else
	
		newdomain="${subdomain}.${domain}"

echo $newdomain
fi



if [ -e $newdomain ]; then
        echo "This domain already exists.\nPlease Try Another one"
        exit;
fi


if [ "$rootPath" = "" ]; then
        rootPath=$serverRoot$newdomain
fi

if ! [ -d $rootPath ]; then
        sudo mkdir -pv $rootPath
        sudo chmod 777 $rootPath
        if ! echo "<?php
// Show all information, defaults to INFO_ALL
phpinfo();
// Show just the module information.
// phpinfo(8) yields identical results.
phpinfo(INFO_MODULES);
?>" > $rootPath/index.php
        then
                echo "ERROR: Not able to write in file $rootPath/index.php. Please check permissions."
                exit;
        else
                echo "Added content to $rootPath/index.php"
        fi
fi

if ! [ -d $sitesEnable ]; then
        sudo mkdir -pv $sitesEnable
        sudo chmod 777 $sitesEnable
fi

if ! [ -d $sitesAvailable ]; then
        sudo mkdir -pv $sitesAvailable
        sudo chmod 777 $sitesAvailable
fi

configName=$newdomain

if ! echo "server {
    server_name $newdomain www.$newdomain;
    root /var/www/$newdomain;
    index index.html index.htm index.php;
    location / {
        try_files "'$uri'" "'$uri'"/ =404;
        if (!-e "'$request_filename'") {
                rewrite ^/(.*)$ /index.php?q="'$1'" last;
        }
    }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
     }

    location ~ /\.ht {
        deny all;
    }
}" > $sitesAvailable$newdomain
then
        echo "There is an ERROR create $configName file"
        exit;
else
        echo "New Virtual Host Created"
fi

#Symlink
sudo ln -s /etc/nginx/sites-available/$newdomain /etc/nginx/sites-enabled/

sudo rm /etc/nginx/sites-enabled/default

#Install Letsencrypt Certbot
sudo apt install -y python3-certbot-nginx

#Restart PHP-FPM and Nginx
sudo systemctl restart php7.4-fpm; sudo systemctl restart nginx;

echo 'LEMP Stack has been Installed
Now downloding latest MODX'
sleep 3

cd ~
wget -O modx.zip https://modx.com/download/direct?id=modx-2.8.1-pl-advanced.zip&0=abs
unzip modx.zip
mv modx-2.8.1-pl/setup /var/www/$newdomain/
mv modx-2.8.1-pl modx
MODXCOREPATH = /home/$USER/modx/core

sudo chown -R www-data:www-data /home/$USER/modx/core

echo "Downloaded MODX 2.8.1
Creating new database for $newdomain"
sleep 2

mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE $MODXDB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$MODXDBUSER'@'localhost' IDENTIFIED BY '$MODXDB_PASSWORD';
GRANT ALL PRIVILEGES ON $MODXDB.* TO '$MODXDBUSER'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

#copy the password to the root directory

echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD" > ~/mysql_info_$newdomain.txt
echo "$newdomain Info
------------------------
MODX DB Name: $MODXDB
MODX DB Username: $MODXDBUSER
MODX DB Password: $MODXDB_PASSWORD" > ~/modx_db_info_$newdomain.txt


echo "MODX Database Connection Details saved to ~/mysql_info_$newdomain.txt \n"
echo "MODX Core Path: $MODXCOREPATH \n\n";
echo "MODX Database Connection Details saved to ~/modx_db_info_$newdomain.txt \n"

#Set up logrotate for our Nginx logs
#Execute the following to create log rotation config for Nginx - this gives you 10 days of logs, rotated daily

cat > /etc/logrotate.d/vhost << EOF
/var/www/logs/*.log {
 rotate 10
 daily
 compress
 delaycompress
 sharedscripts
 
 postrotate
 systemctl reload nginx > /dev/null
 endscript
}
EOF

sudo chown www-data:www-data /var/log/nginx/*

#Setup unattended security upgrades
cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
