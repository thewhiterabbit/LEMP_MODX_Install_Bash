#!/bin/sh
# Author: Aaron K. Nall
set -e

# Get the username of the actual user
UN="$(who am i | awk '{print $1}')"

while [ -n "$1" ]; do # while loop starts
	case "$1" in
                -u)
                        USERNAME="$2"
                        shift
                        ;;

                -k)
                        KEY="$2"
                        shift
                        ;;

                -f)
                        FILE="true"
                        shift
                        ;;

                -fn)
                        FILENAME="$2"
                        shift
                        ;;

                *)
                        echo "Option $1 is invalid."
                        echo "Exiting"
                        exit 1
                        ;;
	esac
	shift
done

secure_user(){
    # Set the home directory in a variable
    if [[ "$UN" != "root" ]] || [[ "$USERNAME" != "" ]]; then
        if [[ "$USERNAME" != "" ]]; then
            HD="/home/$USERNAME"
        else
            HD="/home/$UN"
        fi
    else
        HD="/root"
    fi
    sudo mkdir -p $HD/.ssh
    if [[ "$FILE" = "" ]] && [[ "$FILENAME" = "" ]]; then
        while [[ "$KEY" = "" ]]
        do
            if [[ "$USERNAME" = "" ]]; then
                echo -n "Paste the SSH Key for $UN:"
            else
                echo -n "Paste the SSH Key for $USERNAME:"
            fi
            read -s KEY
        done
        sudo echo "$KEY" >| $HD/.ssh/authorized_keys
        echo "Private key was added to $HD/.ssh/authorized_keys"
        echo ""
    else
        if [[ "$FILENAME" != "" ]]; then
            sudo  mv $HD/LEMP_MODX_Install_Bash/$FILENAME $HD/.ssh/authorized_keys
            echo "$HD/LEMP_MODX_Install_Bash/$FILENAME was copied to $HD/.ssh/authorized_keys"
            echo ""
        else
            sudo  mv $HD/LEMP_MODX_Install_Bash/authorized_keys $HD/.ssh/authorized_keys
            echo "$HD/LEMP_MODX_Install_Bash/authorized_keys was copied to $HD/.ssh/authorized_keys"
            echo ""
        fi
    fi
}

secure_ssh(){
    sudo rm /etc/ssh/sshd_config
    sudo cp $HD/LEMP_MODX_Install_Bash/sshd_conf /etc/ssh/sshd_config

    echo "/etc/ssh/sshd_config was changed to reflect $HD/LEMP_MODX_Install_Bash/sshd_conf"
    echo ""
    sleep 1
}

if [[ "$UN" != "root" ]]; then
    if [[ ! $(sudo echo 0) ]]; then
        echo "Permission Denied!"
        echo ""
        exit;
    fi
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