FROM bitnami/matomo:5.3.2

USER root

COPY entrypoint.sh /opt/bitnami/scripts/matomo/entrypoint.sh

USER 1001
ENTRYPOINT [ "/opt/bitnami/scripts/matomo/entrypoint.sh" ]
CMD [ "/opt/bitnami/scripts/matomo/run.sh" ]


COPY patch/ /tmp/
COPY run_* /usr/bin/
COPY use_matomo_in_rancher.sh /
COPY matomo_entra_sync.php /
COPY patch_saml.sh /
