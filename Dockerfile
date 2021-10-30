FROM openresty/openresty:alpine-fat

# Dockerfile - alpine-fat
# https://github.com/openresty/docker-openresty
#
# This is an alpine-based build that keeps some build-related
# packages, has perl installed for opm, and includes luarocks.

FROM alpine:3.9

LABEL maintainer="Evan Wies <evan@neomantra.net>"

# Docker Build Arguments
ARG RESTY_VERSION="1.13.6.1"
ARG RESTY_LUAROCKS_VERSION="2.4.3"
ARG RESTY_OPENSSL_VERSION="1.0.2k"
ARG RESTY_PCRE_VERSION="8.41"
ARG RESTY_J="1"
ARG RESTY_CONFIG_OPTIONS="\
    --with-file-aio \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_geoip_module=dynamic \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_image_filter_module=dynamic \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-http_xslt_module=dynamic \
    --with-ipv6 \
    --with-mail \
    --with-mail_ssl_module \
    --with-md5-asm \
    --with-pcre-jit \
    --with-sha1-asm \
    --with-stream \
    --with-stream_ssl_module \
    --with-threads \
    --add-module=/tmp/ngx_brotli \
    "
ARG RESTY_CONFIG_OPTIONS_MORE=""

# These are not intended to be user-specified
ARG _RESTY_CONFIG_DEPS="--with-openssl=/tmp/openssl-${RESTY_OPENSSL_VERSION} --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION}"


# 1) Install apk dependencies
# 2) Download and untar OpenSSL, PCRE, and OpenResty
# 3) Build OpenResty
# 4) Cleanup

RUN apk add --no-cache --virtual .build-deps \
        curl \
        gd-dev \
        geoip-dev \
        libxslt-dev \
        perl-dev \
        readline-dev \
        zlib-dev \
    && apk add --no-cache \
        bash \
        build-base \
        curl \
        gd \
        geoip \
        git \
        libgcc \
        libxslt \
        linux-headers \
        make \
        perl \
        unzip \
        zlib \
    && cd /tmp \
    && curl -fSL https://www.openssl.org/source/openssl-${RESTY_OPENSSL_VERSION}.tar.gz -o openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && tar xzf openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
    && curl -fSL https://ftp.pcre.org/pub/pcre/pcre-${RESTY_PCRE_VERSION}.tar.gz -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && git clone https://github.com/google/ngx_brotli.git \
    && cd ngx_brotli \
    && git submodule update --init --recursive \
    && cd /tmp \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && cd /tmp \
    && rm -rf \
        openssl-${RESTY_OPENSSL_VERSION} \
        openssl-${RESTY_OPENSSL_VERSION}.tar.gz \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
    && echo curl -fSL https://github.com/luarocks/luarocks/archive/${RESTY_LUAROCKS_VERSION}.tar.gz -o luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && curl -fSL https://github.com/luarocks/luarocks/archive/${RESTY_LUAROCKS_VERSION}.tar.gz -o luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && tar xzf luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && cd luarocks-${RESTY_LUAROCKS_VERSION} \
    && ./configure \
        --prefix=/usr/local/openresty/luajit \
        --with-lua=/usr/local/openresty/luajit \
        --lua-suffix=jit-2.1.0-beta3 \
        --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 \
    && make build \
    && make install \
    && cd /tmp \
    && rm -rf luarocks-${RESTY_LUAROCKS_VERSION} luarocks-${RESTY_LUAROCKS_VERSION}.tar.gz \
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache --virtual $runDeps \
    && apk del .build-deps .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

# Add additional binaries into PATH for convenience
ENV PATH=$PATH:/usr/local/openresty/luajit/bin/:/usr/local/openresty/nginx/sbin/:/usr/local/openresty/bin/

### custom code starts here

RUN apk add --no-cache --virtual .run-deps \ 
        bash \
        curl \
        diffutils \
        grep \
        sed \
        openssl \
        tzdata \
    && apk add --no-cache --virtual .build-deps \  
        autoconf \
        automake \
        cmake \
        g++ \
        gcc \
        gd-dev \
        geoip-dev \
        gnupg \
        libc-dev \
        libxslt-dev \
        linux-headers \
        lua \
        lua-dev \
        make \
        openssl-dev \
        pcre-dev \
        perl-dev \
        tar \
        unzip \
        zip \
        zlib-dev \
    && mkdir -p /etc/resty-auto-ssl \
    && addgroup -S -g 1000 nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx -u 1000 nginx \
    && chown -R nginx:nginx /etc/resty-auto-ssl \
    && /usr/local/openresty/luajit/bin/luarocks install lua-resty-auto-ssl \
    && apk del .build-deps \
    && rm -rf /usr/local/openresty/nginx/conf/* \
    && mkdir -p /var/cache/nginx

# maybe not necessary, but changing the timezone of the machine so it's easier to read the logs
RUN cp /usr/share/zoneinfo/America/Los_Angeles /etc/localtime \
    && echo "America/Los_Angeles" > /etc/timezone

# use self signed ssl certifacte to start nginx
RUN openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj '/CN=sni-support-required-for-valid-ssl' \
    -keyout /etc/ssl/resty-auto-ssl-fallback.key \
    -out /etc/ssl/resty-auto-ssl-fallback.crt \
    && chown nginx:nginx /etc/ssl/resty-auto-ssl-fallback*

# create a new dhparam.pem file each time the image is created - this does take a while...
RUN openssl dhparam 2048 -out > /usr/local/openresty/nginx/conf/dhparam.pem \
    && chown nginx:nginx /usr/local/openresty/nginx/conf/dhparam.pem

# copy in our configuration
COPY ./conf/ /usr/local/openresty/nginx/conf/
RUN chown -R nginx:nginx /usr/local/openresty/nginx/conf

VOLUME /etc/resty-auto-ssl
VOLUME /var/www

EXPOSE 80
EXPOSE 443

CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]