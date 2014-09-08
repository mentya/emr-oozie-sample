#!/bin/bash

function jsonval {
	temp=`echo $json | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w $prop | cut -d ":" -f 2`
	echo ${temp##*|}
}

json=`cat /mnt/var/lib/info/instance.json`
prop='isMaster'
ismaster=`jsonval`

set -e

if [[ "$ismaster" -eq "true" ]]
then
	# download files
	cd /tmp
	wget --no-check-certificate https://github.com/davideanastasia/emr-oozie-sample/releases/download/v4.0.1/oozie-4.0.1-distro.tar.gz
	wget http://extjs.com/deploy/ext-2.2.zip
	chmod a+x ext-2.2.zip
	
	#
	# unpack oozie and setup
	#
	sudo mkdir -p /opt
	cd /opt
	sudo tar -zxvf /tmp/oozie-4.0.1-distro.tar.gz
	cd /opt/oozie-4.0.1/
	
	# add config
	sudo grep -v '/configuration' /opt/oozie-4.0.1/conf/oozie-site.xml > /tmp/oozie-site.xml.new

	sudo echo '<property><name>hadoop.proxyuser.hadoop.hosts</name><value>*</value></property>' >> /tmp/oozie-site.xml.new
	sudo echo '<property><name>hadoop.proxyuser.hadoop.groups</name><value>*</value></property>' >> /tmp/oozie-site.xml.new
	sudo echo '</configuration>' >> /tmp/oozie-site.xml.new
	
	sudo mv /opt/oozie-4.0.1/conf/oozie-site.xml /opt/oozie-4.0.1/conf/oozie-site.xml.orig
	sudo mv /tmp/oozie-site.xml.new /opt/oozie-4.0.1/conf/oozie-site.xml

	# set user to hadoop:hadoop
 	sudo chown -R hadoop:hadoop /opt/oozie-4.0.1
	
	# create sym link in the home folder
	sudo -u hadoop ln -s /opt/oozie-4.0.1 /home/hadoop/oozie

	# make oozie read the hadoop configuration files
	sudo -u hadoop mv /home/hadoop/oozie/conf/hadoop-conf /home/hadoop/oozie/conf/hadoop-conf-bkp
	sudo -u hadoop ln -s /home/hadoop/etc/hadoop/ /home/hadoop/oozie/conf/hadoop-conf
	
	# copy (EMR?) jars to oozie webapp
	sudo -u hadoop mkdir -p /opt/oozie-4.0.1/libext
	sudo -u hadoop cp /tmp/ext-2.2.zip /opt/oozie-4.0.1/libext/
	sudo -u hadoop cp /opt/oozie-4.0.1/libtools/* /opt/oozie-4.0.1/libext/
	sudo -u hadoop cp /home/hadoop/share/hadoop/common/lib/hadoop-lzo-0.4.20-SNAPSHOT.jar /opt/oozie-4.0.1/libext/
	
	sudo -u hadoop /opt/oozie-4.0.1/bin/oozie-setup.sh prepare-war
	
	# create sharelib (not strictly necessary)
	# sudo -u hadoop /opt/oozie-4.0.1//bin/oozie-setup.sh sharelib create -fs hdfs://`hostname`:9000
	
	# create DB
	sudo -u hadoop /opt/oozie-4.0.1/bin/oozie-setup.sh db create -run

	# startup oozie 
	sudo -u hadoop /opt/oozie-4.0.1/bin/oozied.sh start
else
	echo "not master... skipping"
fi
