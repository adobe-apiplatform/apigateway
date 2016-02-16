# apigateway
#
# VERSION               1.9.7.3
#
# From https://hub.docker.com/_/alpine/
#
FROM alpine:latest

RUN apk update \
    && apk add gcc tar libtool zlib jemalloc jemalloc-dev perl \ 
    make musl-dev openssl-dev pcre-dev g++ zlib-dev curl python \
    perl-test-longstring perl-list-moreutils perl-http-message \
    geoip-dev

ENV OPENRESTY_VERSION 1.9.7.3
ENV NAXSI_VERSION 0.53-2
ENV PCRE_VERSION 8.37
ENV TEST_NGINX_VERSION 0.24
ENV HMAC_LUA_VERSION 1.0.0
ENV REQUEST_VALIDATION_VERSION 1.0.1

RUN mkdir -p /tmp/api-gateway/

RUN  cd /tmp/api-gateway/ \
     && curl -L https://github.com/nbs-system/naxsi/archive/${NAXSI_VERSION}.tar.gz -o /tmp/api-gateway/naxsi-${NAXSI_VERSION}.tar.gz \
     && curl -L http://downloads.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.gz -o /tmp/api-gateway/pcre-${PCRE_VERSION}.tar.gz \
     && curl -L https://openresty.org/download/openresty-{OPENRESTY_VERSION}.tar.gz -o /tmp/api-gateway/openresty-${OPENRESTY_VERSION}.tar.gz \
     && curl -L https://github.com/adobe-apiplatform/api-gateway-request-validation/archive/${REQUEST_VALIDATION_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION}.tar.gz \
     && curl -L https://github.com/adobe-apiplatform/api-gateway-hmac/archive/${HMAC_LUA_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-hmac-${HMAC_LUA_VERSION}.tar.gz \
     && tar -xf ./openresty-${OPENRESTY_VERSION}.tar.gz \
     && tar -xf ./pcre-${PCRE_VERSION}.tar.gz \
     && tar -xf ./naxsi-${NAXSI_VERSION}.tar.gz \
     && cd /tmp/api-gateway/openresty-${OPENRESTY_VERSION} \ 
     && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
     && echo "using up to $NPROC threads" \
     && _prefix="/usr/local" \
     && _exec_prefix="$_prefix" \
     && _localstatedir="/var" \
     && _sysconfdir="/etc" \
     && _sbindir="$_exec_prefix/sbin" \
     && echo "building debugging version of the api-gateway ... " \
     && ./configure \
            --prefix=${_exec_prefix}/api-gateway \
            --sbin-path=${_sbindir}/api-gateway-debug \
            --conf-path=${_sysconfdir}/api-gateway/api-gateway.conf \
            --error-log-path=${_localstatedir}/log/api-gateway/error.log \
            --http-log-path=${_localstatedir}/log/api-gateway/access.log \
            --pid-path=${_localstatedir}/run/api-gateway.pid \
            --lock-path=${_localstatedir}/run/api-gateway.lock \
            --add-module=../naxsi-${NAXSI_VERSION}/naxsi_src/ \
            --with-pcre=../pcre-${PCRE_VERSION}/ --with-pcre-jit \
            --with-stream \
            --with-stream_ssl_module \
            --with-http_ssl_module \
            --with-http_stub_status_module \
            --with-http_realip_module \
            --with-http_addition_module \
            --with-http_sub_module \
            --with-http_dav_module \
            --with-http_geoip_module \
            --with-http_gunzip_module  \
            --with-http_gzip_static_module \
            --with-http_auth_request_module \
            --with-http_random_index_module \
            --with-http_secure_link_module \
            --with-http_degradation_module \
            --with-http_auth_request_module  \
            --with-http_v2_module \
            --with-luajit \
            --without-http_ssi_module \
            --without-http_userid_module \
            --without-http_uwsgi_module \
            --without-http_scgi_module \
            --with-debug \
            -j${NPROC} \
    && make -j${NPROC} \
    && make install \
    && echo "building regular version of the api-gateway ... " \
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
            --with-stream \
            --with-stream_ssl_module \
            --with-http_ssl_module \
            --with-http_stub_status_module \
            --with-http_realip_module \
            --with-http_addition_module \
            --with-http_sub_module \
            --with-http_dav_module \
            --with-http_geoip_module \
            --with-http_gunzip_module  \
            --with-http_gzip_static_module \
            --with-http_auth_request_module \
            --with-http_random_index_module \
            --with-http_secure_link_module \
            --with-http_degradation_module \
            --with-http_auth_request_module  \
            --with-http_v2_module \
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
         INSTALL=/tmp/api-gateway/openresty-${OPENRESTY_VERSION}/build/install \
    && echo " ... installing api-gateway-request-validation ..." \
    && tar -xf /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION} \
    && make install \
         LUA_LIB_DIR=${_exec_prefix}/api-gateway/lualib \
         INSTALL=/tmp/api-gateway/openresty-${OPENRESTY_VERSION}/build/install \
    && apk del g++ gcc make \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/api-gateway \
    && echo " ... adding Nginx Test support" \
    && curl -L https://github.com/openresty/test-nginx/archive/v${TEST_NGINX_VERSION}.tar.gz -o /usr/local/test-nginx-${TEST_NGINX_VERSION}.tar.gz \
    && cd /usr/local/ \
    && tar -xf /usr/local/test-nginx-${TEST_NGINX_VERSION}.tar.gz \
    && rm /usr/local/test-nginx-${TEST_NGINX_VERSION}.tar.gz \
    && ln -s /usr/local/sbin/api-gateway-debug /usr/local/sbin/nginx

