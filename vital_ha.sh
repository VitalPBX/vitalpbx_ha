#!/bin/bash
set -e
# Authors:      Rodrigo Cuadra
#               Jose Miguel Rivera
#
# Support:      rcuadra@aplitel.com
# License:      GNU General Public License (GPL)
#
echo -e "\n"
echo -e "************************************************************"
echo -e "*  Welcome to the VitalPBX high availability installation  *"
echo -e "*                All options are mandatory                 *"
echo -e "************************************************************"

while [[ $ip_master == '' ]]
do
    read -p "IP Master......... > " ip_master 
done 

while [[ $host_master == '' ]]
do
    read -p "Host Name Master.. > " host_master 
done 

while [[ $ip_slave == '' ]]
do
    read -p "IP Slave.......... > " ip_slave 
done 

while [[ $host_slave == '' ]]
do
    read -p "Host Name Slave... > " host_slave 
done 

while [[ $ip_floating == '' ]]
do
    read -p "Floating IP....... > " ip_floating 
done 

while [[ $ip_floating_mask == '' ]]
do
    read -p "Floating IP Mask.. > " ip_floating_mask
done 

while [[ $disk == '' ]]
do
    read -p "Disk (sdax)....... > " disk 
done 

while [[ $hapassword == '' ]]
do
    read -p "hacluster password > " hapassword 
done

echo -e "************************************************************"
echo -e "*                   Check Information                      *"
echo -e "*        Make sure you have internet on both servers       *"
echo -e "************************************************************"
while [[ $veryfy_info != yes && $veryfy_info != no ]]
do
    read -p "Are you sure to continue with this settings? (yes,no) > " veryfy_info 
done

if [ "$veryfy_info" != "${answer#[YESyes]}" ] ;then
	echo -e "************************************************************"
	echo -e "*                Starting to run the scripts               *"
	echo -e "************************************************************"
else
    	exit;
fi

#Check if we have the SSH key generated
sshKeyFile=/root/.ssh/id_rsa
if [ ! -f $sshKeyFile ]; then
	ssh-keygen -f /root/.ssh/id_rsa -t rsa -N '' >/dev/null
fi

#Copy Authorization key to slave server
ssh-copy-id root@$ip_slave

echo -e "************************************************************"
echo -e "*               Creating hosts name in Master              *"
echo -e "************************************************************"
echo -e "$ip_master \t$host_master \n$ip_slave \t$host_slave" >> /etc/hosts
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*            Update Firewall in Master                     *"
echo -e "************************************************************"
firewall-cmd --permanent --add-service=high-availability
firewall-cmd --permanent --add-rich-rule="rule family="ipv4" source address="$ip_slave" port port="7789" protocol="tcp" accept"
firewall-cmd --reload
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*                   Loading drbd in Master                 *"
echo -e "************************************************************"
modprobe drbd
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*         Configure drbr resources in Master               *"
echo -e "************************************************************"
mv /etc/drbd.d/global_common.conf /etc/drbd.d/global_common.conf.orig
echo -e "global { \n\tusage-count no; \n} \ncommon { \n\tnet { \n\tprotocol C; \n\t} \n}"  > /etc/drbd.d/global_common.conf
echo -e "resource drbd0 {" 			> /etc/drbd.d/drbd0.res
echo -e "protocol C;" 				>> /etc/drbd.d/drbd0.res
echo -e "on $host_master {" 			>> /etc/drbd.d/drbd0.res
echo -e "device /dev/drbd0;" 			>> /etc/drbd.d/drbd0.res
echo -e "   	disk /dev/sda4;" 		>> /etc/drbd.d/drbd0.res
echo -e "   	address $ip_master:7789;" 	>> /etc/drbd.d/drbd0.res
echo -e "meta-disk internal;" 			>> /etc/drbd.d/drbd0.res
echo -e "}" 					>> /etc/drbd.d/drbd0.res
echo -e "on $host_slave {" 			>> /etc/drbd.d/drbd0.res
echo -e "device /dev/drbd0;" 			>> /etc/drbd.d/drbd0.res
echo -e "   	disk /dev/sda4;" 		>> /etc/drbd.d/drbd0.res
echo -e "   	address $ip_slave:7789;" 	>> /etc/drbd.d/drbd0.res
echo -e "meta-disk internal;" 			>> /etc/drbd.d/drbd0.res
echo -e "   	}" 				>> /etc/drbd.d/drbd0.res
echo -e "}" 					>> /etc/drbd.d/drbd0.res
drbdadm create-md drbd0
systemctl enable drbd
drbdadm up drbd0
drbdadm primary drbd0 --force
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*              Formating drbd disk in Master               *"
echo -e "************************************************************"
mkfs.xfs /dev/drbd0
mount /dev/drbd0 /mnt
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*        Create password for hacluster in Master           *"
echo -e "************************************************************"
echo $hapassword | passwd --stdin hacluster
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*            Starting pcsd services in Master              *"
echo -e "************************************************************"
systemctl start pcsd 
systemctl enable pcsd.service 
systemctl enable corosync.service 
systemctl enable pacemaker.service
echo -e "*** Done ***"

