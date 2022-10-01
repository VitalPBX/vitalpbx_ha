#!/bin/bash
# This code is the property of VitalPBX LLC Company
# License: Proprietary
# Date: 30-Sep-2022
# VitalPBX Hight Availability with MariaDB Replica, Corosync, PCS, Pacemaker and Lsync
#
set -e
function jumpto
{
    label=$start
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

echo -e "\n"
echo -e "************************************************************"
echo -e "*  Welcome to the VitalPBX high availability installation  *"
echo -e "*                All options are mandatory                 *"
echo -e "************************************************************"

filename="config.txt"
if [ -f $filename ]; then
	echo -e "config file"
	n=1
	while read line; do
		case $n in
			1)
				ip_master=$line
  			;;
			2)
				ip_standby=$line
  			;;
			3)
				ip_floating=$line
  			;;
			4)
				ip_floating_mask=$line
  			;;
			5)
				hapassword=$line
  			;;
		esac
		n=$((n+1))
	done < $filename
	echo -e "IP Master................ > $ip_master"	
	echo -e "IP Standby............... > $ip_standby"
	echo -e "Floating IP.............. > $ip_floating "
	echo -e "Floating IP Mask (SIDR).. > $ip_floating_mask"
	echo -e "hacluster password....... > $hapassword"
fi

while [[ $ip_master == '' ]]
do
    read -p "IP Master................ > " ip_master 
done 

while [[ $ip_standby == '' ]]
do
    read -p "IP Standby............... > " ip_standby 
done

while [[ $ip_floating == '' ]]
do
    read -p "Floating IP.............. > " ip_floating 
done 

while [[ $ip_floating_mask == '' ]]
do
    read -p "Floating IP Mask (SIDR).. > " ip_floating_mask
done 

while [[ $hapassword == '' ]]
do
    read -p "hacluster password....... > " hapassword 
done

echo -e "************************************************************"
echo -e "*                   Check Information                      *"
echo -e "*        Make sure you have internet on both servers       *"
echo -e "************************************************************"
while [[ $veryfy_info != yes && $veryfy_info != no ]]
do
    read -p "Are you sure to continue with this settings? (yes,no) > " veryfy_info 
done

if [ "$veryfy_info" = yes ] ;then
	echo -e "************************************************************"
	echo -e "*                Starting to run the scripts               *"
	echo -e "************************************************************"
else
    	exit;
fi

cat > config.txt << EOF
$ip_master
$ip_standby
$ip_floating
$ip_floating_mask
$hapassword
EOF

echo -e "************************************************************"
echo -e "*            Get the hostname in Master and Standby         *"
echo -e "************************************************************"
host_master=`hostname -f`
host_standby=`ssh root@$ip_standby 'hostname -f'`
echo -e "$host_master"
echo -e "$host_standby"
echo -e "*** Done ***"

arg=$1
if [ "$arg" = 'destroy' ] ;then

# Print a warning message destroy cluster message
echo -e "*****************************************************************"
echo -e "*  \e[41m WARNING-WARNING-WARNING-WARNING-WARNING-WARNING-WARNING  \e[0m   *"
echo -e "*  This process completely destroys the cluster on both servers *"
echo -e "*          then you can re-create it with the command           *"
echo -e "*                     ./vpbxha.sh rebuild                       *"
echo -e "*****************************************************************"
	while [[ $veryfy_destroy != yes && $veryfy_destroy != no ]]
	do
	read -p "Are you sure you want to completely destroy the cluster? (yes, no) > " veryfy_destroy 
	done
	if [ "$veryfy_destroy" = yes ] ;then
		pcs cluster stop
		pcs cluster destroy
		systemctl disable pcsd.service 
		systemctl disable corosync.service 
		systemctl disable pacemaker.service
		systemctl stop pcsd.service 
		systemctl stop corosync.service 
		systemctl stop pacemaker.service
