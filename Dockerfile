# api-platform-box
#
# VERSION               1.9.3.1
#
# From https://hub.docker.com/_/alpine/
#
FROM alpine:latest

RUN apk update \
    && apk add gcc tar libtool zlib jemalloc jemalloc-dev perl \ 
    make musl-dev openssl-dev pcre-dev g++ zlib-dev curl

ENV OPENRESTY_VERSION 1.9.3.1
ENV NAXSI_VERSION 0.53-2
ENV PCRE_VERSION 8.37
ENV HMAC_LUA_VERSION 1.0.0
ENV REQUEST_VALIDATION_VERSION 1.0.1

RUN mkdir -p /tmp/api-gateway/
ADD https://github.com/nbs-system/naxsi/archive/${NAXSI_VERSION}.tar.gz /tmp/api-gateway/naxsi-${NAXSI_VERSION}.tar.gz
ADD http://downloads.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz /tmp/api-gateway/prce-${PCRE_VERSION}.tar.gz
ADD http://openresty.org/download/ngx_openresty-${OPENRESTY_VERSION}.tar.gz /tmp/api-gateway/ngx_openresty-${OPENRESTY_VERSION}.tar.gz
ADD https://github.com/apiplatform/api-gateway-request-validation/archive/${REQUEST_VALIDATION_VERSION}.tar.gz /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION}.tar.gz
ADD https://github.com/apiplatform/api-gateway-hmac/archive/${HMAC_LUA_VERSION}.tar.gz /tmp/api-gateway/api-gateway-hmac-${HMAC_LUA_VERSION}.tar.gz

RUN  cd /tmp/api-gateway/ \ 
     && tar -xf ./ngx_openresty-${OPENRESTY_VERSION}.tar.gz \
     && tar -xf ./prce-${PCRE_VERSION}.tar.gz \
     && tar -xf ./naxsi-${NAXSI_VERSION}.tar.gz \
     && cd /tmp/api-gateway/ngx_openresty-${OPENRESTY_VERSION} \ 
     && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
     && echo "using up to $NPROC threads" \
     && _prefix="/usr/local" \
     && _exec_prefix="$_prefix" \
     && _localstatedir="/var" \
     && _sysconfdir="/etc" \
     && _sbindir="$_exec_prefix/sbin" \
     && ./configure \
            --prefix=${_exec_prefix}/api-gateway \
            --sbin-path=${_sbindir}/api-gateway \
            --conf-path=${_sysconfdir}/api-gateway/api-gateway.conf \
            --error-log-path=${_localstatedir}/log/api-gateway/error.log \
            --http-log-path=${_localstatedir}/log/api-gateway/access.log \
            --pid-path=${_localstatedir}/run/api-gateway.pid \
            --lock-path=${_localstatedir}/run/api-gateway.lock \
            --add-module=../naxsi-${NAXSI_VERSION}/naxsi_src/ \
            --with-pcre=../pcre-${PCRE_VERSION}/ --with-pcre-jit \
            --with-http_ssl_module \
            --with-http_stub_status_module \
            --with-luajit \
            --without-http_ssi_module \
            --without-http_userid_module \
            --without-http_uwsgi_module \
            --without-http_scgi_module \
            -j${NPROC} \
    && make -j${NPROC} \
    && make install \
    && echo " ... installing api-gateway-hmac ..." \
    && tar -xf /tmp/api-gateway/api-gateway-hmac-${HMAC_LUA_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/api-gateway-hmac-${HMAC_LUA_VERSION} \
    && make install \
         LUA_LIB_DIR=${_exec_prefix}/api-gateway/lualib \
         INSTALL=/tmp/api-gateway/ngx_openresty-${OPENRESTY_VERSION}/build/install \
    && echo " ... installing api-gateway-request-validation ..." \
    && tar -xf /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION} \
    && make install \
         LUA_LIB_DIR=${_exec_prefix}/api-gateway/lualib \
         INSTALL=/tmp/api-gateway/ngx_openresty-${OPENRESTY_VERSION}/build/install \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/api-gateway


COPY init.sh /etc/init-container.sh
ONBUILD COPY init.sh /etc/init-container.sh

# add the default configuration for the Gateway
COPY api-gateway-config /etc/api-gateway
RUN adduser -S nginx-api-gateway \
    && addgroup -S nginx-api-gateway
ONBUILD COPY api-gateway-config /etc/api-gateway


CMD ["/etc/init-container.sh"]
