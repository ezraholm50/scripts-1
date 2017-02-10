#!/bin/bash
#
## Tech and Me ## - ©2017, https://www.techandme.se/
#
# Tested on Ubuntu Server 16.04.
#
SCRIPTS=/var/scripts
mkdir -p $SCRIPTS

# ownCloud or nextcloud file?
echo
echo "Is this for owncloud or nextcloud?"
echo "Please use exact name and small letters."
echo "I use (owncloud or nextcloud):"
read CLOUD

if [ $CLOUD == "nextcloud" ]
then
sed "s|https://download.owncloud.org/community/|https://download.nextcloud.com/releases/|g" $SCRIPTS/major-versions.sh > testfile.tmp && mv testfile.tmp $SCRIPTS/major-versions.sh
sed "s|https://raw.githubusercontent.com/techandme-vm/master/static|https://raw.githubusercontent.com/nextcloud/vm/master/static|g" $SCRIPTS/major-versions.sh > testfile.tmp && mv testfile.tmp $SCRIPTS/major-versions.sh
fi
if [ $CLOUD == "owncloud" ]
then
sed "s|https://github.com/nextcloud/vm/issues|https://github.com/enoch85/scripts/issues|g" $SCRIPTS/major-versions.sh > testfile.tmp && mv testfile.tmp $SCRIPTS/major-versions.sh
fi

#---------------------------------------------------------------------------------------------------#
# Put your theme name here:
THEME_NAME=""

# Directories
HTML=/var/www
NCPATH=$HTML/$CLOUD
BACKUP=/var/CLOUD_BACKUP

#Static Values
STATIC="https://raw.githubusercontent.com/techandme-vm/master/static"
NCREPO="https://download.owncloud.org/community/"
SECURE="$SCRIPTS/setup_secure_permissions_$CLOUD.sh"
# Versions
CURRENTVERSION=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
#---------------------------------------------------------------------------------------------------#

