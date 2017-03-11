#!/bin/bash

# This script sets up a new host for a host on Nginx Reverse Proxy that are connected to Cloudflare.
# Based on:
# https://www.techandme.se/update-your-nginx-config-with-the-latest-ip-ranges-from-cloudflare/
# https://www.techandme.se/set-up-nginx-reverse-proxy/

# Requirements:
# 1. Ubuntu 16.04 with Nginx pre-installed (sudo apt-get install nginx -y)
# 2. Let's Encrypt

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0

# DEBUG mode
if [ $DEBUG -eq 1 ]
then
    set -e
    set -x
else
    sleep 1
fi

## DOMAIN.HOSTNAME 	= 	example.techandme
## URL 			= 	example.techandme.se
DOMAIN=example
HOSTNAME=$DOMAIN.techandme
URL=$HOSTNAME.se

# IP
APACHEHOSTIP=192.168.8.100
NGINXHOSTIP=192.168.4.201

# Ports
APACHEPORT="80"
NGINXPORT="443"

# Scripts dir
SCRIPTS=/var/scripts

# Error message 404 500 502 503 504
ERRORMSG="Down for maintenance. Please try again in a few minutes..."
SECONDS=4
REDIRECT=https://techandmedown.fsgo.se/

# CF script dir
CFDIR="/etc/nginx/sites-available/cloudflare_ip"

# SSL
EMAIL=daniel@techandme.se
SSLPATH="/etc/letsencrypt/live/$URL"
CERTNAME="fullchain.pem"
KEY="privkey.pem"
HTTPS_CONF="/etc/nginx/sites-available/$DOMAIN.conf"
DHPARAMS=$CFDIR/$HOSTNAME/$DOMAIN-dhparams.pem

# Nginx variables
upstream='$upstream'
host='$host'
remote_addr='$remote_addr'
proxy_add_x_forwarded_for='$proxy_add_x_forwarded_for'
request_uri='$request_uri'

##################################################

# Remove dirs for script
if [ -d $CFDIR/$HOSTNAME ];
then
        rm -r $CFDIR/$HOSTNAME
fi

if [ -f /etc/nginx/sites-enabled/$DOMAIN.conf ];
then 
        rm /etc/nginx/sites-enabled/$DOMAIN.conf
fi

if [ -f /etc/nginx/sites-available/$DOMAIN.conf ];
then 
        rm /etc/nginx/sites-available/$DOMAIN.conf
fi

# Create cf dir
if [ -d $CFDIR ];
then
        sleep 1
else
        mkdir $CFDIR
fi
mkdir $CFDIR/$HOSTNAME


# cloudflare-new-ip.sh
if [ -f $CFDIR/$HOSTNAME/cloudflare-new-ip.sh ];
        then
        echo "CFNEWIP exists"
else
        touch "$CFDIR/$HOSTNAME/cloudflare-new-ip.sh"
        cat << CFNEWIP > "$CFDIR/$HOSTNAME/cloudflare-new-ip.sh"
