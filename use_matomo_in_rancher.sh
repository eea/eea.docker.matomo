#!/bin/bash


echo "Disable cron"

rm -f /etc/cron.d/matomo


GEOUPDATE_CRON=${GEOUPDATE_CRON:-"30 4 5 * *"}

echo "$GEOUPDATE_CRON /usr/bin/run_geoupdate.sh" > /etc/cron.d/geoupdate

crontab /etc/cron.d/geoupdate

service cron stop

echo "Add X-Forwarded-For logs for apache"

sed -i "s/LogFormat \"%h/LogFormat \"%{X-Forwarded-For}i/g" /opt/bitnami/apache/conf/httpd.conf

# Apply patch from https://github.com/plone/volto/pull/5607.
# Prevent setting pk_ref cookie with an empty string; it is perceived as SQL injection attempt.

rm -rf "/opt/bitnami/matomo/matomo.js"
cp /opt/bitnami/matomo/github-pr-22071/matomo.js /opt/bitnami/matomo/
rm -rf "/opt/bitnami/matomo/piwik.js"
cp /opt/bitnami/matomo/github-pr-22071/piwik.js /opt/bitnami/matomo/
rm -rf "/opt/bitnami/matomo/js/piwik.js"
cp /opt/bitnami/matomo/github-pr-22071/js/piwik.js /opt/bitnami/matomo/js/
rm -rf "/opt/bitnami/matomo/js/piwik.min.js"
cp /opt/bitnami/matomo/github-pr-22071/js/piwik.min.js /opt/bitnami/matomo/js/

rm -rf /opt/bitnami/matomo/github-pr-22071

# fix file permissions

chown -R daemon:root /opt/bitnami/matomo
chown -R daemon:root /opt/bitnami/php

# for matomo 4.14.1
rm -rf "/opt/bitnami/matomo/.spdx-matomo.json"

