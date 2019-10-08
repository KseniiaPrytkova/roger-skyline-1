#!/bin/bash

# Run with sudo.

PRE_INFO="#### "
PRE_ERR="!!!! "

COLOR_INFO="\033[0;35m"
COLOR_ERR="\033[0;31m"
COLOR_RESET="\033[0m"

err () {
	echo -e ${COLOR_ERR}${PRE_ERR}${1}${COLOR_RESET}	
}

err_exit () {
	err "${1} - exiting"
	exit
}

pr () {
	echo -e "${COLOR_INFO}${PRE_INFO}${1}${COLOR_RESET}"
}

pr "Updating system"
#apt-get update -y || err_exit
echo
pr "Upgrading system"
#apt-get upgrade -y || err_exit
echo

# All the packages to install.
declare -a pkgs=(
#"vim"
#"openssh-server" #Should be installed already, but just in case.
#"net-tools"
#"ufw"
#"iptables"
#"fail2ban"
#"apache2"
#"portsentry" # Opens up an interactive screen (->ENTER).
#"bsd-mailx" # Not needed, but can be useful for testing (sending mails manually).
#"postfix" # Opens up an interactive screen.
#"mutt" # Terminal mail client for root.
)

MAIL_NAME="debian.lan"
IP_ADDRESS="192.168.10.42"
NETMASK="255.255.255.252"

# Set these values to be pre-answered for these packages,
# in order to skip the interactive screen.
echo "postfix postfix/mailname string $MAIL_NAME" | debconf-set-selections
echo "postfix postfix/main_mailer_type string Local only" | debconf-set-selections
echo "postfix postfix/root_address string root@localhost" | debconf-set-selections
echo "postfix postfix/protocols select ipv6" | debconf-set-selections
echo "portsentry portsentry/startup_conf_obsolete note" | debconf-set-selections	
echo "portsentry portsentry/warn_no_block note" | debconf-set-selections

# Use DEBIAN_FRONTEND=noninteractive here to skip interactive screens.
for p in ${pkgs[@]}; do
	pr "Installing ${p}"
	apt-get install -y $p || err_exit "Failed to install ${p}"
	echo
done

pr "Setting up static IP ${IP_ADDRESS} with netmask ${NETMASK}"
cd /etc/network/
#chmod +w interfaces
#echo "# The primary network interface" >> interfaces
#echo "auto enp0s3" >> interfaces
#cd /etc/network/interfaces.d/
#touch enp0s3
#echo "iface enp0s3 inet static" >> enp0s3
#echo "    address ${IP_ADDRESS}" >> enp0s3
#echo "    netmask ${NETMASK}" >> enp0s3
#service networking restart || err "Failed to restart the networking service"
echo

pr "Checking ifconfig"
ifconfig || err "Failed to start ifconfig"
echo

pr "Checking the status of the SSH server"
ps -ef | grep sshd
echo

SSH_PORT=50000

pr "Setting SSH port number to ${SSH_PORT}"
cd /etc/ssh/
TMPFILE=/tmp/sshd_config_roger_skyline.tmp
cat sshd_config > $TMPFILE
sed -i "/^[[:blank:]]*#[[:blank:]]*Port[[:blank:]]*[0-9]*[[:blank:]]*$/c\Port ${SSH_PORT}" sshd_config
diff sshd_config $TMPFILE >/dev/null && err "Failed to change the SSH port - change the port (\"Port [n]\") manually in /etc/ssh/sshd_config"
rm $TMPFILE
echo















