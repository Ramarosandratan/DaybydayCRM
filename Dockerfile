FROM php:7.3-fpm

LABEL maintainer="Casper Bottelet <cbottelet@gmail.com>"

# Installation des dépendances en une seule couche pour réduire la taille de l'image
RUN apt-get update && apt-get install -y --no-install-recommends \
    mariadb-client \
    libmemcached-dev \
    libpq-dev \
    libzip-dev \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libbz2-dev \
    cron \
    nginx \
    nano \
    python3 \
    python3-pip \
    curl \
    gnupg \
    git \
    && pip3 install awscli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Installation et configuration de Node.js et Yarn
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Installation des extensions PHP en regroupant les commandes
RUN docker-php-ext-install bcmath zip bz2 mbstring pdo pdo_mysql pcntl \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd \
    && pecl channel-update pecl.php.net \
    && pecl install apcu mcrypt-1.0.2 memcached \
    && docker-php-ext-enable apcu mcrypt memcached

# Installation de Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Configuration de Nginx
COPY .docker/nginx/nginx.conf /etc/nginx/nginx.conf

# Création de l'utilisateur daybyday avec le bon UID
RUN useradd -u 1000 -ms /bin/bash daybyday

# Configuration des permissions
RUN chown -R daybyday:www-data /run \
    && chown -R daybyday:www-data /var/lib/nginx \
    && chown -R daybyday:www-data /var/log/nginx

WORKDIR /var/www/html

# Copie du code de l'application et installation des dépendances
COPY --chown=daybyday:www-data . /var/www/html

# Installation des dépendances et build des assets
RUN npm install --pure-lockfile --ignore-engines \
    && npm run prod \
    && rm -rf node_modules \
    && chmod 0777 ./bootstrap/cache -R \
    && chmod 0777 ./storage/* -R

EXPOSE 80 443

# Script de démarrage
CMD composer install --no-ansi --no-dev --no-interaction --optimize-autoloader && php-fpm -D && nginx -g "daemon off;"