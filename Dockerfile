# apigateway
#
# VERSION               1.9.7.3
#
# From https://hub.docker.com/_/alpine/
#
FROM alpine:latest

COPY submodules /tmp/api-gateway

ENV _prefix=/usr/local \
    _exec_prefix=/usr/local \
    _localstatedir=/var \
    _sysconfdir=/etc \
    _sbindir=/usr/local/sbin

# install dependencies
RUN apk update \
    && apk add musl python libcrypto1.0 libssl1.0 libstdc++ pcre zlib geoip check gawk bash curl \
# build dependencies \
    && apk add --virtual .build-deps gcc tar libtool \ 
    make musl-dev openssl-dev pcre-dev g++ zlib-dev \
    perl-test-longstring perl-list-moreutils perl-http-message \
    gcc make git 'go<1.7' \
    py-pip \
    geoip-dev \
    automake autoconf file \
    redis \
    check-dev \
    && rm -rf /var/cache/apk/* \

# Installing throttling dependencies \
&&  echo " ... adding throttling support with ZMQ and CZMQ" \
         && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1) \
         && cd /tmp/api-gateway/zeromq4-x/ \
         && ./autogen.sh \
         && ./configure --prefix=/usr \
                        --sysconfdir=${_sysconfdir} \
                        --mandir=/usr/share/man \
                        --infodir=/usr/share/info \
         && make -j${NPROC} && make install \
         && cd /tmp/api-gateway/czmq/ \
         && ./autogen.sh \
         && ./configure --prefix=/usr \
                        --sysconfdir=${_sysconfdir} \
                        --mandir=/usr/share/man \
                        --infodir=/usr/share/info \
         && make -j${NPROC} && make install \

&&   echo " ... adding Openresty, NGINX, NAXSI and PCRE" \
     && OPENRESTY_VERSION=1.9.7.3 \
     && echo "using up to $NPROC threads" \

     && curl -k -L https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar -zxf - -C /tmp/api-gateway \
     && cd /tmp/api-gateway/openresty-${OPENRESTY_VERSION} \

     && echo "        - building debugging version of the api-gateway ... " \
     && ./configure \
            --prefix=${_exec_prefix}/api-gateway \
            --sbin-path=${_sbindir}/api-gateway-debug \
            --conf-path=${_sysconfdir}/api-gateway/api-gateway.conf \
            --error-log-path=${_localstatedir}/log/api-gateway/error.log \
            --http-log-path=${_localstatedir}/log/api-gateway/access.log \
            --pid-path=${_localstatedir}/run/api-gateway.pid \
            --lock-path=${_localstatedir}/run/api-gateway.lock \
            --add-module=../naxsi/naxsi_src/ \
            --with-pcre --with-pcre-jit \
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

    && echo "        - building regular version of the api-gateway ... " \
    && ./configure \
            --prefix=${_exec_prefix}/api-gateway \
            --sbin-path=${_sbindir}/api-gateway \
            --conf-path=${_sysconfdir}/api-gateway/api-gateway.conf \
            --error-log-path=${_localstatedir}/log/api-gateway/error.log \
            --http-log-path=${_localstatedir}/log/api-gateway/access.log \
            --pid-path=${_localstatedir}/run/api-gateway.pid \
            --lock-path=${_localstatedir}/run/api-gateway.lock \
            --add-module=../naxsi/naxsi_src/ \
            --with-pcre --with-pcre-jit \
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

    && echo "        - adding Nginx Test support" \
    && cp -r /tmp/api-gateway/test-nginx/inc/* ${_prefix}/share/perl5/site_perl/ \

    && ln -s ${_sbindir}/api-gateway-debug ${_sbindir}/nginx \
    && cp /tmp/api-gateway/openresty-${OPENRESTY_VERSION}/build/install ${_prefix}/api-gateway/bin/resty-install \

&&  echo " ... installing lua-resty-http..." \
    && cd /tmp/api-gateway/lua-resty-http \
    && make install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \

&&  echo " ... installing lua-resty-iputils..." \
    && cd /tmp/api-gateway/lua-resty-iputils \
    && export LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
    && export INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && $INSTALL -d ${LUA_LIB_DIR}/resty \
    && $INSTALL lib/resty/*.lua ${LUA_LIB_DIR}/resty/ \

&&  echo " ... installing api-gateway-config-supervisor  ... " \
    && export GOPATH=/go PATH=$PATH:/go/bin \
    && mkdir -p ${GOPATH}/src/github.com/adobe-apiplatform \
    && ln -s /tmp/api-gateway/api-gateway-config-supervisor ${GOPATH}/src/github.com/adobe-apiplatform/ \
    && cd ${GOPATH}/src/github.com/adobe-apiplatform/api-gateway-config-supervisor \
    && make setup \
    && godep go build -a -o api-gateway-config-supervisor ./ \
    && mv api-gateway-config-supervisor ${_sbindir} \

&&  echo "installing rclone sync ... " \
    && go get github.com/ncw/rclone \
    && mv ${GOPATH}/bin/rclone ${_sbindir}/ \

&&  echo " ... installing aws-cli ..." \
    && pip install --upgrade pip \
    && pip install awscli \

&&  echo " ... installing api-gateway-hmac ..." \
    && cd /tmp/api-gateway/api-gateway-hmac \
    && cp -r /tmp/api-gateway/test-nginx/* ./test/resources/test-nginx/ \
    && make test install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \

&&  echo " ... installing api-gateway-cachemanager..." \
    && cd /tmp/api-gateway/api-gateway-cachemanager \
    && cp -r /tmp/api-gateway/test-nginx/* ./test/resources/test-nginx/ \
    && REDIS_SERVER=/usr/bin/redis-server make test install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && while pkill redis-server; do sleep 1; done \

&&  echo " ... installing api-gateway-aws ..." \
    && cd /tmp/api-gateway/api-gateway-aws \
    && cp -r /tmp/api-gateway/test-nginx/* ./test/resources/test-nginx/ \
    && make test install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \

&&  echo " ... installing api-gateway-request-validation ..." \
    && cd /tmp/api-gateway/api-gateway-request-validation \
    && cp -r /tmp/api-gateway/test-nginx/* ./test/resources/test-nginx/ \
    && REDIS_SERVER=/usr/bin/redis-server make test install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && while pkill redis-server; do sleep 1; done \

&&  echo " ... installing api-gateway-async-logger ..." \
    && cd /tmp/api-gateway/api-gateway-async-logger \
    && cp -r /tmp/api-gateway/test-nginx/* ./test/resources/test-nginx/ \
    && make test install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \

&&  echo " ... installing api-gateway-zmq-adaptor" \
         && cd /tmp/api-gateway/api-gateway-zmq-adaptor \
         && PREFIX=${_sbindir} make test install \

&&  echo " ... installing api-gateway-zmq-logger ..." \
        && cd /tmp/api-gateway/api-gateway-zmq-logger \
        && cp -r /tmp/api-gateway/test-nginx/* ./test/resources/test-nginx/ \
        && make test install \
             LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
             INSTALL=${_prefix}/api-gateway/bin/resty-install \

&&  echo " ... installing api-gateway-request-tracking ..." \
        && cd /tmp/api-gateway/api-gateway-request-tracking \
        && cp -r /tmp/api-gateway/test-nginx/* ./test/resources/test-nginx/ \
        && REDIS_SERVER=/usr/bin/redis-server make test install \
             LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
             INSTALL=${_prefix}/api-gateway/bin/resty-install \
	&& while pkill redis-server; do sleep 1; done \

&&  curl -L -k -s -o ${_prefix}/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
    && chmod 755 ${_prefix}/bin/jq \

&&  echo " cleaning up ... " \
    && apk del .build-deps \
    && rm -rf /tmp/api-gateway ${GOPATH} /var/cache/apk/* /usr/local/share/perl5 \

&&  adduser -S nginx-api-gateway \
    && addgroup -S nginx-api-gateway

COPY init.sh ${_sysconfdir}/init-container.sh
COPY hacky_sync.sh ${_sysconfdir}/hacky_sync.sh
ONBUILD COPY init.sh ${_sysconfdir}/init-container.sh

# add the default configuration for the Gateway
COPY api-gateway-config ${_sysconfdir}/api-gateway
ONBUILD COPY api-gateway-config ${_sysconfdir}/api-gateway


ENTRYPOINT ["/etc/init-container.sh"]
