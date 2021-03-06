FROM php:7.3-zts-alpine AS build-parallel
RUN apk update && \
    apk add --no-cache $PHPIZE_DEPS git
RUN git clone https://github.com/krakjoe/parallel
WORKDIR /parallel
RUN phpize
RUN ./configure
RUN make install
RUN EXTENSION_DIR=`php-config --extension-dir 2>/dev/null` && \
    cp "$EXTENSION_DIR/parallel.so" /parallel.so
RUN sha256sum /parallel.so

FROM php:7.3-zts-alpine AS build-uv
RUN apk update && \
    apk add --no-cache $PHPIZE_DEPS git libuv-dev
RUN git clone https://github.com/bwoebi/php-uv
WORKDIR /php-uv
RUN phpize
RUN ./configure
RUN make install
RUN EXTENSION_DIR=`php-config --extension-dir 2>/dev/null` && \
    cp "$EXTENSION_DIR/uv.so" /uv.so
RUN sha256sum /uv.so

FROM php:7.3-zts-alpine
COPY --from=build-parallel /parallel.so /parallel.so
COPY --from=build-uv /uv.so /uv.so
RUN EXTENSION_DIR=`php-config --extension-dir 2>/dev/null` && \
	mv /*.so "$EXTENSION_DIR/" && \
	apk add \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        gmp-dev \
        zlib-dev \
        icu-dev \
        postgresql-dev \
        libzip-dev \
        libuv-dev \
        make \
        git \
        openssh-client \
        bash \
        coreutils \
        procps \
    && docker-php-ext-install -j$(nproc) iconv \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install -j$(nproc) pcntl \
    && docker-php-ext-install -j$(nproc) pgsql \
    && docker-php-ext-install -j$(nproc) pdo \
    && docker-php-ext-install -j$(nproc) intl \
    && docker-php-ext-install -j$(nproc) pdo_pgsql \
    && docker-php-ext-install -j$(nproc) bcmath \
    && docker-php-ext-install -j$(nproc) zip \
    && docker-php-ext-install -j$(nproc) gmp \
    && docker-php-ext-enable parallel \
    && docker-php-ext-enable uv \
    && curl --silent --fail --location --retry 3 --output /tmp/installer.php --url https://raw.githubusercontent.com/composer/getcomposer.org/cb19f2aa3aeaa2006c0cd69a7ef011eb31463067/web/installer \
    && php -r " \
        \$signature = '48e3236262b34d30969dca3c37281b3b4bbe3221bda826ac6a9a62d6444cdb0dcd0615698a5cbe587c3f0fe57a54d8f5'; \
        \$hash = hash('sha384', file_get_contents('/tmp/installer.php')); \
        if (!hash_equals(\$signature, \$hash)) { \
          unlink('/tmp/installer.php'); \
          echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
          exit(1); \
        }" \
    && php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer \
    && composer --ansi --version --no-interaction \
    && rm -f /tmp/installer.php