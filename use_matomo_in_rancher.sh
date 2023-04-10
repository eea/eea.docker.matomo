#!/bin/bash


echo "Disable cron"

rm -f /etc/cron.d/matomo

service cron stop

echo "Add X-Forwarded-For logs for apache"

sed -i "s/LogFormat \"%h/LogFormat \"%{X-Forwarded-For}i/g" /opt/bitnami/apache/conf/httpd.conf


