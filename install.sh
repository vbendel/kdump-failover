#!/bin/sh

if [ "$EUID" -ne 0 ]; then
		echo "This script requires root priviledges. Please sun with 'sudo' or as root user."
		exit -1
fi

systemd=$( pidof systemd >/dev/null 2>/dev/null; echo $? )
if [ $systemd -eq 0 ]; then 
                echo "Detected init system: systemd"
else
                echo "Detected init system: sysV init"
fi

workdir=$(pwd)

if [ ! -f $workdir/kdump-failover-config-generator.sh ]; then
		echo "File missing: ./kdump-failover-config-generator.sh"
		exit -2
fi

if [ ! -f $workdir/kdump-post-local-failover.sh ]; then
		echo "File missing: ./kdump-post-local-failover.sh"
		exit -2
fi

if [ ! $systemd ]; then
	if [ ! -f $workdir/kdump-failover.service ]; then
			echo "File missing: ./kdump-failover.service"
			exit -2
	fi
else
	if [ ! -f $workdir/kdump-failover.init ]; then
			echo "File missing: ./kdump-failover.init"
            exit -2
    fi
fi

if  [ ! -f $workdir/init_kdump-failover.conf ]; then
        echo "File missing: ./init_kdump-failover.conf"
        exit -2
fi


cp $workdir/init_kdump-failover.conf /etc/kdump-failover.conf

cp $workdir/kdump-failover-config-generator.sh /usr/bin/kdump-failover-config-generator.sh
ln -s -T /usr/bin/kdump-failover-config-generator.sh /usr/bin/kdump-failover-config-generator

mkdir -p /var/crash/scripts/
cp $workdir/kdump-post-local-failover.sh /var/crash/scripts/kdump-post-local-failover.sh

if [ $systemd -eq 0 ]; then 
	cp $workdir/kdump-failover.service /usr/lib/systemd/system/kdump-failover.service
else
	cp $workdir/kdump-failover.init /etc/init.d/kdump-failover
	chkconfig --add kdump-failover
fi

echo "Done! .. Now you can start/enable the \"kdump-failover\" service."
echo "Also don't forget to restart kdump.service as needed. ;)"

exit 0
