#!/bin/bash

# Run with sudo.

PRE="#### "
MSG_INSTALL_FAILED="Installation failed - exiting"

COLOR_RED="\033[0;31m"
COLOR_TERM="\033[0m"

err () {
	echo -e ${COLOR_RED}${MSG_INSTALL_FAILED}${COLOR_RESET}
	exit
}

echo "${PRE}Updating system"
apt-get update -y || err
echo
echo "${PRE}Upgrading system"
apt-get upgrade -y || err
echo

# All the packages to install.
declare -a pkgs=(
"vim"
"openssh-server" # Should be installed already, but just in case.
"net-tools"
"ufw"
"iptables"
"fail2ban"
"apache2"
"portsentry" # Opens up an interactive screen (->ENTER).
"bsd-mailx" # Not needed, but can be useful for testing (sending mails manually).
"postfix" # Opens up an interactive screen.
"mutt" # Mail client for the terminal for root.
)

MAIL_NAME="debian.lan"

# Set these values to be pre-answered for these packages,
# in order to skip interactive screens.
echo "postfix postfix/mailname string $MAIL_NAME" | debconf-set-selections
echo "postfix postfix/main_mailer_type string Local only" | debconf-set-selections
echo "postfix postfix/root_address string root@localhost" | debconf-set-selections
echo "postfix postfix/protocols select all" | debconf-set-selections

echo "portsentry portsentry/startup_conf_obsolete note" | debconf-set-selections
echo "portsentry portsentry/warn_no_block note" | debconf-set-selections

# Can use DEBIAN_FRONTEND=noninteractive here to skip interactive screens.
for p in ${pkgs[@]}; do
	echo "${PRE}Installing ${p}"
	apt-get install -y $p || err
	echo
done
