#!/bin/sh
# Author: Aaron K. Nall
set -e
if [[ ! $(sudo echo 0) ]]; then exit; fi
echo ""
echo "Welcome to the Ubuntu/Debian LEMP Stack Installer."
echo "This script will install a full LEMP Stack on this system."
echo "The www-data group will become $USER's primay group."
echo "This group assignment will allow $USER to manipulate web server files without interuptions to file access for the web server."
echo "It is highly reccomended that this script be ran by a user account that will be responsible for maintaining, editing, and uploading files for the web server."
echo "Do not run this script as the root system user!"
echo "Would you like to continue?"

confirmInstall(){
        while [[ "$confirm" = "" ]]
        do
                echo -n "[y = continue | n = exit]:"
                read confirm
        done
}

confirmInstall

while [[ "$validConfirm" = "" ]]
do 
        case "$confirm" in
                y | Y)
                        validConfirm="true"
                        echo "You will be asked for input, please be patient."
                        sleep 5
                        ;;
                n | N)
                        echo "Exiting Ubuntu/Debian LEMP Stack Installer."
                        exit
                        ;;
                *)
                        confirm=""
                        echo "Invalid input detected."
                        echo "Would you like to continue?"
                        confirmInstall
        esac
done

# Add current user to the www-data group as primary
UN="$(who am i | awk '{print $1}')"
sudo usermod -aG www-data $UN
wait
sudo usermod -g www-data $UN
wait

# Update apt
sudo apt-get update
wait
sudo apt-get upgrade -y
wait

# Instal firewall & security basics
sudo apt-get install -y fail2ban ufw
wait

while [ "$selectedTimezone" = "" ]
do
        echo "Please enter your timezone as TZ database name"
        echo "  Reference https://en.wikipedia.org/wiki/List_of_tz_database_time_zones):"
        read selectedTimezone
done
echo "Selected Timezone: $selectedTimezone"
sleep 5

#Install base packages
sudo apt-get install -y build-essential curl nano wget lftp unzip bzip2 arj nomarch lzop htop openssl gcc git binutils
wait
sudo apt-get install -y libmcrypt4 libpcre3-dev make python3 python3-pip supervisor unattended-upgrades whois zsh imagemagick uuid-runtime net-tools
wait

#Set the timezone to $selectedTimezone
sudo ln -sf /usr/share/zoneinfo/$selectedTimezone /etc/localtime
wait
sudo apt install nginx -y
wait
sudo systemctl enable nginx
wait
sudo systemctl start nginx
wait

#Install PHP7.4 and common PHP packages
echo "Installing PHP..."
sudo apt install -y php-fpm php-mysql php-json php-mbstring
wait
sudo systemctl enable php7.4-fpm
wait
sudo systemctl start php7.4-fpm
wait

#Install and configure Memcached
sudo apt-get install -y memcached
wait
sudo sed -i 's/-l 0.0.0.0/-l 127.0.0.1/' /etc/memcached.conf
wait
sudo systemctl restart memcached
wait

#Update PHP CLI configuration
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.4/cli/php.ini
wait
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.4/cli/php.ini
wait
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.4/cli/php.ini
wait
sudo sed -i "s/;date.timezone.*/date.timezone = $selectedTimezone/" /etc/php/7.4/cli/php.ini
wait

#Configure sessions directory permissions
sudo chmod 733 /var/lib/php/sessions
wait
sudo chmod +t /var/lib/php/sessions
wait

#Tweak PHP-FPM settings
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL \& ~E_NOTICE \& ~E_STRICT \& ~E_DEPRECATED/" /etc/php/7.4/fpm/php.ini
wait
sudo sed -i "s/display_errors = .*/display_errors = Off/" /etc/php/7.4/fpm/php.ini
wait
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.4/fpm/php.ini
wait
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 256M/" /etc/php/7.4/fpm/php.ini
wait
sudo sed -i "s/post_max_size = .*/post_max_size = 256M/" /etc/php/7.4/fpm/php.ini
wait
sudo sed -i "s/;date.timezone.*/date.timezone = $selectedTimezone/" /etc/php/7.4/fpm/php.ini
wait