ENV CONFIG_SUPERVISOR_VERSION initial-poc
ENV GOPATH /usr/lib/go/bin
ENV GOBIN  /usr/lib/go/bin
ENV PATH   $PATH:/usr/lib/go/bin
RUN echo " ... adding api-gateway-config-supervisor  ... " \
    && echo "http://dl-4.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk update \
    && apk add make git go \
    && mkdir -p /tmp/api-gateway \
    && curl -L https://github.com/adobe-apiplatform/api-gateway-config-supervisor/archive/${CONFIG_SUPERVISOR_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-config-supervisor-${CONFIG_SUPERVISOR_VERSION}.tar.gz \
    && cd /tmp/api-gateway \
    && tar -xf /tmp/api-gateway/api-gateway-config-supervisor-${CONFIG_SUPERVISOR_VERSION}.tar.gz \
    && mkdir -p /tmp/go \
    && mv /tmp/api-gateway/api-gateway-config-supervisor-${CONFIG_SUPERVISOR_VERSION}/* /tmp/go \
    && cd /tmp/go \
    && make setup \
    && mkdir -p /tmp/go/Godeps/_workspace \
    && ln -s /tmp/go/vendor /tmp/go/Godeps/_workspace/src \
    && mkdir -p /tmp/go-src/src/github.com/adobe-apiplatform \
    && ln -s /tmp/go /tmp/go-src/src/github.com/adobe-apiplatform/api-gateway-config-supervisor \
    && GOPATH=/tmp/go/vendor:/tmp/go-src CGO_ENABLED=0 GOOS=linux /usr/lib/go/bin/godep  go build -ldflags "-s" -a -installsuffix cgo -o api-gateway-config-supervisor ./ \
    && mv /tmp/go/api-gateway-config-supervisor /usr/local/sbin/ \

    && echo "installing rclone sync ... " \
    && go get github.com/ncw/rclone \
    && mv /usr/lib/go/bin/rclone /usr/local/sbin/ \

    && echo " cleaning up ... " \
    && rm -rf /usr/lib/go/bin/src \
    && rm -rf /tmp/go \
    && rm -rf /tmp/go-src \
    && rm -rf /usr/lib/go/bin/pkg/ \
    && rm -rf /usr/lib/go/bin/godep \
    && apk del make git go \
    && rm -rf /var/cache/apk/*

RUN echo " installing aws-cli ..." \
    && apk update \
    && apk add python \
    && apk add py-pip \
    && pip install --upgrade pip \
    && pip install awscli


COPY init.sh /etc/init-container.sh
ONBUILD COPY init.sh /etc/init-container.sh

# add the default configuration for the Gateway
COPY api-gateway-config /etc/api-gateway
RUN adduser -S nginx-api-gateway \
    && addgroup -S nginx-api-gateway
ONBUILD COPY api-gateway-config /etc/api-gateway


ENTRYPOINT ["/etc/init-container.sh"]
