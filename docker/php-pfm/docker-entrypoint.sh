#!/bin/sh
set -e

# Se esse container for chamado com -f ou --foo-bar, então executamos o php-fpm
if [ "${1#-}" != "$1" ]; then
    set -- php-fpm "$@"
fi

echo "Esperando o banco de dados ficar disponível..."
# until php /app/artisan db:sql "SELECT 1" > /dev/null 2>&1; do
#     sleep 1
# done

if [ "$1" = "php-fpm" ] || [ "$1" = "php" ] || [ "$1" = "artisan" ]; then
    PHP_INI_RECOMMENDED="$PHP_INI_DIR/php.ini-production"
    PERF_INI_RECOMMENDED="$PHP_INI_DIR/available-conf/zz-perf.ini-production"
    if [ "$APP_ENV" != "production" ]; then
        PHP_INI_RECOMMENDED="$PHP_INI_DIR/php.ini-development"
        PERF_INI_RECOMMENDED="$PHP_INI_DIR/zz-perf.ini-development"
    fi
    ln -sf "$PHP_INI_RECOMMENDED" "$PHP_INI_DIR/php.ini"
    ln -sf "$PERF_INI_RECOMMENDED" "$PHP_INI_DIR/zz-perf.ini"

    # chown -R www-data:www-data /app/storage
    # setfacl -R -m u:www-data:rwX -m u:"$(whoami)":rwX /app/storage
    # setfacl -dR -m u:www-data:rwX -m u:"$(whoami)":rwX /app/storage

    # envsubst

    # // dev
    # php artisan view:clear
    # php artisan route:clear
    # php artisan config:clear
    # php artisan clear-compiled

    # composer pra dev
fi

# php /app/artisan doctrine:ensure-production-settings
# if tem migrations
php /app/artisan migrate

exec docker-php-entrypoint "$@"
