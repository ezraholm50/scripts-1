#!/bin/sh

# Tech and Me - ©2017, https://www.techandme.se/
# Author: https://github.com/enoch85

# To restore your config from the file produced in this script, go to System --> Preferences --> Browse and add this file.
# Please note that FreeNAS will reboot after you press OK! Shut down all VMs that are running before you restore anything.

currentdate=$(date +%Y-%m-%d_%H:%M)
backupdir=/mnt/RAID10/cfgbackup
backupname=config_backup_$currentdate
keepfilesfordays=30

# Check if DIRs exist
if ! [ -d $backupdir ]
then
    mkdir -p $backupdir
fi

if ! [ -d $backupdir/config ]
then
    mkdir -p $backupdir/config
fi

# Do the backup and log on error or success
if cli -e "system config download path=$backupdir/$backupname"; then
   echo "Backup success $currentdate" >> $backupdir/config/log
else
   echo "Backup FAILED $currentdate" >> $backupdir/config/log
   exit 1
fi

# Remove files older than $keepfilesfordays days
echo "Removing files older than $keepfilesfordays days"
find $backupdir -maxdepth 1 -type f -mtime +"$keepfilesfordays" | xargs rm
