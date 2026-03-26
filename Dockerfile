FROM docker.io/matomo:5.8.0-fpm-alpine

LABEL org.opencontainers.image.description="Custom Matomo image based on official fpm-alpine" \
      org.opencontainers.image.version="5.7.1" \
      org.opencontainers.image.title="matomo" \
      org.opencontainers.image.documentation="https://github.com/eea/eea.docker.matomo/blob/master/Readme.md" \
      org.opencontainers.image.vendor="EEA"

COPY patch/github-pr-22071/ /usr/src/matomo/
COPY logos/* /usr/src/matomo/misc/user/
COPY run_* /usr/bin/
COPY matomo_entra_sync.php /

RUN set -eux; \
    chown 1001:1001 /usr/src/matomo/misc/user/*.png; \
    chown 1001:1001 \
        /usr/src/matomo/matomo.js \
        /usr/src/matomo/piwik.js \
        /usr/src/matomo/js/piwik.js \
        /usr/src/matomo/js/piwik.min.js; \
    \
    update_manifest() { \
        FILE="$1"; \
        KEY="$2"; \
        SIZE=$(stat -c%s "$FILE"); \
        HASH=$(sha256sum "$FILE" | awk '{print $1}'); \
        sed -i "s|\"$KEY\" => array([^)]*)|\"$KEY\" => array(\"$SIZE\", \"$HASH\")|g" /usr/src/matomo/config/manifest.inc.php; \
    }; \
    \
    update_manifest "/usr/src/matomo/js/piwik.js" "js/piwik.js"; \
    update_manifest "/usr/src/matomo/piwik.js" "piwik.js"; \
    update_manifest "/usr/src/matomo/js/piwik.min.js" "js/piwik.min.js"; \
    update_manifest "/usr/src/matomo/matomo.js" "matomo.js"; \
    \
    chmod +x /matomo_entra_sync.php; \
    chmod +x /usr/bin/run_*; \
    \
    rm -f /usr/sbin/crond; \
    ln -sf /bin/true /usr/sbin/crond


