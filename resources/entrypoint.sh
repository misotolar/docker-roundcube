#!/bin/bash

if ! [ -e index.php -a -e bin/installto.sh ]; then
    tar -xf /usr/src/roundcubemail.tar.gz -C . --exclude-from=/usr/src/roundcubemail.exclude --strip-components=1
else
    mkdir -p /usr/src/roundcubemail; tar -xf /usr/src/roundcubemail.tar.gz -C /usr/src/roundcubemail --exclude-from=/usr/src/roundcubemail.exclude --strip-components=1
    (cd /usr/src/roundcubemail && bin/installto.sh -y /usr/local/roundcube)
    rm -rf /usr/src/roundcubemail
    composer config --no-plugins allow-plugins.roundcube/plugin-installer true
    composer update --no-dev
fi

: "${ROUNDCUBEMAIL_DSNW:=sqlite:////usr/local/etc/roundcube/roundcube.db?mode=0646}"
: "${ROUNDCUBEMAIL_DEFAULT_HOST:=localhost}"
: "${ROUNDCUBEMAIL_DEFAULT_PORT:=143}"
: "${ROUNDCUBEMAIL_SMTP_SERVER:=localhost}"
: "${ROUNDCUBEMAIL_SMTP_PORT:=587}"
: "${ROUNDCUBEMAIL_PLUGINS:=archive,zipdownload}"
: "${ROUNDCUBEMAIL_SKIN:=elastic}"
: "${ROUNDCUBEMAIL_TEMP_DIR:=/tmp/roundcube}"

chown www-data:www-data /usr/local/etc/roundcube
chown -R www-data:www-data /usr/local/roundcube/logs
cp /usr/src/config.inc.php /usr/local/roundcube/config/config.inc.php
bin/initdb.sh --dir=/usr/local/roundcube/SQL --update || echo "Failed to initialize/update the database. Please start with an empty database and restart the container."

if [ ! -z "${ROUNDCUBEMAIL_TEMP_DIR}" ]; then
    mkdir -p ${ROUNDCUBEMAIL_TEMP_DIR} && chown www-data ${ROUNDCUBEMAIL_TEMP_DIR}
fi

: "${ROUNDCUBEMAIL_LOCALE:=en_US.UTF-8 UTF-8}"
if [ -e /usr/sbin/locale-gen ] && [ ! -z "${ROUNDCUBEMAIL_LOCALE}" ]; then
    echo "${ROUNDCUBEMAIL_LOCALE}" > /etc/locale.gen
    /usr/sbin/locale-gen
fi

exec "$@"
