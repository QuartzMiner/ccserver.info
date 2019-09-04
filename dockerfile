FROM openresty/openresty:xenial

RUN apt update && apt install -y libssl-dev git \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /var/www

RUN luarocks install lapis
RUN luarocks install lsqlite3complete
RUN luarocks install redis-lua

WORKDIR /var/www/ccserver.info
