#!/bin/bash

if [ -d /geoupdate ] && [ -f /geoupdate/GeoLite2-City.mmdb ]; then

	cp /geoupdate/GeoLite2-City.mmdb /opt/bitnami/matomo/misc/
fi

