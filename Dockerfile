# apigateway
#
# VERSION               1.9.7.3
#
# From https://hub.docker.com/_/alpine/
# alpine:3.4 if go <1.7
FROM alpine:3.8

# install dependencies
RUN apk update \
    && apk add gcc tar libtool zlib jemalloc jemalloc-dev perl \ 
    make musl-dev openssl-dev pcre-dev g++ zlib-dev curl python \
    perl-test-longstring perl-list-moreutils perl-http-message \
    geoip-dev sudo

ENV ZMQ_VERSION 4.0.5
ENV CZMQ_VERSION 2.2.0

# Installing throttling dependencies
RUN echo " ... adding throttling support with ZMQ and CZMQ" \
         && ZMQ_SHA256=e3dc99aeacd4e1e7a025f22f92afec6c381b82f0e29222d27e1256ada841e43f \
         && CZMQ_SHA256=3c95aab7434ac0a074a46217122c9f454c36befcd0b5aaa1f463aae0838dd499 \
         && apk add autoconf automake \
         && curl -sL https://github.com/zeromq/zeromq4-x/archive/v${ZMQ_VERSION}.tar.gz -o /tmp/zeromq.tar.gz \
         && echo "${ZMQ_SHA256}  /tmp/zeromq.tar.gz" | sha256sum -c - \
         && cd /tmp/ \
         && tar -xf /tmp/zeromq.tar.gz \
         && cd /tmp/zeromq*/ \
         && ./autogen.sh \
         && ./configure --prefix=/usr \
                        --sysconfdir=/etc \
                        --mandir=/usr/share/man \
                        --infodir=/usr/share/info \
         && make && make install \
         && curl -sL https://github.com/zeromq/czmq/archive/v${CZMQ_VERSION}.tar.gz -o /tmp/czmq.tar.gz \
         && echo "${CZMQ_SHA256}  /tmp/czmq.tar.gz" | sha256sum -c - \
         && cd /tmp/ \
         && tar -xf /tmp/czmq.tar.gz \
         && cd /tmp/czmq*/ \
         && ./autogen.sh \
         && ./configure --prefix=/usr \
                        --sysconfdir=/etc \
                        --mandir=/usr/share/man \
                        --infodir=/usr/share/info \
         && make && make install \
         && apk del automake autoconf \
         && rm -rf /tmp/zeromq* && rm -rf /tmp/czmq* \
         && rm -rf /var/cache/apk/*

ENV _prefix /usr/local
# openresty build
ENV OPENRESTY_VERSION 1.13.6.1
ENV PCRE_VERSION 8.37
RUN  echo " ... adding Openresty and PCRE" \
     && OPENRESTY_SHA256=d1246e6cfa81098eea56fb88693e980d3e6b8752afae686fab271519b81d696b \
     && PCRE_SHA256=19d490a714274a8c4c9d131f651489b8647cdb40a159e9fb7ce17ba99ef992ab \
     && _localstatedir=/var \
     && _sysconfdir=/etc \
     && _sbindir=${_prefix}/sbin \
     \
     && mkdir -p /tmp/api-gateway \
     && cd /tmp/api-gateway/ \
     && curl -sL https://s3.amazonaws.com/adobe-cloudops-apip-installers-ue1/3rd-party/pcre-${PCRE_VERSION}.tar.gz -o /tmp/api-gateway/pcre-${PCRE_VERSION}.tar.gz \
     && echo "${PCRE_SHA256}  /tmp/api-gateway/pcre-${PCRE_VERSION}.tar.gz" | sha256sum -c - \
     && curl -sL https://s3.amazonaws.com/adobe-cloudops-apip-installers-ue1/3rd-party/openresty-${OPENRESTY_VERSION}.tar.gz -o /tmp/api-gateway/openresty-${OPENRESTY_VERSION}.tar.gz \
     && echo "${OPENRESTY_SHA256}  /tmp/api-gateway/openresty-${OPENRESTY_VERSION}.tar.gz" | sha256sum -c - \
     && tar -zxf ./openresty-${OPENRESTY_VERSION}.tar.gz \
     && tar -zxf ./pcre-${PCRE_VERSION}.tar.gz \
     \
     && readonly NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
     && echo "using up to $NPROC threads" \
     && cd /tmp/api-gateway/openresty-${OPENRESTY_VERSION} \
     && echo "        - building debugging version of the api-gateway ... " \
     && ./configure \
            --prefix=${_prefix}/api-gateway \
            --sbin-path=${_sbindir}/api-gateway-debug \
            --conf-path=${_sysconfdir}/api-gateway/api-gateway.conf \
            --error-log-path=${_localstatedir}/log/api-gateway/error.log \
            --http-log-path=${_localstatedir}/log/api-gateway/access.log \
            --pid-path=${_localstatedir}/run/api-gateway.pid \
            --lock-path=${_localstatedir}/run/api-gateway.lock \
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
    \
    && echo "        - building regular version of the api-gateway ... " \
    && ./configure \
            --prefix=${_prefix}/api-gateway \
            --sbin-path=${_sbindir}/api-gateway \
            --conf-path=${_sysconfdir}/api-gateway/api-gateway.conf \
            --error-log-path=${_localstatedir}/log/api-gateway/error.log \
            --http-log-path=${_localstatedir}/log/api-gateway/access.log \
            --pid-path=${_localstatedir}/run/api-gateway.pid \
            --lock-path=${_localstatedir}/run/api-gateway.lock \
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
            --with-http_v2_module \
            --with-luajit \
            --without-http_ssi_module \
            --without-http_userid_module \
            --without-http_uwsgi_module \
            --without-http_scgi_module \
            -j${NPROC} \
    && make -j${NPROC} \
    && make install \
    && ln -s ${_sbindir}/api-gateway-debug ${_sbindir}/nginx \
    && cp /tmp/api-gateway/openresty-${OPENRESTY_VERSION}/build/install ${_prefix}/api-gateway/bin/resty-install \
    && apk del g++ gcc make \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/api-gateway

ENV TEST_NGINX_VERSION 0.24
RUN echo " ... adding Nginx Test support..." \
    && TEST_NGINX_SHA256=a98083e801a7a088231da1e3a5e0d3aab743f07ffc65ede48fe8a7de132db9b3 \
    && curl -sL https://github.com/openresty/test-nginx/archive/v${TEST_NGINX_VERSION}.tar.gz -o ${_prefix}/test-nginx.tar.gz \
    && echo "${TEST_NGINX_SHA256}  ${_prefix}/test-nginx.tar.gz" | sha256sum -c - \
    && cd ${_prefix} \
    && tar -xf ${_prefix}/test-nginx.tar.gz \
    && mv ${_prefix}/test-nginx-${TEST_NGINX_VERSION} ${_prefix}/test-nginx \
    && rm ${_prefix}/test-nginx.tar.gz \
    && cp -r ${_prefix}/test-nginx/inc/* /usr/local/share/perl5/site_perl/

ENV LUA_RESTY_HTTP_VERSION 0.07
RUN echo " ... installing lua-resty-http..." \
    && LUA_RESTY_HTTP_SHA256=1c6aa06c9955397c94e9c3e0c0fba4e2704e85bee77b4512fb54ae7c25d58d86 \
    && apk update \
    && apk add make \
    && mkdir -p /tmp/api-gateway \
    && curl -sL https://github.com/pintsized/lua-resty-http/archive/v${LUA_RESTY_HTTP_VERSION}.tar.gz -o /tmp/api-gateway/lua-resty-http-${LUA_RESTY_HTTP_VERSION}.tar.gz \
    && echo "${LUA_RESTY_HTTP_SHA256}  /tmp/api-gateway/lua-resty-http-${LUA_RESTY_HTTP_VERSION}.tar.gz" | sha256sum -c - \
    && tar -xf /tmp/api-gateway/lua-resty-http-${LUA_RESTY_HTTP_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/lua-resty-http-${LUA_RESTY_HTTP_VERSION} \
    && make install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && rm -rf /tmp/api-gateway

ENV LUA_RESTY_IPUTILS_VERSION 0.2.0
RUN echo " ... installing lua-resty-iputils..." \
    && LUA_RESTY_IPUTILS_SHA256=7962557ff3070154a45c5192d927b26106ec2f411fd1a98eaf770bc23189799d \
    && apk update \
    && apk add make \
    && mkdir -p /tmp/api-gateway \
    && curl -sL https://github.com/hamishforbes/lua-resty-iputils/archive/v${LUA_RESTY_IPUTILS_VERSION}.tar.gz -o /tmp/api-gateway/lua-resty-iputils-${LUA_RESTY_IPUTILS_VERSION}.tar.gz \
    && echo "${LUA_RESTY_IPUTILS_SHA256}  /tmp/api-gateway/lua-resty-iputils-${LUA_RESTY_IPUTILS_VERSION}.tar.gz" | sha256sum -c - \
    && tar -xf /tmp/api-gateway/lua-resty-iputils-${LUA_RESTY_IPUTILS_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/lua-resty-iputils-${LUA_RESTY_IPUTILS_VERSION} \
    && export LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
    && export INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && $INSTALL -d ${LUA_LIB_DIR}/resty \
    && $INSTALL lib/resty/*.lua ${LUA_LIB_DIR}/resty/ \
    && rm -rf /tmp/api-gateway

ENV CONFIG_SUPERVISOR_VERSION 1.0.3
ENV GOPATH /tmp/go
ENV GOBIN  /usr/lib/go/bin
ENV PATH   $PATH:/usr/lib/go/bin
RUN echo " ... installing api-gateway-config-supervisor  ... " \
    && CONFIG_SUPERVISOR_SHA256=9a323d93897140f3ccb384a7279335d69f5659d1d29564b21f3d056f42272bdb \
    && echo "http://dl-4.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk update \
    && apk add gcc make git 'go' \
    && mkdir -p /tmp/api-gateway /usr/local/sbin \
    && curl -sL https://github.com/adobe-apiplatform/api-gateway-config-supervisor/archive/${CONFIG_SUPERVISOR_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-config-supervisor-${CONFIG_SUPERVISOR_VERSION}.tar.gz \
    && echo "${CONFIG_SUPERVISOR_SHA256}  /tmp/api-gateway/api-gateway-config-supervisor-${CONFIG_SUPERVISOR_VERSION}.tar.gz" | sha256sum -c - \
    && cd /tmp/api-gateway \
    && tar -xf /tmp/api-gateway/api-gateway-config-supervisor-${CONFIG_SUPERVISOR_VERSION}.tar.gz \
    && mkdir -p ${GOPATH}/src/github.com/adobe-apiplatform/api-gateway-config-supervisor/ \
    && mv /tmp/api-gateway/api-gateway-config-supervisor-${CONFIG_SUPERVISOR_VERSION}/* ${GOPATH}/src/github.com/adobe-apiplatform/api-gateway-config-supervisor/ \
    && cd ${GOPATH}/src/github.com/adobe-apiplatform/api-gateway-config-supervisor/ \
    && make setup \
    && godep go build -ldflags "-s" -a -installsuffix cgo -o api-gateway-config-supervisor ./ \
    && mv ./api-gateway-config-supervisor /usr/local/sbin/ \
    \
    && echo "installing rclone sync ... skipped due to https://github.com/ncw/rclone/issues/663 ... " \
    # && go get github.com/ncw/rclone \
    # && mv /usr/lib/go/bin/rclone /usr/local/sbin/ \
    \
    && echo " cleaning up ... " \
    && rm -rf /usr/lib/go/bin/src \
    && rm -rf /tmp/go \
    && rm -rf /tmp/go-src \
    && rm -rf /usr/lib/go/bin/pkg/ \
    && rm -rf /usr/lib/go/bin/godep \
    && apk del make git go gcc \
    && rm -rf /var/cache/apk/*

RUN echo " ... installing aws-cli ..." \
    && apk update \
    && apk add python \
    && apk add py-pip \
    && pip install --upgrade pip \
    && pip install awscli

ENV HMAC_LUA_VERSION 1.0.0
RUN echo " ... installing api-gateway-hmac ..." \
    && HMAC_LUA_SHA256=53e6183cb3812418b55b9afba256f6d1f149cdd994c0c19df3bb70ac56310281 \
    && apk update \
    && apk add make perl-utils\
    && mkdir -p /tmp/api-gateway \
    && curl -sL https://github.com/adobe-apiplatform/api-gateway-hmac/archive/${HMAC_LUA_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-hmac-${HMAC_LUA_VERSION}.tar.gz \
    && echo "${HMAC_LUA_SHA256}  /tmp/api-gateway/api-gateway-hmac-${HMAC_LUA_VERSION}.tar.gz" | sha256sum -c - \
    && tar -xf /tmp/api-gateway/api-gateway-hmac-${HMAC_LUA_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/api-gateway-hmac-${HMAC_LUA_VERSION} \
    && cp -r /usr/local/test-nginx/* ./test/resources/test-nginx/ \
    && make test \
    && make install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && rm -rf /tmp/api-gateway

ENV CACHE_MANAGER_VERSION 1.0.1
RUN echo " ... installing api-gateway-cachemanager..." \
    && CACHE_MANAGER_SHA256=8d03c1b4a9b3d6ca9fcbf941c42c5795d12fe2fd3d2e58b56e33888acb993f26 \
    && apk update \
    && apk add make \
    && mkdir -p /tmp/api-gateway \
    && curl -sL https://github.com/adobe-apiplatform/api-gateway-cachemanager/archive/${CACHE_MANAGER_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-cachemanager-${CACHE_MANAGER_VERSION}.tar.gz \
    && echo "${CACHE_MANAGER_SHA256}  /tmp/api-gateway/api-gateway-cachemanager-${CACHE_MANAGER_VERSION}.tar.gz" | sha256sum -c - \
    && tar -xf /tmp/api-gateway/api-gateway-cachemanager-${CACHE_MANAGER_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/api-gateway-cachemanager-${CACHE_MANAGER_VERSION} \
    && cp -r /usr/local/test-nginx/* ./test/resources/test-nginx/ \
    # && apk update && apk add redis \
    # && REDIS_SERVER=/usr/bin/redis-server make test \
    && make install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && apk del redis \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/api-gateway

ENV AWS_VERSION 1.7.1
RUN echo " ... installing api-gateway-aws ..." \
    && AWS_SHA256=d9fadd6602e2c139d389bd64329c72c129f76ad1d1c1857c2e4a3537d01e12fe \
    && apk update \
    && apk add make \
    && mkdir -p /tmp/api-gateway \
    && curl -sL https://github.com/adobe-apiplatform/api-gateway-aws/archive/${AWS_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-aws-${AWS_VERSION}.tar.gz \
    && echo "${AWS_SHA256}  /tmp/api-gateway/api-gateway-aws-${AWS_VERSION}.tar.gz" | sha256sum -c - \
    && tar -xf /tmp/api-gateway/api-gateway-aws-${AWS_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/api-gateway-aws-${AWS_VERSION} \
    && cp -r /usr/local/test-nginx/* ./test/resources/test-nginx/ \
    # && make test \
    && make install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/api-gateway

ENV REQUEST_VALIDATION_VERSION 1.2.4
RUN echo " ... installing api-gateway-request-validation ..." \
    && REQUEST_VALIDATION_SHA256=44ebce6119b6d3e1405a1fc203d97c9cb64d4a37ee8e26e00a0eec2b5814e176 \
    && apk update \
    && apk add make \
    && mkdir -p /tmp/api-gateway \
    && curl -sL https://github.com/adobe-apiplatform/api-gateway-request-validation/archive/${REQUEST_VALIDATION_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION}.tar.gz \
    && echo "${REQUEST_VALIDATION_SHA256}  /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION}.tar.gz" | sha256sum -c - \
    && tar -xf /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/api-gateway-request-validation-${REQUEST_VALIDATION_VERSION} \
    && cp -r /usr/local/test-nginx/* ./test/resources/test-nginx/ \
    # && apk update && apk add redis \
    # && REDIS_SERVER=/usr/bin/redis-server make test \
    && make install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && apk del redis \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/api-gateway

ENV ASYNC_LOGGER_VERSION 1.0.1
RUN echo " ... installing api-gateway-async-logger ..." \
    && ASYNC_LOGGER_SHA256=de5e008d189daa619a189a8bb530ed1c58c29f8bf07903b26b818dadd4bcc8fa \
    && apk update \
    && apk add make \
    && mkdir -p /tmp/api-gateway \
    && curl -sL https://github.com/adobe-apiplatform/api-gateway-async-logger/archive/${ASYNC_LOGGER_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-async-logger-${ASYNC_LOGGER_VERSION}.tar.gz \
    && echo "${ASYNC_LOGGER_SHA256}  /tmp/api-gateway/api-gateway-async-logger-${ASYNC_LOGGER_VERSION}.tar.gz" | sha256sum -c - \
    && tar -xf /tmp/api-gateway/api-gateway-async-logger-${ASYNC_LOGGER_VERSION}.tar.gz -C /tmp/api-gateway/ \
    && cd /tmp/api-gateway/api-gateway-async-logger-${ASYNC_LOGGER_VERSION} \
    && cp -r /usr/local/test-nginx/* ./test/resources/test-nginx/ \
    # && make test \
    && make install \
            LUA_LIB_DIR=${_prefix}/api-gateway/lualib \
            INSTALL=${_prefix}/api-gateway/bin/resty-install \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/api-gateway

ENV ZMQ_ADAPTOR_VERSION 0235b04f39a480b5347411c278900e5c57874cf5
RUN echo " ... installing api-gateway-zmq-adaptor" \
         && ZMQ_ADAPTOR_SHA256=d1aa7b70f5acfbf344508cdcac0d87401829b3073616dcf15dcfe337196ebcdc \
         && curl -sL https://github.com/adobe-apiplatform/api-gateway-zmq-adaptor/archive/${ZMQ_ADAPTOR_VERSION}.tar.gz -o /tmp/api-gateway-zmq-adaptor-${ZMQ_ADAPTOR_VERSION} \
         && echo "${ZMQ_ADAPTOR_SHA256}  /tmp/api-gateway-zmq-adaptor-${ZMQ_ADAPTOR_VERSION}" | sha256sum -c - \
         && apk update \
         && apk add check-dev g++ gcc \
         && cd /tmp/ \
         && tar -xf /tmp/api-gateway-zmq-adaptor-${ZMQ_ADAPTOR_VERSION} \
         && cd /tmp/api-gateway-zmq-adaptor-* \
         && make test \
         && PREFIX=/usr/local/sbin make install \
         && rm -rf /tmp/api-gateway-zmq-adaptor-* \
         && apk del check-dev g++ gcc \
         && rm -rf /var/cache/apk/*

ENV ZMQ_LOGGER_VERSION 1.0.0
RUN echo " ... installing api-gateway-zmq-logger ..." \
        && ZMQ_LOGGER_SHA256=76afbe17397881719bf24775747276231841274976708cca8d3b37d6b95e61c8 \
        && mkdir -p /tmp/api-gateway \
        && curl -sL https://github.com/adobe-apiplatform/api-gateway-zmq-logger/archive/${ZMQ_LOGGER_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-zmq-logger-${ZMQ_LOGGER_VERSION}.tar.gz \
        && echo "${ZMQ_LOGGER_SHA256}  /tmp/api-gateway/api-gateway-zmq-logger-${ZMQ_LOGGER_VERSION}.tar.gz" | sha256sum -c - \
        && tar -xf /tmp/api-gateway/api-gateway-zmq-logger-${ZMQ_LOGGER_VERSION}.tar.gz -C /tmp/api-gateway/ \
        && cd /tmp/api-gateway/api-gateway-zmq-logger-${ZMQ_LOGGER_VERSION} \
        && cp -r /usr/local/test-nginx/* ./test/resources/test-nginx/ \
        && make test \
        && make install \
             LUA_LIB_DIR=/usr/local/api-gateway/lualib \
             INSTALL=/usr/local/api-gateway/bin/resty-install \
        && rm -rf /tmp/api-gateway

ENV REQUEST_TRACKING_VERSION 1.0.1
RUN echo " ... installing api-gateway-request-tracking ..." \
        && REQUEST_TRACKING_SHA256=6508d4eb444e0ae46bef262e0dd1def25f5762993e1810c21f1603ec57ce8895 \
        && mkdir -p /tmp/api-gateway \
        && curl -sL https://github.com/adobe-apiplatform/api-gateway-request-tracking/archive/${REQUEST_TRACKING_VERSION}.tar.gz -o /tmp/api-gateway/api-gateway-request-tracking-${REQUEST_TRACKING_VERSION}.tar.gz \
        && echo "${REQUEST_TRACKING_SHA256}  /tmp/api-gateway/api-gateway-request-tracking-${REQUEST_TRACKING_VERSION}.tar.gz" | sha256sum -c - \
        && tar -xf /tmp/api-gateway/api-gateway-request-tracking-${REQUEST_TRACKING_VERSION}.tar.gz -C /tmp/api-gateway/ \
        && cd /tmp/api-gateway/api-gateway-request-tracking-${REQUEST_TRACKING_VERSION} \
        && cp -r /usr/local/test-nginx/* ./test/resources/test-nginx/ \
        # && apk update && apk add redis \
        # && REDIS_SERVER=/usr/bin/redis-server make test \
        && make install \
             LUA_LIB_DIR=/usr/local/api-gateway/lualib \
             INSTALL=/usr/local/api-gateway/bin/resty-install \
        # && apk del redis \
        && rm -rf /tmp/api-gateway

ENV JQ_VERSION 1.5
RUN curl -sL https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 -o /usr/local/bin/jq \
    && JQ_SHA256=c6b3a7d7d3e7b70c6f51b706a3b90bd01833846c54d32ca32f0027f00226ff6d \
    && echo "${JQ_SHA256}  /usr/local/bin/jq" | sha256sum -c - \
    && apk update \
    && apk add gawk \
    && chmod 755 /usr/local/bin/jq \
    && rm -rf /var/cache/apk/*

COPY init.sh /etc/init-container.sh

#add the default configuration for the Gateway
COPY api-gateway-config /etc/api-gateway

RUN adduser -S nginx-api-gateway -u 1000 \
    && addgroup -S nginx-api-gateway -g 1000

RUN mkdir -p /usr/local/api-gateway \
    && chown -R nginx-api-gateway /etc/api-gateway /var/log/api-gateway /usr/local \
    && chmod 755 -R /etc/api-gateway /var/log/api-gateway /usr/local \
    && chmod 4755 /bin/busybox \
    && echo "nginx-api-gateway ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# add the default configuration for the Gateway

USER nginx-api-gateway

ENTRYPOINT ["/etc/init-container.sh"]
