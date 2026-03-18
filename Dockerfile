FROM docker.io/matomo:5.7.1-fpm-alpine

LABEL org.opencontainers.image.description="Custom Matomo image based on official fpm-alpine" \
      org.opencontainers.image.version="5.7.1" \
      org.opencontainers.image.title="matomo" \
      org.opencontainers.image.documentation="https://github.com/eea/eea.docker.matomo/blob/master/Readme.md" \
      org.opencontainers.image.vendor="EEA"

ENV MATOMO_CONFIG_FILE=/var/www/html/config/config.ini.php \
    PATH="/usr/local/bin:$PATH"

COPY patch/ /tmp/
COPY run_* /usr/bin/
COPY use_matomo_in_rancher.sh /
COPY matomo_entra_sync.php /

RUN chmod +x /use_matomo_in_rancher.sh \
    /matomo_entra_sync.php \
    /usr/bin/run_*

COPY entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

USER root
RUN chown -R www-data:www-data /usr/src/matomo

EXPOSE 9000

# Switch to Matomo user (same as official image)
USER www-data

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/custom-entrypoint.sh"]

# Default CMD from official image
CMD ["php-fpm"]
