#!/bin/sh

# For instances where the official scripts are not started.
# You need to mount matomo's /var/www/html/config into /config and /var/www/html/plugins into /plugins

echo "Preparing the environment"
if [ ! -d "/config" ]; then
  echo "Directory /config does not exist. Either incorrect setup or running manually."
  exit 0
fi

cp -r /usr/src/matomo/* /var/www/html/
cp -r /config/* /var/www/html/config/
cp -r /plugins/* /var/www/html/plugins/

chown -R 82:82 /var/www/html
echo "Environment prepared"