FROM php:8.4-fpm-alpine

ENV PHP_MEMORY_LIMIT=256M

RUN set -ex; \
	\
	apk add --no-cache --virtual .build-deps \
		$PHPIZE_DEPS \
		autoconf \
		freetype-dev \
		icu-dev \
		libjpeg-turbo-dev \
		libpng-dev \
		libzip-dev \
		openldap-dev \
		pcre-dev \
		procps \
	; \
	\
	docker-php-ext-configure gd --with-freetype --with-jpeg; \
	docker-php-ext-configure ldap; \
	docker-php-ext-install -j "$(nproc)" \
		gd \
		bcmath \
		ldap \
		mysqli \
		pdo_mysql \
		zip \
	; \
	\
# pecl will claim success even if one install fails, so we need to perform each install separately
	pecl install APCu-5.1.28; \
	pecl install redis-6.3.0; \
	\
	docker-php-ext-enable \
		apcu \
		redis \
	; \
	rm -r /tmp/pear; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .matomo-phpext-rundeps $runDeps; \
	apk del --no-network .build-deps

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=2'; \
		echo 'opcache.fast_shutdown=1'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

ENV MATOMO_VERSION 5.10.1

RUN set -ex; \
	apk add --no-cache --virtual .fetch-deps \
		gnupg \
	; \
	\
	curl -fsSL -o matomo.tar.gz \
		"https://builds.matomo.org/matomo-${MATOMO_VERSION}.tar.gz"; \
	curl -fsSL -o matomo.tar.gz.asc \
		"https://builds.matomo.org/matomo-${MATOMO_VERSION}.tar.gz.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys F529A27008477483777FC23D63BB30D0E5D2C749; \
	gpg --batch --verify matomo.tar.gz.asc matomo.tar.gz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" matomo.tar.gz.asc; \
	tar -xzf matomo.tar.gz -C /usr/src/; \
	rm matomo.tar.gz; \
	apk del .fetch-deps

COPY php.ini /usr/local/etc/php/conf.d/php-matomo.ini

COPY docker-entrypoint.sh /entrypoint.sh

# WORKDIR is /var/www/html (inherited via "FROM php")
# "/entrypoint.sh" will populate it at container startup from /usr/src/matomo
VOLUME /var/www/html

ENTRYPOINT ["/entrypoint.sh"]
CMD ["php-fpm"]

LABEL org.opencontainers.image.description="Custom Matomo image based on official fpm-alpine" \
      org.opencontainers.image.version="5.10.0" \
      org.opencontainers.image.title="matomo" \
      org.opencontainers.image.documentation="https://github.com/eea/eea.docker.matomo/blob/master/Readme.md" \
      org.opencontainers.image.vendor="EEA"

ENV PHP_MAX_EXECUTION_TIME=120
ENV PHP_MAX_INPUT_TIME=60

COPY conf.d/zz-timeouts.ini /usr/local/etc/php/conf.d/zz-timeouts.ini
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