( cat $CFDIR/$HOSTNAME/nginx-$DOMAIN-before ; wget -O- https://www.cloudflare.com/ips-v4 | sed 's/.*/     	set_real_ip_from &;/' ; cat $CFDIR/$HOSTNAME/nginx-$DOMAIN-after ) > $HTTPS_CONF
CFNEWIP
fi

# Error message when server is down
cat << NGERROR > "/usr/share/nginx/html/$DOMAIN-error.html"
<!DOCTYPE html>
<html>
<head>
   <!-- HTML meta refresh URL redirection -->
   <meta http-equiv="refresh"
   content="$SECONDS; url=$REDIRECT">
</head>
<body>
   <p>$ERRORMSG</p>
</body>
</html>
NGERROR

# Nginx before
if [ -f $CFDIR/$HOSTNAME/nginx-$DOMAIN-before ];
        then
        echo "nginx-$DOMAIN-before exists"
else
        touch "$CFDIR/$HOSTNAME/nginx-$DOMAIN-before"
        cat << NGBEFORE > "$CFDIR/$HOSTNAME/nginx-$DOMAIN-before"
server {
        # Cloudflare IP that is masked by mod_real_ip

	error_page 404 500 502 503 504 /$DOMAIN-error.html;
        location = /$DOMAIN-error.html {
                root /usr/share/nginx/html;
                internal;
        }
NGBEFORE
fi

# Nginx after
if [ -f $CFDIR/$HOSTNAME/nginx-$DOMAIN-after ];
        then
        echo "nginx-$DOMAIN-after exists"
else
        touch "$CFDIR/$HOSTNAME/nginx-$DOMAIN-after"
        cat << NGAFTER > "$CFDIR/$HOSTNAME/nginx-$DOMAIN-after"

	real_ip_header     X-Forwarded-For;
        real_ip_recursive  on;

        listen $NGINXHOSTIP:$NGINXPORT ssl http2;

        ssl on;
        ssl_certificate $SSLPATH/$CERTNAME;
        ssl_certificate_key $SSLPATH/$KEY;
	ssl_dhparam $DHPARAMS;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:10m;
        ssl_stapling on;
        ssl_stapling_verify on;

        # Only use safe chiphers
	ssl_ciphers 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:AES:CAMELLIA:DES-CBC3-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!aECDH:!EDH-DSS-DES-CBC3-SHA:!EDH-RSA-DES-CBC3-SHA:!KRB5-DES-CBC3-SHA';
	ssl_prefer_server_ciphers on;
	
	# Add secure headers
	add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload";
	add_header X-Content-Type-Options nosniff;
	
        server_name $URL;
        set $upstream $APACHEHOSTIP:$APACHEPORT;

        location / {
                proxy_pass_header Authorization;
                proxy_pass http://$upstream;
		proxy_set_header X-Forwarded-Proto https;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP  $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_http_version 1.1;
                proxy_set_header Connection "";
                proxy_buffering off;
                proxy_request_buffering off;
		client_max_body_size 0;
                proxy_read_timeout  36000s;
                proxy_redirect off;
                proxy_ssl_session_reuse off;
        }
}

server {
  listen $NGINXHOSTIP:$APACHEPORT;
  server_name $URL;
  return 301 https://$URL$request_uri;
}
NGAFTER
fi

# Write new host
bash $CFDIR/$HOSTNAME/cloudflare-new-ip.sh
ln -s /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/$DOMAIN.conf

# Check which port is used and change settings accordingly
if [ $APACHEPORT -eq 443 ];then
sed -i "s|proxy_pass http://|proxy_pass https://|g" $CFDIR/$HOSTNAME/nginx-$DOMAIN-after
sed -i "s|proxy_ssl_session_reuse on|proxy_ssl_session_reuse off|g" $CFDIR/$HOSTNAME/nginx-$DOMAIN-after
fi

# Generate DHparams chifer
if [ -f $DHPARAMS ];
        then
        echo "$DHPARAMS exists"
else
        openssl dhparam -out $DHPARAMS 4096
fi

# Install letsencrypt
apt update -q2
letsencrypt --version 2> /dev/null
LE_IS_AVAILABLE=$?
if [ $LE_IS_AVAILABLE -eq 0 ]
then
    certbot --version
else
    echo "Installing letsencrypt..."
    add-apt-repository ppa:certbot/certbot -y
    apt update -q2
    apt install letsencrypt -y -q
fi

# Let's Encrypt
echo "Generating SSL certificate..."
letsencrypt certonly \
--webroot --webroot-path /usr/share/nginx/html/ \
--rsa-key-size 4096 \
--renew-by-default --email $EMAIL \
--text \
--agree-tos \
-d $URL
if [[ $? -eq 0 ]]
then
	echo "Let's Encrypt SUCCESS!"
	crontab -u root -l | { cat; echo "@weekly $SCRIPTS/letsencryptrenew.sh"; } | crontab -u root -
	service nginx start
else
	echo "Let's Encypt failed"
	service nginx start
	exit 1
fi

cat << CRONTAB > "$SCRIPTS/letsencryptrenew.sh"
DATE='$(date +%Y-%m-%d_%H:%M)'
IF='if [[ $? -eq 0 ]]'
cat << CRONTAB > "$SCRIPTS/letsencryptrenew.sh"
#!/bin/sh
letsencrypt renew >> /var/log/letsencrypt/renew.log
$IF
then
        echo "Let's Encrypt SUCCESS!"--$DATE >> /var/log/letsencrypt/cronjob.log
else
        echo "Let's Encrypt FAILED!"--$DATE >> /var/log/letsencrypt/cronjob.log
        reboot
fi
CRONTAB


chmod +x $SCRIPTS/letsencryptrenew.sh

# Enable host
service nginx configtest
if [ $? -eq 0 ]
then
	bash $CFDIR/$HOSTNAME/cloudflare-new-ip.sh
	# Put the conf in new_ip_cloudflare.sh
	sed -i "1s|^|bash $CFDIR/$HOSTNAME/cloudflare-new-ip.sh\n|" $SCRIPTS/new_ip_cloudflare.sh
	ln -s /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/$DOMAIN.conf
	service nginx restart
	echo
	echo "Host for $URL created and activated!"
	sleep 5
else
	echo "Host creation for $URL has failed."
        sleep 5
	exit 1
fi