#Tune PHP-FPM pool settings
sudo sed -i "s/;listen\.mode =.*/listen.mode = 0666/" /etc/php/7.4/fpm/pool.d/www.conf
wait
sudo sed -i "s/;request_terminate_timeout =.*/request_terminate_timeout = 60/" /etc/php/7.4/fpm/pool.d/www.conf
wait
sudo sed -i "s/pm\.max_children =.*/pm.max_children = 70/" /etc/php/7.4/fpm/pool.d/www.conf
wait
sudo sed -i "s/pm\.start_servers =.*/pm.start_servers = 20/" /etc/php/7.4/fpm/pool.d/www.conf
wait
sudo sed -i "s/pm\.min_spare_servers =.*/pm.min_spare_servers = 20/" /etc/php/7.4/fpm/pool.d/www.conf
wait
sudo sed -i "s/pm\.max_spare_servers =.*/pm.max_spare_servers = 35/" /etc/php/7.4/fpm/pool.d/www.conf
wait
sudo sed -i "s/;pm\.max_requests =.*/pm.max_requests = 500/" /etc/php/7.4/fpm/pool.d/www.conf
wait

#Tweak Nginx settings
sudo sed -i "s/worker_processes.*/worker_processes auto;/" /etc/nginx/nginx.conf
wait
sudo sed -i "s/# multi_accept.*/multi_accept on;/" /etc/nginx/nginx.conf
wait
sudo sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 128;/" /etc/nginx/nginx.conf
wait
sudo sed -i "s/# server_tokens off/server_tokens off/" /etc/nginx/nginx.conf
wait

#Configure Gzip for Nginx
sudo cat > /etc/nginx/conf.d/gzip.conf << EOF
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
wait

#Install latest NodeJS LTS
#curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
#apt-get install -y nodejs

#Install MySQL and set a strong root password
echo "Installing MySQL Server..."
sudo apt install -y mysql-server
wait

#Secure your MySQL installation
MYSQL_ROOT_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 128 | head -n 1)
MODX_DB_PASSWORD=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 64 | head -n 1)
DB_OBF=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
DB_OBF2=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
DB_OBF3=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
MODX_DB="modx_db_$DB_OBF"
MODX_DB_USER="modx_dbu_$DB_OBF"
PMA_DB_USER="pma_$DB_OBF2"
PMA_DB_PASS=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!#$%&()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 128 | head -n 1)
DB_ADMIN="dba_$DB_OBF3"
DB_ADMIN_PASS=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 128 | head -n 1)
sudo mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE $MODX_DB DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$MODX_DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MODX_DB_PASSWORD';
GRANT ALL PRIVILEGES ON $MODX_DB.* TO '$MODX_DB_USER'@'localhost' WITH GRANT OPTION;
CREATE USER '$PMA_DB_USER'@'localhost' IDENTIFIED WITH mysql_native_password BY '$PMA_DB_PASS';
GRANT ALL ON phpmyadmin.* TO '$PMA_DB_USER'@'localhost' WITH GRANT OPTION;
CREATE USER '$DB_ADMIN'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ADMIN_PASS';
GRANT ALL ON *.* TO '$DB_ADMIN'@'localhost' WITH GRANT OPTION;
MYSQL_SCRIPT
wait

# Make sure the current directory is home
cd /home/$UN
# The phpMyAdmin available in the Ubuntu OS repository for Ubuntu 20.04 may be old. So, we will download the latest version of phpMyAdmin from the official website.
wget https://files.phpmyadmin.net/phpMyAdmin/5.0.4/phpMyAdmin-5.0.4-all-languages.tar.gz
wait
tar -zxvf phpMyAdmin-5.0.4-all-languages.tar.gz
wait
sudo mv phpMyAdmin-5.0.4-all-languages /usr/share/phpMyAdmin
wait

