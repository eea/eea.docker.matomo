#!/bin/bash


if [ -n "$DAYS_TO_KEEP" ] && [ -n "$SITE_TO_DELETE" ]; then

    php /opt/bitnami/matomo/console core:delete-logs-data --dates 2018-01-01,$(date --date="${DAYS_TO_KEEP} days ago" +%F) --idsite ${SITE_TO_DELETE} -n

fi



