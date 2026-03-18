#!/bin/sh

# Apply patch from https://github.com/plone/volto/pull/5607.
# Prevent setting pk_ref cookie with an empty string; it is perceived as SQL injection attempt.

whoami
id

cp -f /tmp/github-pr-22071/matomo.js /var/www/html/
cp -f /tmp/github-pr-22071/matomo.js /usr/src/matomo/

cp -f /tmp/github-pr-22071/piwik.js /var/www/html/
cp -f /tmp/github-pr-22071/piwik.js /usr/src/matomo/
cp -f /tmp/github-pr-22071/js/piwik.js /var/www/html/js/
cp -f /tmp/github-pr-22071/js/piwik.js /usr/src/matomo/js/
cp -f /tmp/github-pr-22071/js/piwik.min.js /var/www/html/js/
cp -f /tmp/github-pr-22071/js/piwik.min.js /usr/src/matomo/js/


# TODO check if necessary
# fix file permissions
#mkdir -p /opt/bitnami/tmp
#
#find /opt/bitnami/tmp \( ! -user daemon \)  -exec chown -h daemon:daemon {} +
#find /opt/bitnami/php \( ! -user daemon \)  -exec chown -h daemon:daemon {} +
#find /bitnami/matomo \( ! -user daemon \)  -exec chown -h daemon:daemon {} +
