#!/bin/sh

if [ -d "/geoupdate" ] && [ -f "/geoupdate/GeoLite2-City.mmdb" ]; then
  cp /geoupdate/GeoLite2-City.mmdb /var/www/html/misc/GeoLite2-City.mmdb
fi
