set -x

#!/bin/sh

currentdate=$(date +%Y-%m-%d_%H:%M)
backupdir=/mnt/RAID10/cfgbackup
backupname=config_backup_$currentdate

# check if backup exists
if [ -f $backupname ]
then
    # Create file
    cli -e "system config download path=$backupdir/$backupname"
    # Generate MD5
    md5 $backupdir/$backupname | awk '{print $4}' > $backupdir/md5hash_orig
else
    # Create file
    cli -e "system config download path=$backupdir/$backupname"
    # Generate MD5
    md5 $backupdir/$backupname | awk '{print $4}' > $backupdir/md5hash_new
fi


if ! diff config_backup_$currentdate config_backup_$currentdate >/dev/null 2>&1; then
echo "hej"
mv $backupname $currentdate
else
echo "not moving"
fi



######### TESTING ###########

# Compare MD5 hashes
#if ! cmp md5hash_orig md5hash_new >/dev/null 2>&1; then
#echo "hej"
#mv $backupname $currentdate
#else
#echo "not moving"
#fi

#if cmp -s "md5hash_orig" "md5hash_new"
#then
#   echo "The files match"
#else
#   echo "The files are different"
#fi