###### SLAVE ######
echo -e "************************************************************"
echo -e "*             Creating hosts name in Slave                 *"
echo -e "************************************************************"
ssh root@$ip_slave "echo -e '$ip_master \t$host_master' >> /etc/hosts"
ssh root@$ip_slave "echo -e '$ip_slave \t$host_slave' >> /etc/hosts"
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*              Update Firewall in Slave                    *"
echo -e "************************************************************"
ssh root@$ip_slave "firewall-cmd --permanent --add-service=high-availability"
ssh root@$ip_slave "firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="$ip_master" port port="7789" protocol="tcp" accept'"
ssh root@$ip_slave "firewall-cmd --reload"
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*                 Loading drbd in Slave                    *"
echo -e "************************************************************"
ssh root@$ip_slave 'modprobe drbd'
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*         Configure drbr resources in Slave                *"
echo -e "************************************************************"
ssh root@$ip_slave "mv /etc/drbd.d/global_common.conf /etc/drbd.d/global_common.conf.orig"
scp /etc/drbd.d/global_common.conf root@$ip_slave:/etc/drbd.d/global_common.conf
scp /etc/drbd.d/drbd0.res root@$ip_slave:/etc/drbd.d/drbd0.res
ssh root@$ip_slave 'drbdadm create-md drbd0'
ssh root@$ip_slave 'systemctl enable drbd'
ssh root@$ip_slave 'drbdadm up drbd0'
ssh root@$ip_slave 'drbdadm secondary drbd0'
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*      Install pcs, pacemaker and corosync in Slave        *"
echo -e "************************************************************"
#ssh root@$ip_slave "yum -y install corosync pacemaker pcs"
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*        Create password for hacluster in Slave            *"
echo -e "************************************************************"
ssh root@$ip_slave "echo $hapassword | passwd --stdin hacluster"
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*            Starting pcsd services in Slave               *"
echo -e "************************************************************"
ssh root@$ip_slave 'systemctl start pcsd'
ssh root@$ip_slave 'systemctl enable pcsd.service'
ssh root@$ip_slave 'systemctl enable corosync.service' 
ssh root@$ip_slave 'systemctl enable pacemaker.service'
echo -e "*** Done ***"

