FROM docker.io/matomo:5.7.1-fpm-alpine

LABEL org.opencontainers.image.description="Custom Matomo image based on official fpm-alpine" \
      org.opencontainers.image.version="5.7.1" \
      org.opencontainers.image.title="matomo" \
      org.opencontainers.image.documentation="https://github.com/eea/eea.docker.matomo/blob/master/Readme.md" \
      org.opencontainers.image.vendor="EEA"

COPY patch/github-pr-22071/*.js /usr/src/matomo/
COPY patch/github-pr-22071/js/*.js /usr/src/matomo/js/
COPY logos/ /usr/src/matomo/misc/user/

RUN chown 1001:1001 /usr/src/matomo/misc/user/*.png
RUN chown 1001:1001 /usr/src/matomo/matomo.js /usr/src/matomo/piwik.js /usr/src/matomo/js/piwik.js /usr/src/matomo/js/piwik.min.js

COPY run_* /usr/bin/
COPY matomo_entra_sync.php /

RUN chmod +x /matomo_entra_sync.php \
    /usr/bin/run_*

# disable cron
RUN rm -f /usr/sbin/crond
RUN ln -sf /bin/true /usr/sbin/crond

EXPOSE 9000

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]
