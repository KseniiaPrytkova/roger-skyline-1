# roger-skyline-1

## V.1 VM Part
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
## V.2 Network and Security Part
### You must create a non-root user to connect to the machine and work.
Non-root login was created while setting up the OS. Just log in.
### Use sudo, with this user, to be able to perform operation requiring special rights.
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

### We don’t want you to use the DHCP service of your machine. You’ve got to configure it to have a static IP and a Netmask in \30.
First, go to VirtualBox settings -> Network -> in `Attached to` subsection change ***NAT*** on ***Bridged Adapter***; i like using `ifconfig`, that's why i'll install it (it's always possible to use `ip`):
```
$ sudo apt-get install net-tools
$ sudo ifconfig
```
As we see, the name of our `bridged adapter` is ***enp0s3***. Let's setup ***static ip*** (not dynamical) - [How to setup a Static IP address on Debian Linux)](https://linuxconfig.org/how-to-setup-a-static-ip-address-on-debian-linux), [Network of VirtualBox instances with static IP addresses and Internet access.](https://www.codesandnotes.be/2018/10/16/network-of-virtualbox-instances-with-static-ip-addresses-and-internet-access/).

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

### You have to change the default port of the SSH service by the one of your choice. SSH access HAS TO be done with publickeys. SSH root access SHOULD NOT be allowed directly, but with a user who can be root.
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
Finaly, let's test the ssh conection from host. We need to setup SSH public key authentication [Setup SSH Public Key Authentication](https://www.cyberciti.biz/faq/ubuntu-18-04-setup-ssh-public-key-authentication/); OS of my host is macOS Sierra; run from ***your host's terminal***:

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

### You have to set the rules of your firewall on your server only with the services used outside the VM.
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

### You have to set a DOS (Denial Of Service Attack) protection on your open ports of your VM.
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

### You have to set a protection against scans on your VM’s open ports.

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

### Stop the services you don’t need for this project.
All the services are controlled with special shell scripts in `/etc/init.d`, so:
```
$ ls /etc/init.d
```
![list_of_services](img/list_of_sefvices.png)

- [List of available services](https://unix.stackexchange.com/questions/108591/list-of-available-services)

```
$ sudo systemctl disable bluetooth.service
$ sudo systemctl disable console-setup.service
$ sudo systemctl disable keyboard-setup.service
```
## V.2 Web Part

## V.3 Deployment Part














