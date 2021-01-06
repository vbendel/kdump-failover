#!/bin/sh

## General Information
# 
# This script determines dump mount points based on a specified directories.
# Then it adjusts relevant variables in kdump.conf and kdump.post script.
#
# Author: Vratislav Bendel <vbendel@redhat.com> @2020
# VERSION: 1.0
#

# Kdump failover configuration file:
#
config_file="/etc/kdump-failover.conf"

# Primary core collector command:
#
#core_collector="makedumpfile -l --message-level 1 -d 1"
core_collector=$(grep ^core_collector= $config_file | cut -d '=' -f 2)

## Kdump-post script path:
#
#kdump_post_script="/var/crash/scripts/kdump-post-local-failover.sh"
kdump_post_script=$(grep ^kdump_post_script= $config_file | cut -d '=' -f 2)

# The directories can be adjusted via following variables:
#
# Primary dump: 
#
#primary_mount="/mnt/crashdumps"
#primary_path="/vmcores"
primary_mount=$(grep ^primary_mount= $config_file | cut -d '=' -f 2)
primary_path=$(grep ^primary_path= $config_file | cut -d '=' -f 2)

# Backup dump:
#
#backup_mount="/var/backupcrash"
#backup_path="/backup-vmcores"
backup_mount=$(grep ^backup_mount= $config_file | cut -d '=' -f 2)
backup_path=$(grep ^backup_path= $config_file | cut -d '=' -f 2)

# Helper functions
#
log() {
	# TODO: Enhance this
	echo "[kdump] $1"
}

# Error codes
#
ENODIR=-1
ENOENT=-2
ENOMOUNT=-3
ERFE=-42 	# Special Error for unimplemented potential future features 


## Step 0
#
# Sanity check existence of dump targets
#

modified=$(stat /etc/kdump-failover.conf | grep Modify)
change_cookie=$(cat /etc/.kdump-failover.change_cookie 2>/dev/null)
if [ $? -ne 0 ]; then
		log "First execution - creating change cookie"
		echo "$modified" > /etc/.kdump-failover.change_cookie
elif [ "$modified" == "$change_cookie" ]; then
		log "No modifications on /etc/kdump-failover.conf - nothing to do..."
		exit 0
else 
		log "Config file /etc/kdump-failover.conf modified - re-generating config..."
		echo "$modified" > /etc/.kdump-failover.change_cookie
fi

if [ ! -d $primary_mount ]; then
	log "Directory does not exist: $primary_mount"
	exit $ENODIR
fi

if [ ! -d $primary_mount$primary_path ]; then
	log "Directory does not exist: $primary_mount$primary_path"
	exit $ENODIR
fi

if [ ! -d $backup_mount ]; then
	log "Directory does not exist: $backup_mount"
	exit $ENODIR
fi

if [ ! -d $backup_mount$backup_path ]; then
	log "Directory does not exist: $backup_mount$backup_path"
	exit $ENODIR
fi

if [ ! -f $kdump_post_script ]; then
	log "File $kdump_post_script not found"
	exit $ENOENT
fi


## Step 1 
#
# Determine dump mount points (+ fs type)
#
tmp_primary=$(mount | grep " $primary_mount ")
if [ $? -ne 0 ]; then 
	log "No specific mount on primary=$primary_mount"
	exit $ENOMOUNT
fi

tmp_backup=$(mount | grep " $backup_mount ")
if [ $? -ne 0 ]; then
        log "No specific mount on backup=$backup_mount"
        exit $ENOMOUNT
fi

## Primary
#
primary_dev=$(echo $tmp_primary | cut -d ' ' -f 1)
primary_fs_type=$(echo $tmp_primary | cut -d ' ' -f 5)

log "Primary mount [$primary_mount] is device [$primary_dev] with fs-type [$primary_fs_type]"

if [ ! $(echo primary_fs_type | grep "nfs") ]; then
	log "Truncating fs-type \"$primary_fs_type\" to \"net\" for RHEL5 kdump.conf"
	primary_fs_type="net"
fi

## Backup
#
backup_dev=$(echo $tmp_backup | cut -d ' ' -f 1)
backup_is_lvm=0
backup_fs_type=$(echo $tmp_backup | cut -d ' ' -f 5)

log "Backup mount [$backup_mount] is device [$backup_dev] with fs-type [$backup_fs_type]"

