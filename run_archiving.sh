#!/bin/bash

CONCURRENT_ARCHIVERS=${CONCURRENT_ARCHIVERS:-8}
CONCURRENT_REQS_PER_WEBSITE=${CONCURRENT_REQS_PER_WEBSITE:-6}
MATOMO_URL=${MATOMO_URL:-matomo}


php /opt/bitnami/matomo/console core:archive --url=http://$MATOMO_URL --concurrent-archivers=$CONCURRENT_ARCHIVERS --concurrent-requests-per-website=$CONCURRENT_REQS_PER_WEBSITE -vvv
chown -R daemon:daemon /bitnami/matomo/tmp/templates_c/
su -s /bin/bash daemon -c "php -r 'file_get_contents(\"http://localhost/\");'"
chown -R daemon:daemon /bitnami/matomo/tmp/templates_c/

