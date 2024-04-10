FROM eeacms/matomo:4.15.1-1
 
COPY use_matomo_in_rancher.sh /
COPY patch /opt/bitnami/matomo/
