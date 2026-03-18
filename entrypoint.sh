#!/bin/sh
set -euo pipefail
# set -x  # Uncomment for debugging

echo "** Starting custom Matomo setup **"

if [ -f /use_matomo_in_rancher.sh ]; then
    echo "** Running custom rancher setup **"
    /use_matomo_in_rancher.sh
fi

if [ -f /post-init.sh ]; then
    echo "** Running post-init scripts **"
    /post-init.sh
fi

exec /entrypoint.sh "$@"
