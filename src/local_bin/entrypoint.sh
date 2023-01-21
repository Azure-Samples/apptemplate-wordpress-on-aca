#!/bin/bash

# set -e

php -v

setup_wordpress(){
	if ! [ -e wp-includes/version.php ]; then
        echo "INFO: There in no wordpress, going to GIT pull...:"
        while [ -d $WORDPRESS_HOME ]
        do
            mkdir -p /home/bak
            mv $WORDPRESS_HOME /home/bak/wordpress_bak$(date +%s)            
        done
        GIT_REPO=${GIT_REPO:-https://github.com/azureappserviceoss/wordpress-azure}
	    GIT_BRANCH=${GIT_BRANCH:-linux-appservice}
	    echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
	    echo "REPO: "$GIT_REPO
	    echo "BRANCH: "$GIT_BRANCH
	    echo "INFO: ++++++++++++++++++++++++++++++++++++++++++++++++++:"
    
	    echo "INFO: Clone from "$GIT_REPO		
        git clone $GIT_REPO $WORDPRESS_HOME	&& cd $WORDPRESS_HOME
	    if [ "$GIT_BRANCH" != "master" ];then
		    echo "INFO: Checkout to "$GIT_BRANCH
		    git fetch origin
	        git branch --track $GIT_BRANCH origin/$GIT_BRANCH && git checkout $GIT_BRANCH
	    fi       
        #IF App settings of DB are exist, Use Special wp-config file.            
        if [ $DB_HOST ]; then
            echo "INFO: External Mysql is used."                
            # show_wordpress_db_config
            cp $WORDPRESS_SOURCE/wp-config.php $WORDPRESS_HOME/ && chmod 777 $WORDPRESS_HOME/wp-config.php            
        else
            echo "ERROR: External Mysql is not used, please check your Settings."
        fi               		        
    else
        echo "INFO: There is one wordpress exist, no need to GIT pull again."
    fi
	
	# Although in AZURE, we still need below chown cmd.
    chown -R nginx:nginx $WORDPRESS_HOME    
}

echo "Setup openrc ..." && openrc && touch /run/openrc/softlevel

# That wp-config.php doesn't exist means WordPress is not installed/configured yet.
if [ ! -e "$WORDPRESS_HOME/wp-config.php" ]; then
	echo "INFO: $WORDPRESS_HOME/wp-config.php not found."    
	echo "Installing WordPress for the first time ..." 
	setup_wordpress
fi

chmod 777 $WORDPRESS_SOURCE/wp-config.php

echo "Starting Redis ..."
redis-server &

#
# Remove symlinks to /home/LogFiles
#
echo "Removing symlinks to /home/LogFiles"
unlink /var/log/nginx
unlink /var/log/supervisor

test ! -d "$SUPERVISOR_LOG_DIR" && echo "INFO: $SUPERVISOR_LOG_DIR not found. creating ..." && mkdir -p "$SUPERVISOR_LOG_DIR"
test ! -d "$NGINX_LOG_DIR" && echo "INFO: Log folder for $NGINX_LOG_DIR not found. creating..." && mkdir -p "$NGINX_LOG_DIR"
test ! -e /home/50x.html && echo "INFO: 50x file not found. createing..." && cp /usr/share/nginx/html/50x.html /home/50x.html
# test -d "/home/etc/nginx" && mv /etc/nginx /etc/nginx-bak && ln -s /home/etc/nginx /etc/nginx
# test ! -d "home/etc/nginx" && mkdir -p /home/etc && mv /etc/nginx /home/etc/nginx && ln -s /home/etc/nginx /etc/nginx

echo "INFO: creating /run/php/php-fpm.sock ..."
test -e /run/php/php-fpm.sock && rm -f /run/php/php-fpm.sock
mkdir -p /run/php
touch /run/php/php-fpm.sock
chown nginx:nginx /run/php/php-fpm.sock
chmod 777 /run/php/php-fpm.sock

sed -i "s/SSH_PORT/$SSH_PORT/g" /etc/ssh/sshd_config
echo "Starting SSH ..."
echo "Starting php-fpm ..."
echo "Starting Nginx ..."

cd /usr/bin/
supervisord -c /etc/supervisord.conf
