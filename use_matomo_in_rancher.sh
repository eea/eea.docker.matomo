#!/bin/bash


echo "Disable cron"

rm -f /etc/cron.d/matomo

service cron stop

echo "Add X-Forwarded-For logs for apache"

sed -i "s/LogFormat \"%h/LogFormat \"%{X-Forwarded-For}i/g" /opt/bitnami/apache/conf/httpd.conf

# for matomo 4.14.1
rm -rf "/opt/bitnami/matomo/.spdx-matomo.json"

