#!/bin/bash

set -x
set -e

DOMAIN=""
HOSTNAME=$DOMAIN.techandme
URL=$HOSTNAME.se

SSLPATH="/etc/letsencrypt/live/$URL"
SSLRENEW="/etc/letsencrypt/renewal/$URL.conf"
SSLARCHIVE="/etc/letsencrypt/archive/$URL"

HTML=/usr/share/nginx/html/$DOMAIN-error.html

CFDIR="/etc/nginx/sites-available/cloudflare_ip"

# Remove entry in cloudflare_new_ip.sh
sed -i "s|bash /etc/nginx/sites-available/cloudflare_ip/$HOSTNAME/cloudflare-new-ip.sh||g" /var/scripts/new_ip_cloudflare.sh

# Remove dirs for script
if [ -d $CFDIR/$HOSTNAME ];
then
        rm -rf $CFDIR/$HOSTNAME
fi

# Disable host
if [ -f /etc/nginx/sites-enabled/$DOMAIN.conf ];
then
        rm /etc/nginx/sites-enabled/$DOMAIN.conf
fi

# Remove from availiable
if [ -f /etc/nginx/sites-available/$DOMAIN.conf ];
then
        rm /etc/nginx/sites-available/$DOMAIN.conf
fi

# Remove error message
if [ -f $HTML ];
then
        rm -f $HTML
fi

# Remove all SSL certs
if [ -d $SSLPATH ];
then
        rm -rf $SSLPATH
fi

if [ -d $SSLARCHIVE ];
then
        rm -rf $SSLARCHIVE
fi

if [ -f $SSLRENEW ];
then
        rm -f $SSLRENEW
fi