# Must be root
[[ `id -u` -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Set secure permissions
FILE="$SECURE"
if [ -f $FILE ]
then
    echo "Script exists"
else
    mkdir -p $SCRIPTS
    wget -q $STATIC/setup_secure_permissions_$CLOUD.sh -P $SCRIPTS
    chmod +x $SECURE
fi

# Wich version?
echo "Which version do you wan to upgrade to?"
echo "Example: 8.0.16"
read NCVERSION

# Upgrade $CLOUD
echo "Checking latest released version on the download server and if it's possible to download..."
curl -s --max-time 900 $NCREPO/$CLOUD-$NCVERSION.tar.bz2 > /dev/null
if [ $? -eq 0 ]; then
    echo -e "\e[32mSUCCESS!\e[0m"
else
    echo
    echo -e "\e[91m$CLOUD $NCVERSION doesn't exist.\e[0m"
    echo "Please check available versions here: $NCREPO"
    echo
    exit 1
fi

# Disable apps
echo "Please disable all 3d party apps like contacts, calendar and such."
echo -e "\e[32m"
read -p "Press any key when all apps are disbaled..." -n1 -s
echo -e "\e[0m"

# Check if new version is larger than current version installed.
function version_gt() { local v1 v2 IFS=.; read -ra v1 <<< "$1"; read -ra v2 <<< "$2"; printf -v v1 %03d "${v1[@]}"; printf -v v2 %03d "${v2[@]}"; [[ $v1 > $v2 ]]; }
if version_gt "$NCVERSION" "$CURRENTVERSION"
then
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
    echo -e "\e[32mNew version available! Upgrade continues...\e[0m"
else
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION."
    echo "No need to upgrade, this script will exit..."
    exit 0
fi
echo "Backing up files and upgrading to $NCVERSION in 10 seconds..." 
echo "Press CTRL+C to abort."
sleep 10

# Backup data
echo "Backing up data..."
DATE=`date +%Y-%m-%d-%H%M%S`
if [ -d $BACKUP ]
then
    mkdir -p /var/NCBACKUP_OLD/$DATE
    mv $BACKUP/* /var/NCBACKUP_OLD/$DATE
    rm -R $BACKUP
    mkdir -p $BACKUP
fi
rsync -Aax $NCPATH/config $BACKUP
rsync -Aax $NCPATH/themes $BACKUP
rsync -Aax $NCPATH/apps $BACKUP
if [[ $? > 0 ]]
then
    echo "Backup was not OK. Please check $BACKUP and see if the folders are backed up properly"
    exit 1
else
    echo -e "\e[32m"
    echo "Backup OK!"
    echo -e "\e[0m"
fi
wget $NCREPO/$CLOUD-$NCVERSION.tar.bz2 -P $HTML

if [ -f $HTML/$CLOUD-$NCVERSION.tar.bz2 ]
then
    echo "$HTML/$CLOUD-$NCVERSION.tar.bz2 exists"
else
    echo "Aborting,something went wrong with the download"
    exit 1
fi

if [ -d $BACKUP/config/ ]
then
    echo "$BACKUP/config/ exists"
else
    echo "Something went wrong with backing up your old $CLOUD instance, please check in $BACKUP if config/ folder exist."
    exit 1
fi

if [ -d $BACKUP/apps/ ]
then
    echo "$BACKUP/apps/ exists"
else
    echo "Something went wrong with backing up your old $CLOUD instance, please check in $BACKUP if apps/ folder exist."
    exit 1
fi

if [ -d $BACKUP/themes/ ]
then
    echo "$BACKUP/themes/ exists"
    echo 
    echo -e "\e[32mAll files are backed up.\e[0m"
    sudo -u www-data php $NCPATH/occ maintenance:mode --on
    echo "Removing old $CLOUD instance in 5 seconds..." && sleep 5
    rm -rf $NCPATH
    tar -xjf $HTML/$CLOUD-$NCVERSION.tar.bz2 -C $HTML
    rm $HTML/$CLOUD-$NCVERSION.tar.bz2
    cp -R $BACKUP/themes $NCPATH/
    cp -R $BACKUP/config $NCPATH/
    bash $SECURE
    sudo -u www-data php $NCPATH/occ maintenance:mode --off
    sudo -u www-data php $NCPATH/occ upgrade
else
    echo "Something went wrong with backing up your old $CLOUD instance, please check in $BACKUP if the folders exist."
    exit 1
fi

# Change owner of $BACKUP folder to root
chown -R root:root $BACKUP

# Set $THEME_NAME
VALUE2="$THEME_NAME"
if grep -Fxq "$VALUE2" "$NCPATH/config/config.php"
then
    echo "Theme correct"
else
    sed -i "s|'theme' => '',|'theme' => '$THEME_NAME',|g" $NCPATH/config/config.php
    echo "Theme set"
fi

# Pretty URLs
echo "Setting RewriteBase to "/" in config.php..."
chown -R www-data:www-data $NCPATH
sudo -u www-data php $NCPATH/occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php $NCPATH/occ maintenance:update:htaccess
bash $SECURE

# Repair
sudo -u www-data php $NCPATH/occ maintenance:repair

# Cleanup un-used packages
apt autoremove -y
apt autoclean

# Update GRUB, just in case
update-grub

CURRENTVERSION_after=$(sudo -u www-data php $NCPATH/occ status | grep "versionstring" | awk '{print $3}')
if [[ "$NCVERSION" == "$CURRENTVERSION_after" ]]
then
    echo
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after."
    echo "UPGRADE SUCCESS!"
    echo "$CLOUD UPDATE success-`date +"%Y%m%d"`" >> /var/log/cronjobs_success.log
    sudo -u www-data php $NCPATH/occ status
    sudo -u www-data php $NCPATH/occ maintenance:mode --off
    echo
    echo "Thank you for using Tech and Me's updater!"
    ## Un-hash this if you want the system to reboot
    # reboot
    exit 0
else
    echo
    echo "Latest version is: $NCVERSION. Current version is: $CURRENTVERSION_after."
    sudo -u www-data php $NCPATH/occ status
    echo "UPGRADE FAILED!"
    echo "Your files are still backed up at $BACKUP. No worries!"
    echo "Please report this issue to https://github.com/nextcloud/vm/issues"
    exit 1
fi