tmp_ret=$(echo $backup_dev | grep "^/dev/mapper")
if [ $? -eq 0 ]; then
	backup_is_lvm=1
	backup_dev=$(echo $backup_dev | cut -d '/' -f 4 | sed 's/-/\//') 
	log "Backup device is LVM : VG/LV [$backup_dev]"

	# The sed for backup_dev changes the 'dash' between vg-lv got from mount cmd
	# to 'slash' needed for lvm cmd. 
fi

# Add 'backslashes' to escape the slashes for the 'sed' for $kdump_post_script
backup_dev=$(echo $backup_dev | sed 's/\//\\\//g')
backup_path=$(echo $backup_path | sed 's/\//\\\//g')

## Step 2
#
# Prepare configs

workdir="/tmp/kdump_failover_setup.tmp"
mkdir $workdir 2>/dev/null

## Primary 
#
grep "^# " /etc/kdump.conf 		>  $workdir/kdump.conf.tmp # keep the comment desc.
echo "$primary_fs_type $primary_dev" 	>> $workdir/kdump.conf.tmp
echo "path $primary_path" 		>> $workdir/kdump.conf.tmp
echo "core_collector $core_collector"	>> $workdir/kdump.conf.tmp  
echo "kdump_post $kdump_post_script"	>> $workdir/kdump.conf.tmp
if [ $backup_fs_type != $primary_fs_type ]; then
	echo "extra_modules $backup_fs_type"	>> $workdir/kdump.conf.tmp 	
fi
if [ $backup_is_lvm ]; then
	echo "extra_bins $(which lvm)"	>> $workdir/kdump.conf.tmp
fi
echo "default reboot"  >> $workdir/kdump.conf.tmp

## RFE: add --verbose for debug prints

log "Generated kdump.conf:"
log "~~~debug:~~~"
cat $workdir/kdump.conf.tmp | grep -v ^#
log "~~~~~~~~~~~~"

## Backup
#
# Use 'sed' to change it in the script directly
# (it's easier that putting a config file into kdump initramfs :P)
#
echo "s/^lvm=.*$/lvm=$backup_is_lvm/" 		>  $workdir/kdump_post_script.sed
if [ $backup_is_lvm -eq 1 ]; then
	echo "s/^vglv=.*$/vglv=$backup_dev/"	>> $workdir/kdump_post_script.sed
	echo "s/^localdev=.*$/localdev=/"	>> $workdir/kdump_post_script.sed
else
        echo "s/^vglv=.*$/vglv=/"     		>> $workdir/kdump_post_script.sed
        echo "s/^localdev=.*$/localdev=$backup_dev/"	>> $workdir/kdump_post_script.sed
fi
echo "s/^backup_type=.*$/backup_type=$backup_fs_type/"	>> $workdir/kdump_post_script.sed
echo "s/^dumppath=.*$/dumppath=$backup_path/"	>> $workdir/kdump_post_script.sed

log "Generated sed file for ${kdump_post_script}:"
log "~~~debug:~~~"
cat $workdir/kdump_post_script.sed
log "~~~~~~~~~~~~"

sed -f $workdir/kdump_post_script.sed $kdump_post_script > $workdir/kdump_post_script.tmp

log "Relevant (potentially changed) lines from ${kdump_post_script}:"
log "~~~debug:~~~"
grep -e ^lvm= \
     -e ^vglv= \
     -e ^localdev= \
     -e ^backup_type= \
     -e ^dumppath= \
     $workdir/kdump_post_script.tmp
log "~~~~~~~~~~~~"

# Last non-destructive exit point (before commiting anything):
# RFE: add --dry-run 
#exit 0 


## Step 3 
#
# Save backups and Comit changes

## RFE: omit '-f' and make a cycle iteratively trying .bak1, .bak2 etc.

date=$(date "+%F-%T")

log "Saving backup .conf files with .bak\$date extension"
mv  /etc/kdump.conf /etc/kdump.conf.bak$date
mv  $kdump_post_script ${kdump_post_script}.bak$date

log "Copying generated .conf files"
cp $workdir/kdump.conf.tmp /etc/kdump.conf
cp $workdir/kdump_post_script.tmp $kdump_post_script
chmod +x $kdump_post_script

log "Finished!"
exit 0

