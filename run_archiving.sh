#!/bin/bash

CONCURRENT_ARCHIVERS=${CONCURRENT_ARCHIVERS:-8}
CONCURRENT_REQS_PER_WEBSITE=${CONCURRENT_REQS_PER_WEBSITE:-6}
MATOMO_URL=${MATOMO_URL:-matomo}

if [ -n "$IDSITE" ]; then
    echo "Received parameter Id Site, will only run for the site ids $IDSITE"
    list="$IDSITE"
fi

if [ -n "$EXCLUDEIDSITE" ]; then
  echo "Received parameter Exclude Id Site $EXCLUDEIDSITE, will now try to get the list of site ids and run the archiving on it"
  list=$(/opt/bitnami/php/bin/php -q  /bitnami/matomo/console climulti:request -q --matomo-domain='matomo' --superuser 'module=API&method=SitesManager.getAllSites&filter_limit=-1'| grep idsite | awk -F'<|>' '{print $3}' |  tr '\n' ',')
  echo "Got this list of sites: $list"
fi

if [ -n "$list" ]; then     
    php /opt/bitnami/matomo/console core:archive --url=http://$MATOMO_URL --concurrent-archivers=$CONCURRENT_ARCHIVERS --concurrent-requests-per-website=$CONCURRENT_REQS_PER_WEBSITE --force-idsites="$list"  -vvv
else
    php /opt/bitnami/matomo/console core:archive --url=http://$MATOMO_URL --concurrent-archivers=$CONCURRENT_ARCHIVERS --concurrent-requests-per-website=$CONCURRENT_REQS_PER_WEBSITE -vvv
fi
