#!/bin/sh
set -e

cd /var/www

if [ ! -f "composer.json" ]; then
    echo ">>> composer.json не найден, устанавливаю Laravel во временную папку..."
    TMP_DIR=$(mktemp -d)
    composer create-project laravel/laravel "$TMP_DIR" --prefer-dist --no-interaction
    echo ">>> Переношу файлы в /var/www (не перезаписывая существующие)..."
    cp -rn "$TMP_DIR"/. .
    rm -rf "$TMP_DIR"
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
# -E + "^#?[[:space:]]*KEY=" раскомментирует строку и подставит значение,
# независимо от того, была ли она закомментирована в .env.example Laravel.
sed -i -E \
    -e "s|^#?[[:space:]]*APP_NAME=.*|APP_NAME=${APP_NAME:-Laravel}|" \
    -e "s|^#?[[:space:]]*DB_CONNECTION=.*|DB_CONNECTION=${DB_CONNECTION:-pgsql}|" \
    -e "s|^#?[[:space:]]*DB_HOST=.*|DB_HOST=db|" \
    -e "s|^#?[[:space:]]*DB_PORT=.*|DB_PORT=5432|" \
    -e "s|^#?[[:space:]]*DB_DATABASE=.*|DB_DATABASE=${DB_DATABASE}|" \
    -e "s|^#?[[:space:]]*DB_USERNAME=.*|DB_USERNAME=${DB_USERNAME}|" \
    -e "s|^#?[[:space:]]*DB_PASSWORD=.*|DB_PASSWORD=${DB_PASSWORD}|" \
    -e "s|^#?[[:space:]]*REDIS_HOST=.*|REDIS_HOST=redis|" \
    .env

if ! grep -q "^APP_KEY=base64" .env 2>/dev/null; then
    echo ">>> Генерирую APP_KEY..."
    php artisan key:generate --no-interaction
fi

echo ">>> Сбрасываю закэшированный конфиг (если был закэширован ранее)..."
php artisan config:clear --no-interaction

echo ">>> Применяю миграции БД..."
php artisan migrate --force --no-interaction

php artisan cache:clear --no-interaction || true

mkdir -p storage/framework/sessions \
         storage/framework/views \
         storage/framework/cache \
         storage/logs \
         bootstrap/cache

chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

exec "$@"