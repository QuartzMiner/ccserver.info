FROM openresty/openresty:xenial

RUN apt update && apt install -y libssl-dev git \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/www

RUN luarocks install lapis sqlite3complete redis-lua

WORKDIR /var/www/ccserver.info