# Create blowfish key for config file
BLOWFISH=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!#$%&()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 32 | head -n 1)
sudo sed -i "s/{blowfish}/$BLOWFISH/" /home/$UN/LEMP_MODX_Install_Bash/config.inc.php
wait
sudo sed -i "s/{controluser}/$PMA_DB_USER/" /home/$UN/LEMP_MODX_Install_Bash/config.inc.php
wait
sudo sed -i "s/{controlpass}/$PMA_DB_PASS/" /home/$UN/LEMP_MODX_Install_Bash/config.inc.php
wait
sudo rm /usr/share/phpMyAdmin/config.inc.php
wait
sudo cp /home/$UN/LEMP_MODX_Install_Bash/config.inc.php /usr/share/phpMyAdmin/
wait

# Import the create_tables.sql to create tables for phpMyAdmin
sudo mysql < /usr/share/phpMyAdmin/sql/create_tables.sql -u root
wait

# Secure MySQL installation
sudo mysql -uroot <<MYSQL_SCRIPT
USE mysql;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
INSTALL COMPONENT 'file://component_validate_password';
SET GLOBAL validate_password_policy=STRONG;
FLUSH PRIVILEGES;
MYSQL_SCRIPT
wait

#Create Nginx virtual host config
newdomain=""
sitesEnabled='/etc/nginx/sites-enabled'
sitesAvailable='/etc/nginx/sites-available'
webRoot='/var/www'
domainRegex="^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9]\.[a-zA-Z]{2,}$"

# Ask the user for the domain
acquireDomain(){
        while [ "$OWNER_IP" = "" ]
        do
                echo -n "Enter the IP you want to have admin remote access:"
                read OWNER_IP
        done
        echo ""
        while [ "$domain" = "" ]
        do
                echo -n "Enter your host domain:"
                read domain
        done
        echo ""
        until [[ $domain =~ $domainRegex ]]
        do
                echo -n "Enter a valid domain:"
                read domain
        done
        echo ""
        echo -n "Enter the sub domain (optional):"
                read subdomain
        if [ -z "$subdomain" ]
        then
                newdomain="$domain"
        else
                newdomain="${subdomain}.${domain}"
        fi
        echo ""
}
acquireDomain

# SSH, HTTP and HTTPS
sudo ufw default deny incoming
wait
sudo ufw default allow outgoing
wait
sudo ufw allow 'OpenSSH'
wait
sudo ufw allow from $OWNER_IP
wait

# Skip the following 3 lines if you do not plan on using unsecure FTP
#ufw allow 21
#ufw allow 50000:50099/tcp
#ufw allow out 20/tcp

# Activate UFW
sudo ufw --force enable
wait

# Show the new ufw status
UFWS=$(ufw status)
wait
echo "$UFWS"
sleep 5

# Check the entered domain for existance
while [ -e $newdomain ]
do
        echo "This domain already exists, please choose a different domain."
        acquireDomain
done
echo "Using $newdomain for this LEMP installation"
sleep 5

# Check directories for existance
if ! [ -d $sitesEnabled ]; then
        sudo mkdir -pv $sitesEnabled
        wait
        sudo chmod 777 $sitesEnabled
        wait
fi
if ! [ -d $sitesAvailable ]; then
        sudo mkdir -pv $sitesAvailable
        wait
        sudo chmod 777 $sitesAvailable
        wait
fi

# Create the domain server block
sudo sed -i "s/{domain}/$newdomain/" /home/$UN/LEMP_MODX_Install_Bash/server_block
wait
SA_PATH="$sitesAvailable/$newdomain"
sudo cp /home/$UN/LEMP_MODX_Install_Bash/server_block $SA_PATH
wait

# Create the PhpMyAdmin hostname
PMAOBF=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | fold -w 8 | head -n 1)
PMA_SUB="pma_$PMAOBF"
PMA_HOST="$PMA_SUB.$newdomain"

# Create the PhpMyAdmin server block
STR="{PMAHOST}"
sudo sed -i "s/$STR/$PMA_HOST/" /home/$UN/LEMP_MODX_Install_Bash/pma_server_block
wait
STR2="{PMASUB}"
sudo sed -i "s/$STR2/$PMA_SUB/" /home/$UN/LEMP_MODX_Install_Bash/pma_server_block
wait
sudo cp /home/$UN/LEMP_MODX_Install_Bash/pma_server_block /etc/nginx/conf.d/phpMyAdmin.conf
wait

