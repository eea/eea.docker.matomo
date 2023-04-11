#!/bin/bash


echo "Disable cron"

rm -f /etc/cron.d/matomo


GEOUPDATE_CRON=${GEOUPDATE_CRON:-"30 4 5 * *"}

echo "$GEOUPDATE_CRON /usr/bin/run_geoupdate.sh" > /etc/cron.d/geoupdate

crontab /etc/cron.d/geoupdate

service cron stop

echo "Add X-Forwarded-For logs for apache"

sed -i "s/LogFormat \"%h/LogFormat \"%{X-Forwarded-For}i/g" /opt/bitnami/apache/conf/httpd.conf


#fix file permissions

chown -R daemon:root /opt/bitnami/matomo
chown -R daemon:root /opt/bitnami/php

# for matomo 4.14.1
rm -rf "/opt/bitnami/matomo/.spdx-matomo.json"

