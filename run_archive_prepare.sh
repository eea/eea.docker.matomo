#!/bin/sh

if [ ! -d "/config" ]; then
  echo "Directory /config does not exist"
  exit 0
fi

cp -r /usr/src/matomo/* /var/www/html/
cp -r /config/* /var/www/html/config/
cp -r /plugins/* /var/www/html/plugins/

chown -R 82:82 /var/www/html
