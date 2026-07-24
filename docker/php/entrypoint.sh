#!/bin/sh
set -e

cd /var/www

if [ ! -f "composer.json" ]; then
    echo ">>> composer.json не найден, устанавливаю Laravel..."
    composer create-project laravel/laravel . --prefer-dist --no-interaction
fi

if [ ! -f "vendor/autoload.php" ]; then
    echo ">>> vendor/autoload.php не найден, выполняю composer install..."
    composer install --no-interaction --prefer-dist
fi

if [ ! -f ".env" ]; then
    echo ">>> .env не найден, копирую из .env.example..."
    cp .env.example .env
fi

echo ">>> Синхронизирую .env с переменными окружения..."
sed -i \
    -e "s|^APP_NAME=.*|APP_NAME=${APP_NAME:-Laravel}|" \
    -e "s|^DB_CONNECTION=.*|DB_CONNECTION=${DB_CONNECTION:-pgsql}|" \
    -e "s|^DB_HOST=.*|DB_HOST=db|" \
    -e "s|^DB_PORT=.*|DB_PORT=5432|" \
    -e "s|^DB_DATABASE=.*|DB_DATABASE=${DB_DATABASE}|" \
    -e "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USERNAME}|" \
    -e "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASSWORD}|" \
    -e "s|^REDIS_HOST=.*|REDIS_HOST=redis|" \
    .env

if ! grep -q "^APP_KEY=base64" .env 2>/dev/null; then
    echo ">>> Генерирую APP_KEY..."
    php artisan key:generate --no-interaction
fi

mkdir -p storage/framework/sessions \
         storage/framework/views \
         storage/framework/cache \
         storage/logs \
         bootstrap/cache

chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

exec "$@"