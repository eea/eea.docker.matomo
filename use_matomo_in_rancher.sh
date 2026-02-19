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

cp /tmp/github-pr-22071/matomo.js /opt/bitnami/matomo/
cp /tmp/github-pr-22071/matomo.js /bitnami/matomo/

cp /tmp/github-pr-22071/piwik.js /opt/bitnami/matomo/
cp /tmp/github-pr-22071/piwik.js /bitnami/matomo/
cp /tmp/github-pr-22071/js/piwik.js /opt/bitnami/matomo/js/
cp /tmp/github-pr-22071/js/piwik.js /bitnami/matomo/js/
cp /tmp/github-pr-22071/js/piwik.min.js /opt/bitnami/matomo/js/
cp /tmp/github-pr-22071/js/piwik.min.js /bitnami/matomo/js/

# fix file permissions
mkdir -p /opt/bitnami/tmp

find /opt/bitnami/tmp \( ! -user daemon \)  -exec chown -h daemon:daemon {} +
find /opt/bitnami/php \( ! -user daemon \)  -exec chown -h daemon:daemon {} +
find /bitnami/matomo \( ! -user daemon \)  -exec chown -h daemon:daemon {} +