# Symlink Server Block
sudo ln -s /etc/nginx/sites-available/$newdomain /etc/nginx/sites-enabled/
wait

# Remove the default server block
sudo rm /etc/nginx/sites-enabled/default
wait

#Install Letsencrypt Certbot
sudo apt install -y python3-certbot-nginx
wait

# Keep the user informed
echo "The LEMP Stack has been Installed"
echo ""
sleep 5
echo "Now downloding latest MODX..."

# Make sure the current directory is home
cd /home/$UN

# Download MODX
wget -O modx.zip https://modx.com/download/direct?id=modx-2.8.1-pl-advanced.zip&0=abs
wait
unzip modx.zip
wait
sudo mkdir /var/www/$newdomain
wait
sudo mv /home/$UN/modx-2.8.1-pl/setup /var/www/$newdomain/
wait
sudo mv /home/$UN/modx-2.8.1-pl /home/$UN/modx
wait
MODXCOREPATH="/home/$UN/modx/core"
sudo chown -R www-data:www-data /home/$UN/modx/core
wait
sudo mkdir /usr/share/phpMyAdmin/tmp
wait
sudo chmod 777 /usr/share/phpMyAdmin/tmp
wait
sudo ln -sf /usr/share/phpmyadmin /var/www/phpMyAdmin
wait
sudo chown -R www-data:www-data /usr/share/phpMyAdmin
wait
sudo chown -R www-data:www-data /var/www/phpMyAdmin
wait

#Restart PHP-FPM and Nginx
sudo systemctl restart nginx
wait
sudo systemctl restart php7.4-fpm
wait

#Setup logrotate for our Nginx logs
#Execute the following to create log rotation config for Nginx - this gives you 10 days of logs, rotated daily
sudo cat > /etc/logrotate.d/vhost << EOF
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
wait
sudo chown -R www-data:www-data /var/log/nginx/*
wait
sudo chown -R www-data:www-data /var/www
wait

#Setup unattended security upgrades
sudo cat > /etc/apt/apt.conf.d/10periodic << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
wait

# Keep the user informed
echo "MODX 2.8.1 download complete"
echo ""
sleep 5
echo "Creating database for $newdomain..."
sleep 2

# Write the setup information to files
FP="/home/$UN/mysql_info_$newdomain.txt"
sudo echo "MySQL root Password: $MYSQL_ROOT_PASSWORD" > $FP
FP2="/home/$UN/modx_db_info_$newdomain.txt"
wait
sudo echo "$newdomain Info
------------------------
MODX DB Name: $MODX_DB
MODX DB Username: $MODX_DB_USER
MODX DB Password: $MODX_DB_PASSWORD" > $FP2
wait

# Display the setup information to the user
echo "Open your browser and navigate to $newdomain/setup/"
sleep 1
echo ""
echo "Use the information below to complete the MODX setup process..."
sleep 1
echo "$newdomain Info"
echo "------------------------"
sleep 1
echo "MODX DB Name: $MODX_DB"
sleep 1
echo "MODX DB Username: $MODX_DB_USER"
sleep 1
echo "MODX DB Password: $MODX_DB_PASSWORD"
sleep 1
echo "MODX Core Path: $MODXCOREPATH";
sleep 1
echo "MODX Database Connection Details saved to /home/$UN/modx_db_info_$newdomain.txt"
sleep 1
echo "Your MySQL root Password is: $MYSQL_ROOT_PASSWORD"
echo "Save this in a safe place or download the following file..."
echo "/home/$UN/mysql_info_$newdomain.txt"
echo ""
sleep 1
echo "Access PhpMyAdmin at: $PMA_HOST"
echo "You will need to create a DNS record for this subdomain."
echo "PhpMyAdmin can also be accessed at: $newdomain/$PMA_SUB."
echo ""
sleep 1
echo "Database Admin Info"
echo "------------------------"
echo "Username: $DB_ADMIN"
echo "Password: $DB_ADMIN_PASS"
echo ""
echo "Use these credentials to administer the database through PhpMyAdmin."