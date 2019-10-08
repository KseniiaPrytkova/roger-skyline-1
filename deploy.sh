#!/bin/bash

# Run with sudo.

PRE_INFO="# "
PRE_ERR="! "

COLOR_INFO="\033[0;36m"
COLOR_NOTICE="\033[0;33m"
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

pr_notice () {
	echo -e "${COLOR_NOTICE}${PRE_INFO}${1}${COLOR_RESET}"
}

# Get all configurable values.
source deploy.conf

# Save the full path to this script.
SCRIPT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"

SRC_DIR="${SCRIPT_DIR}/src/"
# Check that the src/ directory exists.
[ ! -d "${SRC_DIR}" ] && err_exit "Source directory \"${SRC_DIR}\" does not exist"

pr "Updating system"
apt-get update -y || err_exit
echo
pr "Upgrading system"
apt-get upgrade -y || err_exit
echo

# All the packages to install.
declare -a pkgs=(
"vim"
"openssh-server" #Should be installed already, but just in case.
"net-tools"
"ufw"
"iptables"
"fail2ban"
"apache2"
"portsentry" # Opens up an interactive screen (->ENTER).
"bsd-mailx" # Not needed, but can be useful for testing (sending mails manually).
"postfix" # Opens up an interactive screen.
"mutt" # Terminal mail client for root.
)

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
chmod +w interfaces
echo "# The primary network interface" >> interfaces
echo "auto enp0s3" >> interfaces
cd /etc/network/interfaces.d/
touch enp0s3
echo "iface enp0s3 inet static" >> enp0s3
echo "    address ${IP_ADDRESS}" >> enp0s3
echo "    netmask ${NETMASK}" >> enp0s3
service networking restart || err "Failed to restart the networking service"
echo

pr "Printing ifconfig"
ifconfig || err "Failed to start ifconfig"
echo

pr "Printing the SSHD service process"
ps -ef | grep sshd
echo

pr "Setting SSH port number to ${SSH_PORT}"
cd /etc/ssh/
TMP=/tmp/roger_skyline_sshd_config.tmp
cat sshd_config > $TMP
sed -i "/^[[:blank:]]*#[[:blank:]]*Port[[:blank:]]*[0-9]*[[:blank:]]*$/c\Port ${SSH_PORT}" sshd_config
diff sshd_config $TMP >/dev/null && err "Failed to change the SSH port - change the port (\"Port ${SSH_PORT}\") manually in /etc/ssh/sshd_config"
rm $TMP
echo

pr "Disable SSH login for the root user"
cd /etc/ssh/
cat sshd_config > $TMP
sed -i "/^[[:blank:]]*#[[:blank:]]*PermitRootLogin[[:blank:]]*[[:graph:]]*[[:blank:]]*$/c\PermitRootLogin no" sshd_config
diff sshd_config $TMP >/dev/null && err "Failed to disable SSH root login - change it (\"PermitRootLogin no\") manually in /etc/ssh/sshd_config"
rm $TMP
echo

pr "Restarting the SSHD service"
sudo service sshd restart || err "Restarting the SSHD service failed"
echo

pr "Printing the status of SSH"
systemctl status ssh || err "Failed to check the status of SSH"
echo
pr_notice "Don't forget to setup SSH public key authentication on the host side!"
echo

pr "Enabling ufw"
ufw enable || err_exit "Failed to enable ufw"
echo

declare -a ufw_allow=(
"${SSH_PORT}/tcp (SSH)"
"80/tcp (HTTP)"
"443 (HTTPS)"
)
for e in "${ufw_allow[@]}"; do
	pr "Make ufw allow ${e}"
	ufw allow `echo ${e} | awk '{print $1}'` || err_exit "Failed to make ufw allow ${e}"
	echo
done

pr "Printing the status of ufw"
ufw status
echo

pr "Deploying fail2ban src files"
cp ${SRC_DIR}/jail.local /etc/fail2ban || err_exit "Failed to copy \"jail.local\""
cp ${SRC_DIR}/http-get-dos.conf /etc/fail2ban/filter.d/ || err_exit "Failed to copy \"http-get-dos.conf\""
echo

