#!/bin/sh

currentdate=$(date +%Y-%m-%d_%H:%M)
backupdir=/mnt/RAID10/cfgbackup
backupname=config_backup_$currentdate
keepfilesfordays=30

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
