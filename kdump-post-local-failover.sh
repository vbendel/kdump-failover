#!/bin/sh

## General Information
# 
# This script is supposed to be hooked as kdump-post script.
# In case the primary vmcore collection fails, this script mounts a specified local
# filesystem and collects a vmcore there. (hence the name - failover)
#
# It is primarily meant to be used as a backup collection when the primary is over network,
# so in case there is any problem with net, a vmcore gets still captued.
#
# It's different from kdump's 'dump_to_rootfs' default_action in that you can specify
# a dedicated device/filesystem to dump the failover vmcore to.
#
# Author: Vratislav Bendel <vbendel@redhat.com> @2020
# VERSION: 1.0
#

#
# Format without spaces
#
date=$(date "+%F-%T")

#
# These variables (+ $dumppath) are being configured by kdump-failover-config-generator.sh
# Still can be configured manually though.
#
lvm=""
vglv=""
localdev=""
backup_type=""

#
# Dump directory options. 
#
dumppath=""
dumpdir="${date}-fallback" 

#
# Log controls
#
log_to_file=1
logfile="/kdump-post.log"

#
# Error numbers:
#
EDUMPDIR=-1
EMAKEDUMP=-2

#
# Since we are running in second/Kdump kernel, we have limited commands (no tee).
# This function serves to print messages both to console and a file, which can be 
# optionally copied to /sysroot
#
echo_log ()
{
	echo $1
	if [ $log_to_file -eq 1 ]; then
		echo $1 >> $logfile
	fi
}

echo_log "Kdump post script initiated at ${date}..."

## IMPORTANT!!! uncomment this if -- this was a testing version
#if [ $1 -ne 0 ]; then
        echo_log "Collection to primary target failed. Falling back to local dump-disk."

	# LVMs may need to get actived for device mapper to create the block device files
	if [ $lvm -eq 1 ]; then
		
		# Set DM_DISABLE_UDEV to avoid deadlock
		export DM_DISABLE_UDEV=1 
		lvm lvchange -a y -vv $vglv 
		
		# Get the correct block device filename
		#minor=$(lvm lvdisplay $vglv | grep Block | cut -d ':' -f 2)
		localdev="/dev/$vglv"	 
	fi

	# Mount the local backup target device
        mkdir -p /tmp/dump-mnt
        mount -t $backup_type $localdev /tmp/dump-mnt

	# Create dump directory
	mkdir /tmp/dump-mnt$dumppath/$dumpdir
	if [ $? -ne 0 ]; then
		echo_log "Failed to create dump directory /tmp/dump-mnt$dumppath/$dumpdir, dumppath=$dumppath, dumpdir=$dumpdir"
		exit $EDUMPDIR
	fi

	# Dump it
	makedumpfile -l --message-level 1 -d 31 /proc/vmcore /tmp/dump-mnt$dumppath/$dumpdir/vmcore-incomplete

	# Check success
	if [ $? -ne 0 ]; then
		echo_log "Fallback dump failed... proceeding with default action."
		#cp $logfile /sysroot/$logfile	# see FIXME at the end

		exit $EMAKEDUMP
		# This should proceed with the kdump.conf default action
	fi

	# Rename on success 
	mv /tmp/dump-mnt$dumppath/$dumpdir/vmcore-incomplete /tmp/dump-mnt$dumppath/$dumpdir/vmcore

	echo_log "Fallback collection success."

#else

#    echo_log "Primary collection successfull, nothing to do..."

#fi

# FIXME: The first-kernel rootfs should be mounted on /sysroot,
# but in case it isn't maybe we should put this into some 'if'

# CURRENTLY DISABLED: 
# cp $logfile /sysroot/$logfile

echo_log "Proceeding with default action."

exit 0

