#!/bin/bash

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Run hotfix for LoginSaml
/patch_saml.sh

# Load Matomo environment
. /opt/bitnami/scripts/matomo-env.sh

# Load libraries
. /opt/bitnami/scripts/libbitnami.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libwebserver.sh

print_welcome_page

#############################################
#old code
#if [[ "$1" = "/opt/bitnami/scripts/$(web_server_type)/run.sh" || "$1" = "/opt/bitnami/scripts/nginx-php-fpm/run.sh" || "$1" = "/opt/bitnami/scripts/matomo/run.sh" ]]; then
#############################################
#add support for our run scripts
############################################
if [[ "$1" = "/opt/bitnami/scripts/$(web_server_type)/run.sh" || "$1" = "/opt/bitnami/scripts/nginx-php-fpm/run.sh" || "$1" = "/opt/bitnami/scripts/matomo/run.sh" || "$1" == run_* ]]; then
    info "** Starting Matomo setup **"
    /opt/bitnami/scripts/"$(web_server_type)"/setup.sh
    /opt/bitnami/scripts/php/setup.sh
    /opt/bitnami/scripts/mysql-client/setup.sh
    /opt/bitnami/scripts/matomo/setup.sh

    ##################################
    /use_matomo_in_rancher.sh
    ##################################


    /post-init.sh
    info "** Matomo setup finished! **"
fi

echo ""
exec "$@"
