FROM php:8.4-fpm-alpine3.23

LABEL org.opencontainers.image.url="https://github.com/misotolar/docker-roundcube"
LABEL org.opencontainers.image.description="Roundcube Webmail Alpine Linux FPM image"
LABEL org.opencontainers.image.authors="Michal Sotolar <michal@sotolar.com>"

ENV ROUNDCUBE_VERSION=1.6.12
ARG SHA256=180b485dfde1898b2f1ac8046b34063898d263d7605fc64c41e230e3418f2a30
ADD https://github.com/roundcube/roundcubemail/releases/download/$ROUNDCUBE_VERSION/roundcubemail-$ROUNDCUBE_VERSION-complete.tar.gz /usr/src/roundcubemail.tar.gz

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

ENV TZ=UTC
ENV PHP_FPM_POOL=www
ENV PHP_FPM_LISTEN=0.0.0.0:9000
ENV PHP_MAX_EXECUTION_TIME=300
ENV PHP_MEMORY_LIMIT=64M
ENV PHP_UPLOAD_LIMIT=2048K

WORKDIR /usr/local/roundcube

RUN set -ex; \
    apk add --no-cache \
        bash \
        coreutils \
        git \
        gettext-envsubst \
        icu-data-full \
        rsync \
        tzdata; \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        freetype-dev \
        icu-dev \
        imagemagick-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libwebp-dev \
        libxpm-dev \
        libzip-dev \
        libtool \
        openldap-dev \
        postgresql-dev \
        sqlite-dev \
    ; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp --with-xpm; \
    docker-php-ext-configure ldap; \
    docker-php-ext-install \
        exif \
        gd \
        intl \
        ldap \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        zip \
    ; \
    pecl install imagick redis; \
    docker-php-ext-enable imagick opcache redis; \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache --virtual .roundcube-rundeps imagemagick $runDeps; \
    apk del --no-network .build-deps; \
    { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
        echo 'opcache.fast_shutdown=1'; \
    } > $PHP_INI_DIR/conf.d/opcache-recommended.ini; \
    \
    { \
        echo 'session.cookie_httponly=1'; \
        echo 'session.use_strict_mode=1'; \
    } > $PHP_INI_DIR/conf.d/session-strict.ini; \
    \
    { \
        echo 'session.auto_start=off'; \
        echo 'session.gc_maxlifetime=21600'; \
        echo 'session.gc_divisor=500'; \
        echo 'session.gc_probability=1'; \
        echo 'output_buffering=on'; \
        echo 'zlib.output_compression=off'; \
    } > $PHP_INI_DIR/conf.d/roundcube-defaults.ini; \
    \
    { \
        echo 'expose_php=off'; \
        echo 'allow_url_fopen=off'; \
        echo 'date.timezone=${TZ}'; \
        echo 'max_input_vars=10000'; \
        echo 'memory_limit=${PHP_MEMORY_LIMIT}'; \
        echo 'post_max_size=${PHP_UPLOAD_LIMIT}'; \
        echo 'upload_max_filesize=${PHP_UPLOAD_LIMIT}'; \
        echo 'max_execution_time=${PHP_MAX_EXECUTION_TIME}'; \
    } > $PHP_INI_DIR/conf.d/roundcube-misc.ini; \
    echo "$SHA256 */usr/src/roundcubemail.tar.gz" | sha256sum -c -; \
    rm -rf \
        /usr/src/php.tar.xz \
        /usr/src/php.tar.xz.asc \
        /var/cache/apk/* \
        /var/tmp/* \
        /tmp/*;

COPY resources/php-fpm.conf /usr/local/etc/php-fpm.conf.docker
COPY resources/config.inc.php /usr/src/config.inc.php
COPY resources/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY resources/exclude.txt /usr/src/roundcubemail.exclude

VOLUME /usr/local/roundcube

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
