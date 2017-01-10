#!/bin/bash

TODAY=`date +"%Y%m%d"`
OLD=`date -d "1 days ago" +"%Y%m%d"`
OLD2=`date -d "11 days ago" +"%Y%m%d"`
UPLOAD_DIR="/var/ocdata/daniel/files/Projekt/GITHUB_MAIL"
# Makefile --allow-root
JSON1="./node_modules/bower/bin/bower install"
JSON2="./node_modules/bower/bin/bower install --allow-root"
MAILDIR=/tmp

cd $MAILDIR

# Clone Mail master
git clone https://github.com/owncloud/mail.git

# Install PHP/JS Dependencies
cd mail
#rm composer.lock
#wget https://patch-diff.githubusercontent.com/raw/owncloud/mail/pull/1558.patch
#git apply 1558.patch
sed -i "s|${JSON1}|${JSON2}|g" Makefile
make
cd ..

# Move .zip archive to the shared folder in ownCloud
mv $MAILDIR/mail/build/artifacts/appstore/mail.tar.gz $UPLOAD_DIR/owncloud_mail_nightly_build_$TODAY.tar.gz

# Cleanup
mv $UPLOAD_DIR/owncloud_mail_nightly_build_$OLD.tar.gz $UPLOAD_DIR/OLD_NIGHTLIES_10_DAYS/owncloud_mail_nightly_build_$OLD.tar.gz
rm $UPLOAD_DIR/OLD_NIGHTLIES_10_DAYS/owncloud_mail_nightly_build_$OLD2.tar.gz
rm -rf $MAILDIR/mail

# Set correct permissions to zip file
bash /var/scripts/setup_secure_permissions_owncloud.sh

# Rescan files with .occ
sudo -u www-data php /var/www/owncloud/occ  files:scan -p daniel/files/Projekt/GITHUB_MAIL/

exit 0
