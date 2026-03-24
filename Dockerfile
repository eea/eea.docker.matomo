FROM docker.io/matomo:5.7.1-fpm-alpine

LABEL org.opencontainers.image.description="Custom Matomo image based on official fpm-alpine" \
      org.opencontainers.image.version="5.7.1" \
      org.opencontainers.image.title="matomo" \
      org.opencontainers.image.documentation="https://github.com/eea/eea.docker.matomo/blob/master/Readme.md" \
      org.opencontainers.image.vendor="EEA"

#USER 1001
#
#COPY patch/github-pr-22071/ /usr/src/matomo/
#COPY logos/ /usr/src/matomo/misc/user/

#USER root

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
