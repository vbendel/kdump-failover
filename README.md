# kdump-failover
Kdump-failover is a simple bunch of scripts + service that are made to extend kdump's functionality so that a backup target can be specified in case of primary failure. 

The reason for this project is that kdump service only supports one primary target and provides a *dump_to_rootfs* default action, but no option for a secondary non-rootfs target.

It is specifically meant to cover the use-case, when primary target is some storage over network (ex. NFS) and the backup should be some local disk/lvm, in order to still get a vmcore in case of a network failure, but when the rootfs cannot be used for such backup (for example due to limited space or any other reason).


## Components

* **kdump-post-local-failover.sh**
  * The script that is used as *kdump_post*, which simply checks whether the primary collection was succesfull or not and optionally mounts the backup devices (or disovers the lvm) and attempts to collect a vmcore to this backup target.
  * Default install location: /var/crash/scripts/
* **kdump-failover.conf**
  * Main configuration file to set the primary and backup mounts+paths and some other stuff.
  * Default install location: /etc/
* **kdump-failover-config-generator.sh**
  * Script that parses kdump-failover.conf, makes some sanity checks and optionally updates *kdump.conf* and *kdump-post-local-failover.sh* to reflect set targets.
  * Defaults install location: /usr/bin
* **kdump-failover.[service|init]**
  * Systemd service and SysV init file respecitvely, providing a service that runs before kdump.service, which practically just runs the *kdump-failover-config-generator.sh*.
  * Default install puts these to the places where systemd/sysV services live.
* **install.sh**
  * Script that places all the above files at *default install locations*. For the service it automatically checks whether you run it on a systemd or sysV init system.
  * *Note: Redundant when installed from an .rpm* 
  

## Usage

1) Install either with *install.sh* or from an *.rpm*.
2) Modify */etc/kdump-failover.conf* to reflect your desired mounts and paths. (Note that all directories must exist and the mount points must be explicit mounts - listed in *mount* output)
3) Start kdump-failover service (optionally enable it to run at boot)
4) Restart kdump service so it takes new configuration into account.

### Notes

All files are rather primitive scripts; easy to read imho. So feel free to examine them and suggest improvements. (I'm not the best bash scripter ;))

The current version 0.2 was tested (and should work) with the specific use-case that it was disegned for: primary NFS target and local LVM backup device. Tough I haven't done any thorough testing, so who knows what corner cases and bugs await.

Future plans are mainly to:
* Improve the scripts in terms of bash scripting.
* Extend functionallity to account for corner cases, fix bugs and optionally cover more **relevant** use-cases.

