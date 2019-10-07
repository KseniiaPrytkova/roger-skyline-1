# roger-skyline-1

## Summary <a id="summary"></a>

- [V.1 VM Part](#VMPart)
- [V.2 Network and Security Part](#NetworkSecurityPart)
	- [Install and configure `sudo`](#sudo)
	- [Configure a static IP on Virtual Machine](#StaticIP)
	- [Change the default port of the SSH service](#SSHDefault)
	- [Setup SSH Public Key Authentication](#SSHKeySetup)
	- [Set up Firewall with UFW (Uncomplicated Firewall)](#UFW)
	- [Set a DOS (Denial Of Service Attack) protection on open ports of VM(server) with `fail2ban`](#DOS)
	- [Set a protection against scans of open ports with `portsentry`](#StopScan)
	- [Stop services that are not needed](#StopServices)
	- [Update packages regularly](#UpdatePackages)
	- [Monitor changes of the `/etc/crontab` periodically](#UpdateCron)
		- [Set up local mail delivery with Postfix and Mutt](#SetUpMail)
- [V.2 Web Part](#WebPart)
- [V.3 Deployment Part](#DepPart)

## V.1 VM Part <a id="VMPart"></a>
***hypervisor:*** VirtualBox; ***Linux OS:*** Debian(64-bit); size of the hard disk is 8.00 GB(VDI, fixed size);
Next you should run the virtual machine and specify the image of the OS - i downloaded `debian-10.1.0-amd64-netinst.iso` from https://www.debian.org/distrib/.
![specify_img](img/specify_img.png)

Then you need to set up you Debian, process is quite simple, but i'll pay some attention on `Partition disks` part. Choose `Partition method` as `manual` and next choose:
![partition_1](img/partition_1.png)

then:

![partition_2](img/partition_2.png)

go for `Create a new partition` and specify new partition size:

![partition_3](img/partition_3.png)

choose type and location (i choosed beggining); choose file system(i went for `/ - the root file system`):

![partition_4](img/partition_4.png)

i created 2 partitions: one `primary` with mout point on the `/ (root)` of OS and with 4.2GB capacity, second `logical` with mount point on the `/home` dir and 4.4GB of space:

![partition_5](img/partition_5.png)

then go for `Finish partitioning and write changes to disk`.
Finally, i did not install desktop envirinment; GRUB i accepted.
## V.2 Network and Security Part <a id="NetworkSecurityPart"></a>
### You must create a non-root user to connect to the machine and work.
Non-root login was created while setting up the OS. Just log in.
### Use sudo, with this user, to be able to perform operation requiring special rights. <a id="sudo"></a>
First, we need to install `sudo`, what we can do only as root, so:
```
$ su
$ apt-get update -y && apt-get upgrade -y
$ apt-get install sudo vim -y
```
exit root mode:
```
$ exit
```
but now, if we'll try to use `sudo`, the OS will respond: `kseniia is not in the sudoers file. This incident will be reported`. That means we need to open `/etc/sudoers` file (again under the root). Don't forget to check rights on the file (must be writible!).
```
$ pwd
/etc
$ chmod +w sudoers
$ vim sudoers
```
add `username ALL=(ALL:ALL) ALL` to `# User priviliege specification` section:

![sudoers](img/sudoers.png)

### We don’t want you to use the DHCP service of your machine. You’ve got to configure it to have a static IP and a Netmask in \30. <a id="StaticIP"></a>
First, go to VirtualBox settings -> Network -> in `Attached to` subsection change ***NAT*** on ***Bridged Adapter***; i like using `ifconfig`, that's why i'll install it (it's always possible to use `ip`):
```
$ sudo apt-get install net-tools
$ sudo ifconfig
```
As we see, the name of our `bridged adapter` is ***enp0s3***. Let's setup ***static ip*** (not dynamical) - check [How to setup a Static IP address on Debian Linux](https://linuxconfig.org/how-to-setup-a-static-ip-address-on-debian-linux) and [Network of VirtualBox instances with static IP addresses and Internet access](https://www.codesandnotes.be/2018/10/16/network-of-virtualbox-instances-with-static-ip-addresses-and-internet-access/).

***1.*** We should modify `/etc/network/interfaces` network config file (don't forget to`$ sudo chmod +w interfaces`):

![interfaces](img/interfaces.png)

[Файл настройки сети /etc/network/interfaces)](https://notessysadmin.com/fajl-nastrojki-seti)

***2.*** Define your network interfaces separately within `/etc/network/interfaces.d/` directory. During the networking daemon initiation the `/etc/network/interfaces.d/` directory is searched for network interface configurations. Any found network configuration is included as part of the `/etc/network/interfaces`. So:
```
$ cd interfaces.d
$ sudo touch enp0s3
$ sudo vim enp0s3
```

![enp0s3](img/enp0s3.png)

next restart the network service:
```
$ sudo service networking restart
```
run `ifconfig` to see the result:

![ifconfig_res](img/ifconfig_res.png)

### You have to change the default port of the SSH service by the one of your choice. SSH access HAS TO be done with publickeys. SSH root access SHOULD NOT be allowed directly, but with a user who can be root. <a id="SSHDefault"></a>
let's check status of ssh server:
```
$ ps -ef | grep sshd
```
next we need to change `/etc/ssh/sshd_config` file [Changing the SSH Port for Your Linux Server](https://se.godaddy.com/help/changing-the-ssh-port-for-your-linux-server-7306):
```
$ sudo vim /etc/ssh/sshd_config
```
and change the line `# Port 22` - remove `#` and type choosen port number; you can use range of numbers from 49152 to 65535 (accordingly to IANA); i chosed port number ***50000***; restart the sshd service:
```
$ sudo service sshd restart
```
login with ssh and check status of our connection:
```
$ sudo ssh kseniia@192.168.10.42 -p 50000
$ sudo systemctl status ssh
```
#### Finaly <a id="SSHKeySetup"></a>
let's test the ssh conection from host. We need to setup SSH public key authentication [Setup SSH Public Key Authentication](https://www.cyberciti.biz/faq/ubuntu-18-04-setup-ssh-public-key-authentication/); OS of my host is macOS Sierra; run from ***your host's terminal***:

```
# host terminal

$ ssh-keygen -t rsa
```
to connect 2 interfaces they must be in one subnet; for the ip on VM allowed 2 ip adresses (because we use netmask /30): 192.168.10.42(for VM, ip addr that we set) and 192.168.10.41(for host); we need to set up the ip addr to the host: ***System Preferences*** -> ***Network*** -> ***Advanced*** -> ***TCP/IP*** -> ***Select Manual*** -> ***Enter the new ip addr (192.168.10.41)*** -> ***Apply***; you can also try to change ip via `ifconfig`. Now we can connect to our server(VM):
```
# host terminal

$ ping 192.168.10.42
$ ssh kseniia@192.168.10.42 -p 50000
$ exit (logout from the ssh)
```
last step is [HOW DO I DISABLE SSH LOGIN FOR THE ROOT USER?](https://mediatemple.net/community/products/dv/204643810/how-do-i-disable-ssh-login-for-the-root-user). To disable root SSH login, edit `/etc/ssh/sshd_config`, by changing line `# PermitRootLogin yes` to `PermitRootLogin no`. Restart the SSH daemon: `sudo service sshd restart`. And read [Why should I really disable root ssh login?](https://superuser.com/questions/1006267/why-should-i-really-disable-root-ssh-login)

### You have to set the rules of your firewall on your server only with the services used outside the VM. <a id="UFW"></a>
I'll set up a Firewall with the help of ***UFW (Uncomplicated Firewall)***, whisch is an interface to ***iptables*** that is geared towards simplifying the process of configuring a firewall. 
> by the way - couple of times i had the problem with `upd-get install` - for some reason my VM could nor reach the server with package, also `ping` did not work; ***SOLUTION*** for problem `apt-get update fails to fetch files, “Temporary failure resolving …” error`: open `/etc/resolv.conf` file on your host, copy the `namserver` value (`nameserver fdb8:8db8:81bd::1`) and modify `/etc/resolv.conf` on VM with this value
```
$ sudo apt-get install ufw
$ sudo ufw status
$ sudo ufw enable
```
we can allow or deny by service name since ufw reads from `/etc/services`. To see get a list of services:
```
$ less /etc/services
```
let's allow services, that we need:
```
# allow ssh
$ sudo ufw allow 50000/tcp
# allow http
$ sudo ufw allow 80/tcp
# allow https
$ sudo ufw allow 443
```
now let's check status of our firewall:

![ufw_status](img/ufw_status.png)

here are some usefull links:
- [Linux firewalls: What you need to know about iptables and firewalld](https://opensource.com/article/18/9/linux-iptables-firewalld)
- [UFW](https://help.ubuntu.com/community/UFW)
- [How To Set Up a Firewall with UFW on Debian 9](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-debian-9)

### You have to set a DOS (Denial Of Service Attack) protection on your open ports of your VM. <a id="DOS"></a>
There are a lot of methods to set a DOS protection: [A guide to secure your server from DDoS!](https://bobcares.com/blog/centos-ddos-protection/) Let's use one of listed via the link - `Fail2Ban`:
```
$ sudo apt-get install iptables fail2ban apache2
```
Fail2Ban keeps its configuration files in `/etc/fail2ban` folder. The configuration file is `jail.conf` which is present in this directory. This file can be modified by package upgrades so we will keep a copy of it `jail.local` and edit it.
```
$ sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
$ sudo vim /etc/fail2ban/fail2ban.local
```

1. SSH protocol security (protect open port 50000). Edit `/etc/fail2ban/jail.local`: 

![fail2ban_ssh](img/fail2ban_ssh.png)

- [Fail2Ban Port 80 to protect sites from DOS Attacks](http://www.tothenew.com/blog/fail2ban-port-80-to-protect-sites-from-dos-attacks/)
- [Настройка Fail2ban](https://vps.ua/wiki/configuring-fail2ban/)

2. HTTP protocol security (protect our port 80). Edit `/etc/fail2ban/jail.local`:

![fail2ban_http](img/fail2ban_http.png)

Now we need to create the filter, to do that, create the file `/etc/fail2ban/filter.d/http-get-dos.conf` and add this text:

![http-get-dos.png](img/http-get-dos.png)

- [Install fail2ban to protect your site from DOS attacks](https://www.garron.me/en/go2linux/fail2ban-protect-web-server-http-dos-attack.html)

finaly:
```
$ sudo ufw reload
$ sudo service fail2ban restart
```
let's see the result:

![fail2ban_check](img/fail2ban_check.png)

### You have to set a protection against scans on your VM’s open ports. <a id="StopScan"></a>

```
$ sudo apt-get install portsentry
```
modify the file `/etc/default/portsentry`:

```
TCP_MODE="atcp"
UDP_MODE="audp"
```
We also wish that `portsentry` is a blockage. We therefore need to activate it by passing BLOCK_UDP and BLOCK_TCP to 1; modify `/etc/portsentry/portsentry.conf`:
```
##################
# Ignore Options #
##################
# 0 = Do not block UDP/TCP scans.
# 1 = Block UDP/TCP scans.
# 2 = Run external command only (KILL_RUN_CMD)

BLOCK_UDP="1"
BLOCK_TCP="1"
```
We opt for a blocking of malicious persons through iptables. We will therefore comment on all lines of the configuration file that begin with KILL_ROUTE except this one:
```
KILL_ROUTE="/sbin/iptables -I INPUT -s $TARGET$ -j DROP"
```
verify your actions:
```
$ cat portsentry.conf | grep KILL_ROUTE | grep -v "#"
```
relaunch service `portsentry` and it will now begin to block the port scans:
```
$ sudo /etc/init.d/portsentry start
```
`portsentry` logs are in the `/var/log/syslog` file.

- [To protect against the scan of ports with portsentry](https://en-wiki.ikoula.com/en/To_protect_against_the_scan_of_ports_with_portsentry)
- [How to protect against port scanners?](https://unix.stackexchange.com/questions/345114/how-to-protect-against-port-scanners)

### Stop the services you don’t need for this project. <a id="StopServices"></a>
All the services are controlled with special shell scripts in `/etc/init.d`, so:
```
$ ls /etc/init.d
```
![list_of_services](img/list_of_services.png)

```
$ sudo systemctl disable bluetooth.service
$ sudo systemctl disable console-setup.service
$ sudo systemctl disable keyboard-setup.service
```
- [List of available services](https://unix.stackexchange.com/questions/108591/list-of-available-services)

### Create a script that updates all the sources of package, then your packages and which logs the whole in a file named /var/log/update_script.log. Create a scheduled task for this script once a week at 4AM and every time the machine reboots. <a id="UpdatePackages"></a>

```
$ touch i_will_update.sh
$ chmod a+x i_will_update.sh
```
![update](img/update.png)

```
$ sudo crontab -e
```

![cron_update](img/cron_update.png)

 - [crontab guru](https://crontab.guru/#0_4_*_*_MON)

### Make a script to monitor changes of the /etc/crontab file and sends an email to root if it has been modified. Create a scheduled script task every day at midnight.  <a id="UpdateCron"></a>

```
$ touch i_will_monitor_cron.sh
$ chmod a+x i_will_monitor_cron.sh
```
![monitor_cron](img/monitor_cron.png)

Add this line to `crontab`:
```
* * * * * /home/kseniia/i_will_monitor_cron.sh &
```
#### to be able to use the mail command <a id="SetUpMail"></a>
install the `bsd-mailx package`:
```
$ sudo apt install bsd-mailx
```
Install `postfix` (setup happens after installation):
```
$ sudo apt install postfix
```
In postfix setup, select "Local only" to create a local mail server.
+ System mail name: "debian.lan"
+ Root and postmaster mail recipient: "root@localhost"
+ Other destinations to accept mail for: "debian.lan, debian.lan, localhost.lan, , localhost"
+ Force synchronous updates on mail queue? - No
+ Local networks: ENTER
+ Mailbox size limit (bytes): 0 (no limit)
+ Local address extension character: ENTER
+ Internet protocols to use: all

Edit `/etc/aliases`:
```
root: root
```
Then:
```
$ sudo newaliases
```
To update the aliases here.

Then change the home mailbox directory:
```
$ sudo postconf -e "home_mailbox = mail/"
```
Restart the postfix service:
```
$ sudo service postfix restart
```
Install the CLI (non-graphical) mail client `mutt`:
```
$ sudo apt install mutt
```
Create a config file `".muttrc"` for `mutt` in the `/root/` directory and edit it:
```
set mbox_type=Maildir
set folder="/root/mail"
set mask="!^\\.[^.]"
set mbox="/root/mail"
set record="+.Sent"
set postponed="+.Drafts"
set spoolfile="/root/mail"
```
Start `mutt` and exit:
```
$ mutt
Enter 'q' to exit
```
Test sending a simple mail to root:
```
$ echo "Text" | sudo mail -s "Subject" root@debian.lan
```
Then login as root and start `mutt`. The mail should now be visible.

The crontab script should now work.
- [Setting Up Local Mail Delivery on Ubuntu with Postfix and Mutt](https://www.cmsimike.com/blog/2011/10/30/setting-up-local-mail-delivery-on-ubuntu-with-postfix-and-mutt/)

> to copy file from host to VM via SSH: `scp -P 50000 i_will_monitor_cron.sh kseniia@192.168.10.42:~` (~ means home dir)
## V.2 Web Part <a id="WebPart"></a>
my login page:

![login_page](img/login_page.png)


> scp -P 50000 kseniia@192.168.10.42:/var/www/html/index.html .

Generate SSL self-signed key and certificate:
```
$ sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/apache-selfsigned.key -out /etc/ssl/certs/apache-selfsigned.crt
Country name: UA
State or Province Name: ENTER
Locality Name: ENTER
Organization Name: ENTER
Organizational Unit Name: ENTER
Common Name: 192.168.10.42 (VM IP address)
Email Address: root@debian.lan
```

Create the file /etc/apache2/conf-available/ssl-params.conf and edit it:
```
SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3
SSLHonorCipherOrder On

Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff

SSLCompression off
SSLSessionTickets Off
SSLUseStapling on
SSLStaplingCache "shmcb:logs/stapling-cache(150000)"
```

Edit the file /etc/apache2/sites-available/default-ssl.conf so it looks like this:

```
<IfModule mod_ssl.c>
	<VirtualHost _default_:443>
		ServerAdmin root@localhost
		ServerName 192.168.10.42
		DocumentRoot /var/www/html
		ErrorLog ${APACHE_LOG_DIR}/error.log
		CustomLog ${APACHE_LOG_DIR}/access.log combined
		SSLEngine on
		SSLCertificateFile	/etc/ssl/certs/apache-selfsigned.crt
		SSLCertificateKeyFile /etc/ssl/private/apache-selfsigned.key
		<FilesMatch "\.(cgi|shtml|phtml|php)$">
				SSLOptions +StdEnvVars
		</FilesMatch>
		<Directory /usr/lib/cgi-bin>
				SSLOptions +StdEnvVars
		</Directory>
	</VirtualHost>
</IfModule>
```

Add a redirect rule to /etc/apache2/sites-available/000-default.conf, to redirect HTTP to HTTPS:
```
Redirect "/" "https://192.168.10.42/"
```

Enable everything changed and restart the Apache service:
```
$ sudo a2enmod ssl
$ sudo a2enmod headers
$ sudo a2ensite default-ssl
$ sudo a2enconf ssl-params
$ sudo apache2ctl configtest (to check that the syntax is OK)
$ sudo systemctl restart apache2
```

The SSL server is tested by entering "https://192.168.10.42" in a host browser. The expected result is a "Your connection is not private" warning page. Continue from this by selecting Advanced->Proceed to...
HTTP->HTTPS redirection is tested by entering "http://192.168.10.42" in the host browser.

## V.3 Deployment Part <a id="DepPart"></a>




