cat > /etc/profile.d/vitalwelcome.sh << EOF
#!/bin/bash
# This code is the property of VitalPBX LLC Company
# License: Proprietary
# Date: 30-Sep-2022
# Show the Role of Server.
#Bash Colour Codes
green="\033[00;32m"
txtrst="\033[00;0m"
if [ -f /etc/redhat-release ]; then
        linux_ver=\`cat /etc/redhat-release\`
        vitalpbx_ver=\`rpm -qi vitalpbx |awk -F: '/^Version/ {print \$2}'\`
        vitalpbx_release=\`rpm -qi vitalpbx |awk -F: '/^Release/ {print \$2}'\`
elif [ -f /etc/debian_version ]; then
        linux_ver="Debian "\`cat /etc/debian_version\`
        vitalpbx_ver=\`dpkg -l vitalpbx |awk '/ombutel/ {print \$3}'\`
else
        linux_ver=""
        vitalpbx_ver=""
        vitalpbx_release=""
fi
vpbx_version="\${vitalpbx_ver}-\${vitalpbx_release}"
asterisk_version=\`rpm -q --qf "%{VERSION}" asterisk\`
logo='
 _    _ _           _ ______ ______ _    _
| |  | (_)_        | (_____ (____  \ \  / /
| |  | |_| |_  ____| |_____) )___)  ) \/ /
 \ \/ /| |  _)/ _  | |  ____/  __  ( )  (
  \  / | | |_( ( | | | |    | |__)  ) /\ \\
   \/  |_|\___)_||_|_|_|    |______/_/  \_\\
'
echo -e "
\${green}
\${logo}
\${txtrst}
 Version        : \${vpbx_version//[[:space:]]}
 Asterisk       : \${asterisk_version}
 Linux Version  : \${linux_ver}
 Welcome to     : \`hostname\`
 Uptime         : \`uptime | grep -ohe 'up .*' | sed 's/up //g' | awk -F "," '{print \$1}'\`
 Load           : \`uptime | grep -ohe 'load average[s:][: ].*' | awk '{ print "Last Minute: " \$3" Last 5 Minutes: "\$4" Last 15 Minutes: "\$5 }'\`
 Users          : \`uptime | grep -ohe '[0-9.*] user[s,]'\`
 IP Address     : \${green}\`ip addr | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | xargs\`\${txtrst}
 Clock          :\`timedatectl | sed -n '/Local time/ s/^[ \t]*Local time:\(.*$\)/\1/p'\`
 NTP Sync.      :\`timedatectl |awk -F: '/NTP sync/ {print \$2}'\`
"
EOF
chmod 755 /etc/profile.d/vitalwelcome.sh
scp /etc/profile.d/vitalwelcome.sh root@$ip_standby:/etc/profile.d/vitalwelcome.sh
ssh root@$ip_standby "chmod 755 /etc/profile.d/vitalwelcome.sh"
rm -rf /usr/local/bin/bascul		
rm -rf /usr/local/bin/role
ssh root@$ip_standby "rm -rf /usr/local/bin/bascul"
ssh root@$ip_standby "rm -rf /usr/local/bin/role"
echo -e "************************************************************"
echo -e "*         Remove Firewall Services/Rules in Mariadb        *"
echo -e "************************************************************"
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'MariaDB Client'" | awk 'NR==2')
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_rules WHERE firewall_service_id = $service_id"
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA2224'" | awk 'NR==2')
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_rules WHERE firewall_service_id = $service_id"
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA3121'" | awk 'NR==2')
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_rules WHERE firewall_service_id = $service_id"
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA5403'" | awk 'NR==2')
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_rules WHERE firewall_service_id = $service_id"
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA5404-5405'" | awk 'NR==2')
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_rules WHERE firewall_service_id = $service_id"
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA21064'" | awk 'NR==2')
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_rules WHERE firewall_service_id = $service_id"
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA9929'" | awk 'NR==2')
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_rules WHERE firewall_service_id = $service_id"
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_whitelist WHERE description = 'Server 1 IP'"
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_whitelist WHERE description = 'Server 2 IP'"
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_services WHERE name = 'MariaDB Client'"
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_services WHERE name = 'HA2224'"
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_services WHERE name = 'HA3121'"
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_services WHERE name = 'HA5403'"
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_services WHERE name = 'HA5404-5405'"
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_services WHERE name = 'HA21064'"
mysql -uroot ombutel -e "DELETE FROM ombu_firewall_services WHERE name = 'HA9929'"
cat > /etc/my.cnf.d/server.cnf << EOF
#
# These groups are read by MariaDB server.
# Use it for options that only the server (but not clients) should see
#
# See the examples of server my.cnf files in /usr/share/mysql/
#
# this is read by the standalone daemon and embedded servers
[server]
# this is only for the mysqld standalone daemon
[mysqld]
#
# * Galera-related settings
#
[galera]
# Mandatory settings
#wsrep_on=ON
#wsrep_provider=
#wsrep_cluster_address=
#binlog_format=row
#default_storage_engine=InnoDB
#innodb_autoinc_lock_mode=2
#
# Allow server to accept connections on all interfaces.
#
#bind-address=0.0.0.0
#
# Optional setting
#wsrep_slave_threads=1
#innodb_flush_log_at_trx_commit=0
# this is only for embedded server
[embedded]
EOF
scp /etc/my.cnf.d/server.cnf root@$ip_standby:/etc/my.cnf.d/server.cnf
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "RESET SLAVE;"
systemctl restart mariadb
ssh root@$ip_standby 'mysql -uroot -e "STOP SLAVE;"'
ssh root@$ip_standby 'mysql -uroot -e "RESET SLAVE;"'
ssh root@$ip_standby "systemctl restart mariadb"

cat > /etc/lsyncd.conf << EOF
----
-- User configuration file for lsyncd.
--
-- Simple example for default rsync.
--
EOF
scp /etc/lsyncd.conf root@$ip_standby:/etc/lsyncd.conf
cat > /tmp/remotecluster.sh << EOF
#!/bin/bash
pcs cluster destroy
systemctl disable pcsd.service 
systemctl disable corosync.service 
systemctl disable pacemaker.service
systemctl stop pcsd.service 
systemctl stop corosync.service 
systemctl stop pacemaker.service
EOF
scp /tmp/remotecluster.sh root@$ip_standby:/tmp/remotecluster.sh
ssh root@$ip_standby "chmod +x /tmp/remotecluster.sh"
ssh root@$ip_standby "/tmp/./remotecluster.sh"	
systemctl stop lsyncd
systemctl enable asterisk
systemctl restart asterisk
ssh root@$ip_standby "systemctl stop lsyncd"
ssh root@$ip_standby "systemctl enable asterisk"
ssh root@$ip_standby "systemctl restart asterisk"
echo -e "************************************************************"
echo -e "*  Remove memory Firewall Rules in Server 1 and 2 and App  *"
echo -e "************************************************************"
firewall-cmd --remove-service=high-availability
firewall-cmd --zone=public --remove-port=3306/tcp
firewall-cmd --runtime-to-permanent
firewall-cmd --reload
ssh root@$ip_standby "firewall-cmd --remove-service=high-availability"
ssh root@$ip_standby "firewall-cmd --zone=public --remove-port=3306/tcp"
ssh root@$ip_standby "firewall-cmd --runtime-to-permanent"
ssh root@$ip_standby "firewall-cmd --reload"
echo -e "************************************************************"
echo -e "*            Cluster destroyed successfully                *"
echo -e "************************************************************"
		
	fi
	echo -e "2"	> step.txt
	exit
fi

if [ "$arg" = 'rebuild' ] ;then
	step=4
else
	stepFile=step.txt
	if [ -f $stepFile ]; then
		step=`cat $stepFile`
	else
		step=0
	fi
fi

echo -e "Start in step: " $step

start="create_hostname"
case $step in
	1)
		start="create_hostname"
  	;;
	2)
		start="rename_tenant_id_in_server2"
  	;;
	3)
		start="configuring_firewall"
  	;;
	4)
		start="create_lsyncd_config_file"
  	;;
	5)
		start="create_mariadb_replica"
	;;
	6)
		start="create_hacluster_password"
  	;;
	7)
		start="starting_pcs"
  	;;
	8)
		start="auth_hacluster"
  	;;
	9)
		start="creating_cluster"
  	;;
	10)
		start="starting_cluster"
  	;;
	11)
		start="creating_floating_ip"
  	;;
	12)
		start="disable_services"
	;;
	13)
		start="create_asterisk_service"
	;;
	14)
		start="create_lsyncd_service"
	;;
	15)
		start="vitalpbx_create_bascul"
	;;
	16)
		start="vitalpbx_create_role"
		;;
	17)
		start="ceate_welcome_message"
	;;
	18)
		start="ceate_maridb_fix_sync"
	;;
esac
jumpto $start
echo -e "*** Done Step 1 ***"
echo -e "1"	> step.txt

create_hostname:
echo -e "************************************************************"
echo -e "*          Creating hosts name in Master/Standby           *"
echo -e "************************************************************"
echo -e "$ip_master \t$host_master" >> /etc/hosts
echo -e "$ip_standby \t$host_standby" >> /etc/hosts
ssh root@$ip_standby "echo -e '$ip_master \t$host_master' >> /etc/hosts"
ssh root@$ip_standby "echo -e '$ip_standby \t$host_standby' >> /etc/hosts"
echo -e "*** Done Step 2 ***"
echo -e "2"	> step.txt

rename_tenant_id_in_server2:
echo -e "************************************************************"
echo -e "*                Remove Tenant in Server 2                 *"
echo -e "************************************************************"
remote_tenant_id=`ssh root@$ip_standby "ls /var//lib/vitalpbx/static/"`
ssh root@$ip_standby "rm -rf /var/lib/vitalpbx/static/$remote_tenant_id"
echo -e "*** Done Step 3 ***"
echo -e "3"	> step.txt

configuring_firewall:
echo -e "************************************************************"
echo -e "*             Configuring Temporal Firewall                *"
echo -e "************************************************************"
#Create temporal Firewall Rules in Server 1 and 2
firewall-cmd --permanent --add-service=high-availability
firewall-cmd --permanent --zone=public --add-port=3306/tcp
firewall-cmd --reload
ssh root@$ip_standby "firewall-cmd --permanent --add-service=high-availability"
ssh root@$ip_standby "firewall-cmd --permanent --zone=public --add-port=3306/tcp"
ssh root@$ip_standby "firewall-cmd --reload"

echo -e "************************************************************"
echo -e "*             Configuring Permanent Firewall               *"
echo -e "*   Creating Firewall Services in VitalPBX in Server 1     *"
echo -e "************************************************************"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('MariaDB Client', 'tcp', '3306')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA2224', 'tcp', '2224')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA3121', 'tcp', '3121')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA5403', 'tcp', '5403')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA5404-5405', 'udp', '5404-5405')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA21064', 'tcp', '21064')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_services (name, protocol, port) VALUES ('HA9929', 'both', '9929')"
echo -e "************************************************************"
echo -e "*             Configuring Permanent Firewall               *"
echo -e "*     Creating Firewall Rules in VitalPBX in Server 1      *"
echo -e "************************************************************"
last_index=$(mysql -uroot ombutel -e "SELECT MAX(\`index\`) AS Consecutive FROM ombu_firewall_rules"  | awk 'NR==2')
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'MariaDB Client'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA2224'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA3121'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA5403'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA5404-5405'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA21064'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_arbitrator', 'accept', $last_index)"
last_index=$last_index+1
service_id=$(mysql -uroot ombutel -e "select firewall_service_id from ombu_firewall_services where name = 'HA9929'" | awk 'NR==2')
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_master', 'accept', $last_index)"
last_index=$last_index+1
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_rules (firewall_service_id, source, action, \`index\`) VALUES ($service_id, '$ip_standby', 'accept', $last_index)"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_whitelist (host, description, \`default\`) VALUES ('$ip_master', 'Server 1 IP', 'no')"
mysql -uroot ombutel -e "INSERT INTO ombu_firewall_whitelist (host, description, \`default\`) VALUES ('$ip_standby', 'Server 2 IP', 'no')"
echo -e "*** Done Step 4 ***"
echo -e "4"	> step.txt

create_lsyncd_config_file:
echo -e "************************************************************"
echo -e "*          Configure lsync in Server 1 and 2               *"
echo -e "************************************************************"
if [ ! -d "/var/spool/asterisk/monitor" ] ;then
	mkdir /var/spool/asterisk/monitor
fi
chown asterisk:asterisk /var/spool/asterisk/monitor

if [ ! -d "/usr/share/vitxi" ] ;then
	mkdir /usr/share/vitxi
	mkdir /usr/share/vitxi/backend
	mkdir /usr/share/vitxi/backend/storage
fi
chown -R apache:apache /usr/share/vitxi

if [ ! -d "/var/lib/vitxi" ] ;then
	mkdir /var/lib/vitxi
fi
chown -R apache:apache /var/lib/vitxi

ssh root@$ip_standby [[ ! -d /var/spool/asterisk/monitor ]] && ssh root@$ip_standby "mkdir /var/spool/asterisk/monitor" || echo "Path exist";
ssh root@$ip_standby "chown -R asterisk:asterisk /var/spool/asterisk/monitor"

ssh root@$ip_standby [[ ! -d /usr/share/vitxi ]] && ssh root@$ip_standby "mkdir /usr/share/vitxi" || echo "Path exist";
ssh root@$ip_standby "chown -R apache:apache /usr/share/vitxi"

ssh root@$ip_standby [[ ! -d /usr/share/vitxi/backend ]] && ssh root@$ip_standby "mkdir /usr/share/vitxi/backend" || echo "Path exist";
ssh root@$ip_standby "chown -R apache:apache /usr/share/vitxi/backend"

ssh root@$ip_standby [[ ! -d /usr/share/vitxi/backend/storage ]] && ssh root@$ip_standby "mkdir /usr/share/vitxi/backend/storage" || echo "Path exist";
ssh root@$ip_standby "chown -R apache:apache /usr/share/vitxi/backend/storage"

ssh root@$ip_standby [[ ! -d /var/lib/vitxi ]] && ssh root@$ip_standby "mkdir /var/lib/vitxi" || echo "Path exist";
ssh root@$ip_standby "chown -R apache:apache /var/lib/vitxi"

cat > /etc/lsyncd.conf << EOF
----
-- User configuration file for lsyncd.
--
-- Simple example for default rsync.
--
settings {
		logfile    = "/var/log/lsyncd/lsyncd.log",
		statusFile = "/var/log/lsyncd/lsyncd-status.log",
		statusInterval = 20,
		nodaemon   = true,
		insist = true,
}

sync {
		default.rsync,
		source="/var/spool/asterisk/monitor",
		target="$ip_standby:/var/spool/asterisk/monitor",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/",
		target="$ip_standby:/var/lib/asterisk/",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,
				archive = "true",
				_extra = {
						"--include=astdb.sqlite3",
						"--exclude=*"
						}
				}
}

sync {
		default.rsync,
		source="/usr/share/vitxi/backend/",
		target="$ip_standby:/usr/share/vitxi/backend/",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,
				archive = "true",
				_extra = {
						"--include=.env",
						"--exclude=*"
						}
				}
}

sync {
		default.rsync,
		source="/usr/share/vitxi/backend/storage/",
		target="$ip_standby:/usr/share/vitxi/backend/storage/",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/vitxi/",
		target="$ip_standby:/var/lib/vitxi/",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,
				archive = "true",
				_extra = {
						"--include=wizard.conf",
						"--exclude=*"
						}
				}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/agi-bin/",
		target="$ip_standby:/var/lib/asterisk/agi-bin/",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/priv-callerintros/",
		target="$ip_standby:/var/lib/asterisk/priv-callerintros",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/sounds/",
		target="$ip_standby:/var/lib/asterisk/sounds/",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/vitalpbx",
		target="$ip_standby:/var/lib/vitalpbx",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,			
				archive = "true",
				_extra = {
						"--exclude=*.lic",
						"--exclude=*.dat",
						"--exclude=dbsetup-done",
						"--exclude=cache"
						}
				}
}

sync {
		default.rsync,
		source="/etc/asterisk",
		target="$ip_standby:/etc/asterisk",
		rsync={
				owner = true,
				group = true
		}
}
EOF
cat > /tmp/lsyncd.conf << EOF
----
-- User configuration file for lsyncd.
--
-- Simple example for default rsync.
--
settings {
		logfile    = "/var/log/lsyncd/lsyncd.log",
		statusFile = "/var/log/lsyncd/lsyncd-status.log",
		statusInterval = 20,
		nodaemon   = true,
		insist = true,
}

sync {
		default.rsync,
		source="/var/spool/asterisk/monitor",
		target="$ip_master:/var/spool/asterisk/monitor",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/",
		target="$ip_master:/var/lib/asterisk/",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,
				archive = "true",
				_extra = {
						"--include=astdb.sqlite3",
						"--exclude=*"
						}
				}
}

sync {
		default.rsync,
		source="/usr/share/vitxi/backend/",
		target="$ip_master:/usr/share/vitxi/backend/",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,
				archive = "true",
				_extra = {
						"--include=.env",
						"--exclude=*"
						}
				}
}

sync {
		default.rsync,
		source="/usr/share/vitxi/backend/storage/",
		target="$ip_master:/usr/share/vitxi/backend/storage/",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/vitxi/",
		target="$ip_master:/var/lib/vitxi/",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,
				archive = "true",
				_extra = {
						"--include=wizard.conf",
						"--exclude=*"
						}
				}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/agi-bin/",
		target="$ip_master:/var/lib/asterisk/agi-bin/",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/priv-callerintros/",
		target="$ip_master:/var/lib/asterisk/priv-callerintros",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/asterisk/sounds/",
		target="$ip_master:/var/lib/asterisk/sounds/",
		rsync={
				owner = true,
				group = true
		}
}

sync {
		default.rsync,
		source="/var/lib/vitalpbx",
		target="$ip_master:/var/lib/vitalpbx",
		rsync = {
				binary = "/usr/bin/rsync",
				owner = true,
				group = true,
				archive = "true",
				_extra = {
						"--exclude=*.lic",
						"--exclude=*.dat",
						"--exclude=dbsetup-done",
						"--exclude=cache"
						}
				}
}

sync {
		default.rsync,
		source="/etc/asterisk",
		target="$ip_master:/etc/asterisk",
		rsync={
				owner = true,
				group = true
		}
}
EOF
scp /tmp/lsyncd.conf root@$ip_standby:/etc/lsyncd.conf
echo -e "*** Done Step 5 ***"
echo -e "5"	> step.txt

create_mariadb_replica:
echo -e "************************************************************"
echo -e "*                Create mariadb replica                    *"
echo -e "************************************************************"
#Remove anonymous user from MySQL
mysql -uroot -e "DELETE FROM mysql.user WHERE User='';"
#Configuration of the First Master Server (Master-1)
cat > /etc/my.cnf.d/vitalpbx.cnf << EOF
[mysqld]
server-id=1
log-bin=mysql-bin
report_host = master1

innodb_buffer_pool_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 64M
innodb_log_buffer_size = 64M
bulk_insert_buffer_size = 64M
max_allowed_packet = 64M
EOF
systemctl restart mariadb
#Create a new user on the Master-1
mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* to vitalpbx_replica@'%' IDENTIFIED BY 'vitalpbx_replica';"
mysql -uroot -e "FLUSH PRIVILEGES;"
mysql -uroot -e "FLUSH TABLES WITH READ LOCK;"
#Get bin_log on Master-1
file_server_1=`mysql -uroot -e "show master status" | awk 'NR==2 {print $1}'`
position_server_1=`mysql -uroot -e "show master status" | awk 'NR==2 {print $2}'`

#Now on the Master-1 server, do a dump of the database MySQL and import it to Master-2
mysqldump -u root --all-databases > all_databases.sql
scp all_databases.sql root@$ip_standby:/tmp/all_databases.sql
cat > /tmp/mysqldump.sh << EOF
#!/bin/bash
mysql mysql -u root <  /tmp/all_databases.sql 
EOF
scp /tmp/mysqldump.sh root@$ip_standby:/tmp/mysqldump.sh
ssh root@$ip_standby "chmod +x /tmp/mysqldump.sh"
ssh root@$ip_standby "/tmp/./mysqldump.sh"

#Configuration of the Second Master Server (Master-2)
cat > /tmp/vitalpbx.cnf << EOF
[mysqld]
server-id = 2
log-bin=mysql-bin
report_host = master2

innodb_buffer_pool_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 64M
innodb_log_buffer_size = 64M
bulk_insert_buffer_size = 64M
max_allowed_packet = 64M
EOF
scp /tmp/vitalpbx.cnf root@$ip_standby:/etc/my.cnf.d/vitalpbx.cnf
ssh root@$ip_standby "systemctl restart mariadb"
#Create a new user on the Master-2
cat > /tmp/grand.sh << EOF
#!/bin/bash
mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* to vitalpbx_replica@'%' IDENTIFIED BY 'vitalpbx_replica';"
mysql -uroot -e "FLUSH PRIVILEGES;"
mysql -uroot -e "FLUSH TABLES WITH READ LOCK;"
EOF
scp /tmp/grand.sh root@$ip_standby:/tmp/grand.sh
ssh root@$ip_standby "chmod +x /tmp/grand.sh"
ssh root@$ip_standby "/tmp/./grand.sh"
#Get bin_log on Master-2
file_server_2=`ssh root@$ip_standby 'mysql -uroot -e "show master status;"' | awk 'NR==2 {print $1}'`
position_server_2=`ssh root@$ip_standby 'mysql -uroot -e "show master status;"' | awk 'NR==2 {print $2}'`
#Stop the slave, add Master-1 to the Master-2 and start slave
cat > /tmp/change.sh << EOF
#!/bin/bash
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='$ip_master', MASTER_USER='vitalpbx_replica', MASTER_PASSWORD='vitalpbx_replica', MASTER_LOG_FILE='$file_server_1', MASTER_LOG_POS=$position_server_1;"
mysql -uroot -e "START SLAVE;"
EOF
scp /tmp/change.sh root@$ip_standby:/tmp/change.sh
ssh root@$ip_standby "chmod +x /tmp/change.sh"
ssh root@$ip_standby "/tmp/./change.sh"

#Connect to Master-1 and follow the same steps
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='$ip_standby', MASTER_USER='vitalpbx_replica', MASTER_PASSWORD='vitalpbx_replica', MASTER_LOG_FILE='$file_server_2', MASTER_LOG_POS=$position_server_2;"
mysql -uroot -e "START SLAVE;"

echo -e "*** Done Step 6 ***"
echo -e "6"	> step.txt

create_hacluster_password:
echo -e "************************************************************"
echo -e "*     Create password for hacluster in Master/Standby      *"
echo -e "************************************************************"
echo $hapassword | passwd --stdin hacluster
ssh root@$ip_standby "echo $hapassword | passwd --stdin hacluster"
echo -e "*** Done Step 7 ***"
echo -e "7"	> step.txt

starting_pcs:
echo -e "************************************************************"
echo -e "*         Starting pcsd services in Master/Standby         *"
echo -e "************************************************************"
systemctl start pcsd
ssh root@$ip_standby "systemctl start pcsd"
systemctl enable pcsd.service 
systemctl enable corosync.service 
systemctl enable pacemaker.service
ssh root@$ip_standby "systemctl enable pcsd.service"
ssh root@$ip_standby "systemctl enable corosync.service"
ssh root@$ip_standby "systemctl enable pacemaker.service"
echo -e "*** Done Step 8 ***"
echo -e "8"	> step.txt

auth_hacluster:
echo -e "************************************************************"
echo -e "*            Server Authenticate in Master                 *"
echo -e "************************************************************"
pcs cluster auth $host_master $host_standby -u hacluster -p $hapassword
echo -e "*** Done Step 9 ***"
echo -e "9"	> step.txt

creating_cluster:
echo -e "************************************************************"
echo -e "*              Creating Cluster in Master                  *"
echo -e "************************************************************"
pcs cluster setup --name cluster_vitalpbx $host_master $host_standby
echo -e "*** Done Step 10 ***"
echo -e "10"	> step.txt

starting_cluster:
echo -e "************************************************************"
echo -e "*              Starting Cluster in Master                  *"
echo -e "************************************************************"
pcs cluster start --all
pcs cluster enable --all
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore
echo -e "*** Done Step 11 ***"
echo -e "11"	> step.txt

creating_floating_ip:
echo -e "************************************************************"
echo -e "*            Creating Floating IP in Master                *"
echo -e "************************************************************"
pcs resource create virtual_ip ocf:heartbeat:IPaddr2 ip=$ip_floating cidr_netmask=$ip_floating_mask op monitor interval=30s on-fail=restart
pcs cluster cib drbd_cfg
pcs cluster cib-push drbd_cfg
echo -e "*** Done Step 12 ***"
echo -e "12"	> step.txt

disable_services:
echo -e "************************************************************"
echo -e "*             Disable Services in Server 1 and 2           *"
echo -e "************************************************************"
systemctl disable asterisk
systemctl stop asterisk
systemctl disable lsyncd
systemctl stop lsyncd
ssh root@$ip_standby "systemctl disable asterisk"
ssh root@$ip_standby "systemctl stop asterisk"
ssh root@$ip_standby "systemctl disable lsyncd"
ssh root@$ip_standby "systemctl stop lsyncd"
echo -e "*** Done Step 13 ***"
echo -e "13"	> step.txt

create_asterisk_service:
echo -e "************************************************************"
echo -e "*          Create asterisk Service in Server 1             *"
echo -e "************************************************************"
pcs resource create asterisk service:asterisk op monitor interval=30s
pcs cluster cib fs_cfg
pcs cluster cib-push fs_cfg --config
pcs -f fs_cfg constraint colocation add asterisk with virtual_ip INFINITY
pcs -f fs_cfg constraint order virtual_ip then asterisk
pcs cluster cib-push fs_cfg --config
#Changing these values from 15s (default) to 120s is very important 
#since depending on the server and the number of extensions 
#the Asterisk can take more than 15s to start
pcs resource update asterisk op stop timeout=120s
pcs resource update asterisk op start timeout=120s
pcs resource update asterisk op restart timeout=120s
echo -e "*** Done Step 14 ***"
echo -e "14"	> step.txt

create_lsyncd_service:
echo -e "************************************************************"
echo -e "*             Create lsyncd Service in Server 1            *"
echo -e "************************************************************"
pcs resource create lsyncd service:lsyncd.service op monitor interval=30s
pcs cluster cib fs_cfg
pcs cluster cib-push fs_cfg --config
pcs -f fs_cfg constraint colocation add lsyncd with virtual_ip INFINITY
pcs -f fs_cfg constraint order asterisk then lsyncd
pcs cluster cib-push fs_cfg --config
echo -e "*** Done Step 15 ***"
echo -e "15"	> step.txt

vitalpbx_create_bascul:
echo -e "************************************************************"
echo -e "*         Creating VitalPBX Cluster bascul Command         *"
echo -e "************************************************************"
cat > /usr/local/bin/bascul << EOF
#!/bin/bash
# This code is the property of VitalPBX LLC Company
# License: Proprietary
# Date: 30-Jul-2020
# Change the status of the servers, the Master goes to Stanby and the Standby goes to Master.
#funtion for draw a progress bar
#You must pass as argument the amount of secconds that the progress bar will run
#progress-bar 10 --> it will generate a progress bar that will run per 10 seconds

set -e
progress-bar() {
        local duration=\${1}

        already_done() { for ((done=0; done<\$elapsed; done++)); do printf ">"; done }
        remaining() { for ((remain=\$elapsed; remain<\$duration; remain++)); do printf " "; done }
        percentage() { printf "| %s%%" \$(( ((\$elapsed)*100)/(\$duration)*100/100 )); }
        clean_line() { printf "\r"; }

        for (( elapsed=1; elapsed<=\$duration; elapsed++ )); do
                already_done; remaining; percentage
                sleep 1
                clean_line
        done
        clean_line
}

server_a=\`pcs status | awk 'NR==10 {print \$3}'\`
server_b=\`pcs status | awk 'NR==10 {print \$4}'\`
server_master=\`pcs status resources | awk 'NR==1 {print \$4}'\`

#Perform some validations
if [ "\${server_a}" = "" ] || [ "\${server_b}" = "" ]
then
    echo -e "\e[41m There are problems with high availability, please check with the command *pcs status* (we recommend applying the command *pcs cluster unstandby* in both servers) \e[0m"
    exit;
fi

if [[ "\${server_master}" = "\${server_a}" ]]; then
        host_master=\$server_a
        host_standby=\$server_b
else
        host_master=\$server_b
        host_standby=\$server_a
fi

arg=\$1
if [ "\$arg" = 'yes' ] ;then
	perform_bascul='yes'
fi

# Print a warning message and ask to the user if he wants to continue
echo -e "************************************************************"
echo -e "*     Change the roles of servers in high availability     *"
echo -e "*\e[41m WARNING-WARNING-WARNING-WARNING-WARNING-WARNING-WARNING  \e[0m*"
echo -e "*All calls in progress will be lost and the system will be *"
echo -e "*     be in an unavailable state for a few seconds.        *"
echo -e "************************************************************"

#Perform a loop until the users confirm if wants to proceed or not
while [[ \$perform_bascul != yes && \$perform_bascul != no ]]; do
        read -p "Are you sure to switch from \$host_master to \$host_standby? (yes,no) > " perform_bascul
done

if [[ "\${perform_bascul}" = "yes" ]]; then
        #Unstandby both nodes
        pcs cluster unstandby \$host_master
        pcs cluster unstandby \$host_standby

        #Do a loop per resource
        pcs status resources | grep "^s.*s(.*):s.*" | awk '{print \$1}' | while read -r resource ; do
                #Skip moving the virutal_ip resource, it will be moved at the end
                if [[ "\${resource}" != "virtual_ip" ]]; then
                        echo "Moving \${resource} from \${host_master} to \${host_standby}"
                        pcs resource move ${resource} \${host_standby}
                fi
        done

        sleep 5 && pcs cluster standby \$host_master & #Standby current Master node after five seconds
        sleep 20 && pcs cluster unstandby \$host_master & #Automatically Unstandby current Master node after$

        #Move the Virtual IP resource to standby node
        echo "Moving virutal_ip from \${host_master} to \${host_standby}"
        pcs resource move virtual_ip \${host_standby}

        #End the script
        echo "Becoming \${host_standby} to Master"
        progress-bar 10
        echo "Done"
else
        echo "Nothing to do, bye, bye"
fi

sleep 5
role
EOF
chmod +x /usr/local/bin/bascul
scp /usr/local/bin/bascul root@$ip_standby:/usr/local/bin/bascul
ssh root@$ip_standby 'chmod +x /usr/local/bin/bascul'
echo -e "*** Done Step 16 ***"
echo -e "16"	> step.txt

vitalpbx_create_role:
echo -e "************************************************************"
echo -e "*         Creating VitalPBX Cluster role Command           *"
echo -e "************************************************************"
cat > /usr/local/bin/role << EOF
#!/bin/bash
# This code is the property of VitalPBX LLC Company
# License: Proprietary
# Date: 30-Jul-2020
# Show the Role of Server.
#Bash Colour Codes
green="\033[00;32m"
txtrst="\033[00;0m"
if [ -f /etc/redhat-release ]; then
        linux_ver=\`cat /etc/redhat-release\`
        vitalpbx_ver=\`rpm -qi vitalpbx |awk -F: '/^Version/ {print \$2}'\`
        vitalpbx_release=\`rpm -qi vitalpbx |awk -F: '/^Release/ {print \$2}'\`
elif [ -f /etc/debian_version ]; then
        linux_ver="Debian "\`cat /etc/debian_version\`
        vitalpbx_ver=\`dpkg -l vitalpbx |awk '/ombutel/ {print \$3}'\`
else
        linux_ver=""
        vitalpbx_ver=""
        vitalpbx_release=""
fi
vpbx_version="\${vitalpbx_ver}-\${vitalpbx_release}"
asterisk_version=\`rpm -q --qf "%{VERSION}" asterisk\`
server_master=\`pcs status resources | awk 'NR==1 {print \$4}'\`
host=\`hostname\`
if [[ "\${server_master}" = "\${host}" ]]; then
        server_mode="Master"
else
		server_mode="Standby"
fi
logo='
 _    _ _           _ ______ ______ _    _
| |  | (_)_        | (_____ (____  \ \  / /
| |  | |_| |_  ____| |_____) )___)  ) \/ /
 \ \/ /| |  _)/ _  | |  ____/  __  ( )  (
  \  / | | |_( ( | | | |    | |__)  ) /\ \\
   \/  |_|\___)_||_|_|_|    |______/_/  \_\\
'
echo -e "
\${green}
\${logo}
\${txtrst}
 Role           : \$server_mode
 Version        : \${vpbx_version//[[:space:]]}
 Asterisk       : \${asterisk_version}
 Linux Version  : \${linux_ver}
 Welcome to     : \`hostname\`
 Uptime         : \`uptime | grep -ohe 'up .*' | sed 's/up //g' | awk -F "," '{print \$1}'\`
 Load           : \`uptime | grep -ohe 'load average[s:][: ].*' | awk '{ print "Last Minute: " \$3" Last 5 Minutes: "\$4" Last 15 Minutes: "\$5 }'\`
 Users          : \`uptime | grep -ohe '[0-9.*] user[s,]'\`
 IP Address     : \${green}\`ip addr | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | xargs\`\${txtrst}
 Clock          :\`timedatectl | sed -n '/Local time/ s/^[ \t]*Local time:\(.*$\)/\1/p'\`
 NTP Sync.      :\`timedatectl |awk -F: '/NTP sync/ {print \$2}'\`
"
echo -e ""
echo -e "************************************************************"
echo -e "*                  Servers Status                          *"
echo -e "************************************************************"
echo -e "Master"
pcs status resources
echo -e ""
echo -e "Servers Status"
pcs cluster pcsd-status
EOF
chmod +x /usr/local/bin/role
scp /usr/local/bin/role root@$ip_standby:/usr/local/bin/role
ssh root@$ip_standby 'chmod +x /usr/local/bin/role'
echo -e "*** Done Step 17 ***"
echo -e "17"	> step.txt

ceate_welcome_message:
echo -e "************************************************************"
echo -e "*              Creating Welcome message                    *"
echo -e "************************************************************"
/bin/cp -rf /usr/local/bin/role /etc/profile.d/vitalwelcome.sh
chmod 755 /etc/profile.d/vitalwelcome.sh
echo -e "*** Done ***"
scp /etc/profile.d/vitalwelcome.sh root@$ip_standby:/etc/profile.d/vitalwelcome.sh
ssh root@$ip_standby "chmod 755 /etc/profile.d/vitalwelcome.sh"
echo -e "*** Done Step 18 ***"
echo -e "18"	> step.txt

ceate_maridb_fix_sync:
echo -e "************************************************************"
echo -e "*              Creating MariaDB Fix Sync                   *"
echo -e "************************************************************"
cat > /usr/local/bin/mariadbfix << EOF
#!/bin/bash
# This code is the property of VitalPBX LLC Company
# License: Proprietary
# Date: 30-Sep-2022
# Create the script to repair MariaDB synchronization.
# Normalize settings
cat > /etc/my.cnf.d/server.cnf << EOF
#
# These groups are read by MariaDB server.
# Use it for options that only the server (but not clients) should see
#
# See the examples of server my.cnf files in /usr/share/mysql/
#
# this is read by the standalone daemon and embedded servers
[server]
# this is only for the mysqld standalone daemon
[mysqld]
#
# * Galera-related settings
#
[galera]
# Mandatory settings
#wsrep_on=ON
#wsrep_provider=
#wsrep_cluster_address=
#binlog_format=row
#default_storage_engine=InnoDB
#innodb_autoinc_lock_mode=2
#
# Allow server to accept connections on all interfaces.
#
#bind-address=0.0.0.0
#
# Optional setting
#wsrep_slave_threads=1
#innodb_flush_log_at_trx_commit=0
# this is only for embedded server
[embedded]
EOF
scp /etc/my.cnf.d/server.cnf root@$ip_standby:/etc/my.cnf.d/server.cnf
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "RESET SLAVE;"
systemctl restart mariadb
ssh root@$ip_standby 'mysql -uroot -e "STOP SLAVE;"'
ssh root@$ip_standby 'mysql -uroot -e "RESET SLAVE;"'
ssh root@$ip_standby "systemctl restart mariadb"
# Create sync again
echo -e "************************************************************"
echo -e "*                Create mariadb replica                    *"
echo -e "************************************************************"
#Remove anonymous user from MySQL
mysql -uroot -e "DELETE FROM mysql.user WHERE User='';"
#Configuration of the First Master Server (Master-1)
cat > /etc/my.cnf.d/vitalpbx.cnf << EOF
[mysqld]
server-id=1
log-bin=mysql-bin
report_host = master1

innodb_buffer_pool_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 64M
innodb_log_buffer_size = 64M
bulk_insert_buffer_size = 64M
max_allowed_packet = 64M
EOF
systemctl restart mariadb
#Create a new user on the Master-1
mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* to vitalpbx_replica@'%' IDENTIFIED BY 'vitalpbx_replica';"
mysql -uroot -e "FLUSH PRIVILEGES;"
mysql -uroot -e "FLUSH TABLES WITH READ LOCK;"
#Get bin_log on Master-1
file_server_1=`mysql -uroot -e "show master status" | awk 'NR==2 {print $1}'`
position_server_1=`mysql -uroot -e "show master status" | awk 'NR==2 {print $2}'`

#Now on the Master-1 server, do a dump of the database MySQL and import it to Master-2
mysqldump -u root --all-databases > all_databases.sql
scp all_databases.sql root@$ip_standby:/tmp/all_databases.sql
cat > /tmp/mysqldump.sh << EOF
#!/bin/bash
mysql mysql -u root <  /tmp/all_databases.sql 
EOF
scp /tmp/mysqldump.sh root@$ip_standby:/tmp/mysqldump.sh
ssh root@$ip_standby "chmod +x /tmp/mysqldump.sh"
ssh root@$ip_standby "/tmp/./mysqldump.sh"

#Configuration of the Second Master Server (Master-2)
cat > /tmp/vitalpbx.cnf << EOF
[mysqld]
server-id = 2
log-bin=mysql-bin
report_host = master2

innodb_buffer_pool_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_log_file_size = 64M
innodb_log_buffer_size = 64M
bulk_insert_buffer_size = 64M
max_allowed_packet = 64M
EOF
scp /tmp/vitalpbx.cnf root@$ip_standby:/etc/my.cnf.d/vitalpbx.cnf
ssh root@$ip_standby "systemctl restart mariadb"
#Create a new user on the Master-2
cat > /tmp/grand.sh << EOF
#!/bin/bash
mysql -uroot -e "GRANT REPLICATION SLAVE ON *.* to vitalpbx_replica@'%' IDENTIFIED BY 'vitalpbx_replica';"
mysql -uroot -e "FLUSH PRIVILEGES;"
mysql -uroot -e "FLUSH TABLES WITH READ LOCK;"
EOF
scp /tmp/grand.sh root@$ip_standby:/tmp/grand.sh
ssh root@$ip_standby "chmod +x /tmp/grand.sh"
ssh root@$ip_standby "/tmp/./grand.sh"
#Get bin_log on Master-2
file_server_2=`ssh root@$ip_standby 'mysql -uroot -e "show master status;"' | awk 'NR==2 {print $1}'`
position_server_2=`ssh root@$ip_standby 'mysql -uroot -e "show master status;"' | awk 'NR==2 {print $2}'`
#Stop the slave, add Master-1 to the Master-2 and start slave
cat > /tmp/change.sh << EOF
#!/bin/bash
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='$ip_master', MASTER_USER='vitalpbx_replica', MASTER_PASSWORD='vitalpbx_replica', MASTER_LOG_FILE='$file_server_1', MASTER_LOG_POS=$position_server_1;"
mysql -uroot -e "START SLAVE;"
EOF
scp /tmp/change.sh root@$ip_standby:/tmp/change.sh
ssh root@$ip_standby "chmod +x /tmp/change.sh"
ssh root@$ip_standby "/tmp/./change.sh"

#Connect to Master-1 and follow the same steps
mysql -uroot -e "STOP SLAVE;"
mysql -uroot -e "CHANGE MASTER TO MASTER_HOST='$ip_standby', MASTER_USER='vitalpbx_replica', MASTER_PASSWORD='vitalpbx_replica', MASTER_LOG_FILE='$file_server_2', MASTER_LOG_POS=$position_server_2;"
mysql -uroot -e "START SLAVE;"
EOF
echo -e "*** Done Step 19 END ***"
echo -e "19"	> step.txt

vitalpbx_cluster_ok:
echo -e "************************************************************"
echo -e "*                VitalPBX Cluster OK                       *"
echo -e "*    Don't worry if you still see the status in Stop       *"
echo -e "*  sometimes you have to wait about 30 seconds for it to   *"
echo -e "*                 restart completely                       *"
echo -e "*         after 30 seconds run the command: role           *"
echo -e "************************************************************"
sleep 20
role
