#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load Matomo environment
. /opt/bitnami/scripts/matomo-env.sh

# Load libraries
. /opt/bitnami/scripts/libbitnami.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libwebserver.sh

print_welcome_page

    info "** Starting Matomo setup **"
    /opt/bitnami/scripts/"$(web_server_type)"/setup.sh
    /opt/bitnami/scripts/php/setup.sh
    /opt/bitnami/scripts/mysql-client/setup.sh
    /opt/bitnami/scripts/matomo/setup.sh
    /post-init.sh
    info "** Matomo setup finished! **"

# copied from ./rootfs/opt/bitnami/scripts/matomo/entrypoint.sh without the if check

if [ -n "$DAYS_TO_KEEP" ] && [ -n "$SITE_TO_DELETE" ]; then

    php /opt/bitnami/matomo/console core:delete-logs-data --dates 2018-01-01,$(date --date="${DAYS_TO_KEEP} days ago" +%F) --idsite ${SITE_TO_DELETE} -n

fi