pr "Restarting ufw and starting fail2ban"
ufw reload || err "Failed to restart ufw"
service fail2ban start || err_exit "Failed to start fail2ban"
echo

pr "Printing the status of fail2ban"
fail2ban-client status
echo

pr "Deploying portsentry src files"
cp ${SRC_DIR}/portsentry /etc/default/ || err_exit "Failed to copy \"portsentry\""
cp ${SRC_DIR}/portsentry.conf /etc/portsentry/ || err_exit "Failed to copy \"portsentry.conf\""
echo

pr "Starting portsentry (it will now begin to block the port scans)"
/etc/init.d/portsentry start || err_exit "Failed to start portsentry"
echo

declare -a services_to_disable=(
"bluetooth"
"console-setup"
"keyboard-setup"
)
for e in "${services_to_disable[@]}"; do
	pr "Disable service ${e}"
	systemctl disable ${e}.service || err "Failed to disable the ${e} service"
	echo
done

# Deploy cron jobs to the /home/[user who called sudo]/cronjobs/.
TMP="/home/${SUDO_USER}/cronjobs"
declare -a cronjobs=(
"i_will_update.sh"
"i_will_monitor_cron.sh"
)

pr "Deploying cron jobs to ${TMP}/"
sudo -u $SUDO_USER mkdir $TMP >/dev/null
for e in "${cronjobs[@]}"; do
	sudo -u $SUDO_USER cp "${SRC_DIR}/${e}" "${TMP}" || err_exit "Failed to copy \"${e}\""
	sudo chmod u+x "${TMP}/${e}"
done
echo

DIR_CRONJOBS="${TMP}"
for e in "${cronjobs[@]}"; do
	pr "Adding crontab rules for ${e}"
	TMP=/tmp/roger_skyline_crontab.tmp
	sudo -u $SUDO_USER crontab -l > $TMP

	if [ "${e}" == "i_will_update.sh" ]; then
		echo "@reboot ${DIR_CRONJOBS}/${e} &" >> $TMP
		echo "0 4 * * MON ${DIR_CRONJOBS}/${e} &" >> $TMP
	elif [ "${e}" == "i_will_monitor_cron.sh" ]; then
		echo "* * * * * ${DIR_CRONJOBS}/${e} &" >> $TMP
	fi

	sudo -u $SUDO_USER crontab $TMP || err_exit "Failed to add ${e} cron job"
	echo
done
rm $TMP

pr "Set root:root in etc/aliases"
sed -i "/^[[:blank:]]*root:[[:blank:]]*[[:graph:]]*[[:blank:]]*$/c\root:root" /etc/aliases
echo

pr "Reload aliases"
newaliases || err_exit "Failed reloading aliases"
echo

pr "Setting the home mailbox and restarting postfix"
postconf -e "home_mailbox = ${MAIL_HOME_MAILBOX}"
postfix reload || err_exit "Failed to restart postfix"
echo

pr "Deploying mutt src file" 
cp ${SRC_DIR}/.muttrc /root || err_exit "Failed to copy .muttrc"
echo

pr "Generate SSL self-signed key and certificate"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
	-subj "/C=UA/ST=/L=/O=/OU=/CN=${IP_ADDRESS}" \
	-keyout /etc/ssl/private/apache-selfsigned.key \
	-out /etc/ssl/certs/apache-selfsigned.crt \
	|| err_exit "Failed to generate SSL self-signed key and certificate"
echo

pr "Deploying SSL params src file"
cp ${SRC_DIR}/ssl-params.conf /etc/apache2/conf-available/ || err_exit "Failed to copy ssl-params.conf"
echo

pr "Deploying default SSL conf src file"
cp ${SRC_DIR}/default-ssl.conf /etc/apache2/sites-available/ || err_exit "Failed to copy default-ssl.conf"
echo

pr "Deploying 000-default.conf src file"
cp ${SRC_DIR}/000-default.conf /etc/apache2/sites-available/ || err_exit "Failed to copy 000-default.conf"
echo

pr "Deploy the login page"
cp ${SRC_DIR}/login.html /var/www/html/ || err_exit "Failed to copy login.html"
mkdir /var/www/html/img/ >/dev/null
cp ${SRC_DIR}/img/you.png /var/www/html/img/ || err_exit "Failed to copy you.png"
echo
