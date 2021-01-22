#!/bin/sh
# Author: Aaron K. Nall
set -e

secure_user(){
    while [[ "$KEY" = "" ]]
    do
        echo -n "Paste the SSH Private Key for $USER:"
        read KEY
    done

    sudo echo
    "$KEY"
    >> ~.ssh/authorized_keys

    echo "Private key was added to ~.ssh/authorized_keys"
    echo ""
}

secure_ssh(){
    sudo rm /etc/ssh/sshd_config
    sudo cp ~/LEMP_MODX_Install_Bash/sshd_conf /etc/ssh/sshd_config

    echo "/etc/ssh/sshd_config was changed to reflect ~/LEMP_MODX_Install_Bash/sshd_conf"
    echo ""
    sleep 1
}

if [[ "$USER" != "root" ]]; then
    if [[ ! $(sudo echo 0) ]]; then exit; fi
    secure_ssh
    secure_user
    sudo service ssh reload
else
    secure_ssh
    secure_user
    service ssh reload
fi

echo "Your changes have been applied successfully."
echo "The ssh servive has been reloaded."
echo ""