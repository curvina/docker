ARG PHP_VERSION=7.4
ARG NGINX_VERSION=1.19
ARG APP_ENV=production

FROM php:${PHP_VERSION}-fpm-alpine AS php_fpm

#############
## PHP-FPM ##
#############

RUN apk add --no-cache --update \
        acl \
        fcgi \
    ;

RUN set -eux; \
    ln -s $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini; \
    cat <<MISC_INI > $PHP_INI_DIR/conf.d/zz-misc.ini
date.timezone=UTC
short_open_tag=Off
MISC_INI
    cat <<SECURITY_INI > $PHP_INI_DIR/conf.d/zz-security.ini \
session.auto_start=Off
SECURITY_INI
    cat <<PERF_DEFAULT_INI > $PHP_INI_DIR/conf.d/zz-perf-default.ini
;https://symfony.com/doc/current/performance.html
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.memory_consumption=256
realpath_cache_size=4096K
realpath_cache_ttl=600
PERF_DEFAULT_INI
    mkdir $PHP_INI_DIR/available-conf; \
    cat <<PERF_PROD_INI > $PHP_INI_DIR/available-conf/zz-perf.ini-production
opcache.validate_timestamps=0
apc.enable_cli=1
PERF_PROD_INI
    cat <<PERF_DEV_INI > $PHP_INI_DIR/available-conf/zz-perf.ini-development
opcache.validate_timestamps=1
apc.enable_cli=0
PERF_DEV_INI
    ln -s $PHP_INI_DIR/available-conf/zz-perf.ini-production $PHP_INI_DIR/conf.d/zz-perf-env.ini

VOLUME /var/run/php

RUN set -eux; \
    cat <<FPM_CONF > /usr/local/etc/php-fpm.d/zz-docker.conf
[global]
daemonize = no

[www]
listen = /var/run/php/php-fpm.sock
listen.mode = 0666
ping.path = /ping
FPM_CONF

RUN set -eux; \
    cat <<HEALCHECK > /usr/local/bin/healthcheck
#!/bin/sh
set -e

export SCRIPT_NAME=/ping
export SCRIPT_FILENAME=/ping
export REQUEST_METHOD=GET

if cgi-fcgi -bind -connect /var/run/php/php-fpm.sock; then
    exit 0
fi

exit 1
HEALCHECK
    chmod +x /usr/local/bin/healthcheck

HEALTHCHECK --interval=10s --timeout=3s --retries=3 CMD ["healthcheck"]

COPY docker/php-fpm/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

##############
## Composer ##
##############

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="${PATH}:/root/.composer/vendor/bin"

#############
## Laravel ##
#############

WORKDIR /app

COPY composer.json composer.lock ./
RUN set -eux; \
    composer install --prefer-dist --no-dev --no-scripts --no-progress; \
    composer clear-cache

COPY artisan .env ./
COPY app app/
COPY bootstrap bootstrap/
COPY config config/
COPY database database/
COPY public public/
COPY resources resources/
COPY routes routes/

VOLUME /app/storage

RUN set -eux; \
    chmod +x artisan; sync; \
    php artisan optimize; \
    composer dump-autoload --classmap-authoritative --no-dev

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]

FROM nginx:${NGINX_VERSION}-alpine AS nginx

COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