###### MASTER #####
echo -e "************************************************************"
echo -e "*            Server Authenticate in Master                 *"
echo -e "************************************************************"
echo $hapassword
pcs cluster auth $host_master $host_slave -u hacluster -p $hapassword
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*              Creating Cluster in Master                  *"
echo -e "************************************************************"
pcs cluster setup --name cluster_voip $host_master $host_slave
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*              Starting Cluster in Master                  *"
echo -e "************************************************************"
pcs cluster start --all
pcs cluster enable --all
pcs property set stonith-enabled=false
pcs property set no-quorum-policy=ignore
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*            Creating Floating IP in Master                *"
echo -e "************************************************************"
pcs resource create virtual_ip ocf:heartbeat:IPaddr2 ip=$ip_floating cidr_netmask=$ip_floating_mask op monitor interval=30s on-fail=restart
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*              Updating Cluster in Master                  *"
echo -e "************************************************************"
pcs cluster cib drbd_cfg
pcs cluster cib-push drbd_cfg
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*        Creating Resources for drbd in Master             *"
echo -e "************************************************************"
pcs -f drbd_cfg resource create DrbdData ocf:linbit:drbd drbd_resource=drbd0 op monitor interval=60s
pcs -f drbd_cfg resource master DrbdDataClone DrbdData master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true
pcs cluster cib-push drbd_cfg
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "* Create FILESYSTEM resource for the automated mount point *"
echo -e "************************************************************"
pcs cluster cib fs_cfg
pcs  -f fs_cfg resource create DrbdFS Filesystem device="/dev/drbd0" directory="/mnt" fstype="xfs" 
pcs  -f fs_cfg constraint colocation add DrbdFS with DrbdDataClone INFINITY with-rsc-role=Master 
pcs  -f fs_cfg constraint order promote DrbdDataClone then start DrbdFS
pcs -f fs_cfg constraint colocation add DrbdFS with virtual_ip INFINITY
pcs -f fs_cfg constraint order virtual_ip then DrbdFS
pcs cluster cib-push fs_cfg
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*    Create resource for the use of MariaDB in Master      *"
echo -e "************************************************************"
systemctl stop mariadb
systemctl disable mariadb
mkdir /mnt/mysql
mkdir /mnt/mysql/data
cd /mnt/mysql
cp -aR /var/lib/mysql/* /mnt/mysql/data
mv /etc/my.cnf /mnt/mysql/
ln -s /mnt/mysql/my.cnf /etc/
sed -i 's/var\/lib\/mysql/mnt\/mysql\/data/g' /etc/my.cnf
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*     Create resource for the use of MariaDB in Slave      *"
echo -e "************************************************************"
pcs cluster standby
ssh root@$ip_slave 'rm -rf /etc/my.cnf'
ssh root@$ip_slave 'ln -s /mnt/mysql/my.cnf /etc/'
pcs cluster unstandby
ssh root@$ip_slave 'pcs cluster standby'
ssh root@$ip_slave 'pcs cluster unstandby'

echo -e "************************************************************"
echo -e "*    Create resource for the use of MariaDB in Master      *"
echo -e "************************************************************"
pcs resource create mysql ocf:heartbeat:mysql binary="/usr/bin/mysqld_safe" config="/etc/my.cnf" datadir="/mnt/mysql/data" pid="/var/lib/mysql/mysql.pid" socket="/var/lib/mysql/mysql.sock" additional_parameters="--bind-address=0.0.0.0" op start timeout=60s op stop timeout=60s op monitor interval=20s timeout=30s on-fail=standby 
pcs cluster cib fs_cfg
pcs cluster cib-push fs_cfg
pcs -f fs_cfg constraint colocation add mysql with virtual_ip INFINITY
pcs -f fs_cfg constraint order DrbdFS then mysql
pcs cluster cib-push fs_cfg
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*            Create resource for Asterisk                  *"
echo -e "************************************************************"
service asterisk stop
systemctl disable asterisk
cd /usr/lib/ocf/resource.d/heartbeat
wget https://raw.githubusercontent.com/VitalPBX/vitalpbx_ha/master/asterisk 
chmod 755 asterisk
scp /usr/lib/ocf/resource.d/heartbeat/asterisk root@$ip_slave:/usr/lib/ocf/resource.d/heartbeat/asterisk
ssh root@$ip_slave 'chmod 755 /usr/lib/ocf/resource.d/heartbeat/asterisk'
pcs resource create asterisk ocf:heartbeat:asterisk user="root" group="root" op monitor timeout="30"
pcs cluster cib fs_cfg
pcs -f fs_cfg constraint colocation add asterisk with virtual_ip INFINITY
pcs -f fs_cfg constraint order mysql then asterisk
pcs cluster cib-push fs_cfg 
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*   Copy folders and files the DRBD partition on Master    *"
echo -e "************************************************************"
cd /mnt/
tar -zcvf var-asterisk.tgz /var/log/asterisk 
tar -zcvf var-lib-asterisk.tgz /var/lib/asterisk
tar -zcvf usr-lib64-asterisk.tgz /usr/lib64/asterisk
tar -zcvf var-spool-asterisk.tgz /var/spool/asterisk
tar -zcvf etc-asterisk.tgz /etc/asterisk

tar xvfz var-asterisk.tgz 
tar xvfz var-lib-asterisk.tgz 
tar xvfz usr-lib64-asterisk.tgz 
tar xvfz var-spool-asterisk.tgz 
tar xvfz etc-asterisk.tgz

rm -rf /var/log/asterisk 
rm -rf /var/lib/asterisk 
rm -rf /usr/lib64/asterisk/ 
rm -rf /var/spool/asterisk/ 
rm -rf /etc/asterisk 

ln -s /mnt/var/log/asterisk /var/log/asterisk 
ln -s /mnt/var/lib/asterisk /var/lib/asterisk 
ln -s /mnt/usr/lib64/asterisk /usr/lib64/asterisk
ln -s /mnt/var/spool/asterisk /var/spool/asterisk
ln -s /mnt/etc/asterisk /etc/asterisk
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*           Configure symbolic links on Slave              *"
echo -e "************************************************************"
ssh root@$ip_slave 'rm -rf /var/log/asterisk'
ssh root@$ip_slave 'rm -rf /var/lib/asterisk'
ssh root@$ip_slave 'rm -rf /usr/lib64/asterisk/'
ssh root@$ip_slave 'rm -rf /var/spool/asterisk/'
ssh root@$ip_slave 'rm -rf /etc/asterisk'

ssh root@$ip_slave 'ln -s /mnt/var/log/asterisk /var/log/asterisk'
ssh root@$ip_slave 'ln -s /mnt/var/lib/asterisk /var/lib/asterisk'
ssh root@$ip_slave 'ln -s /mnt/usr/lib64/asterisk /usr/lib64/asterisk'
ssh root@$ip_slave 'ln -s /mnt/var/spool/asterisk /var/spool/asterisk'
ssh root@$ip_slave 'ln -s /mnt/etc/asterisk /etc/asterisk'
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*                    VitalPBX Service                      *"
echo -e "************************************************************"
service vpbx-monitor stop
systemctl disable vpbx-monitor
pcs resource create vpbx-monitor service:vpbx-monitor op monitor interval=30s
pcs cluster cib fs_cfg
pcs -f fs_cfg constraint colocation add vpbx-monitor with virtual_ip INFINITY
pcs -f fs_cfg constraint order asterisk then vpbx-monitor
pcs cluster cib-push fs_cfg
echo -e "*** Done ***"

echo -e "************************************************************"
echo -e "*                VitalPBX Cluster OK                       *"
echo -e "************************************************************"
sleep 5
pcs status resources
echo -e "*** Done ***"