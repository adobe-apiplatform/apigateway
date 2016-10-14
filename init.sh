#!/bin/bash
#/*
# * Copyright (c) 2012 Adobe Systems Incorporated. All rights reserved.
# *
# * Permission is hereby granted, free of charge, to any person obtaining a
# * copy of this software and associated documentation files (the "Software"),
# * to deal in the Software without restriction, including without limitation
# * the rights to use, copy, modify, merge, publish, distribute, sublicense,
# * and/or sell copies of the Software, and to permit persons to whom the
# * Software is furnished to do so, subject to the following conditions:
# *
# * The above copyright notice and this permission notice shall be included in
# * all copies or substantial portions of the Software.
# *
# * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# * DEALINGS IN THE SOFTWARE.
# *
# */

# configurable environment variables
[[ "${DEBUG}" == true ]] && set -vx || DEBUG=false
: ${LOG_LEVEL:=warn}
: ${ZMQ_PUBLISHER_PORT}
: ${MARATHON_HOST}
: ${MARATHON_POLL_INTERVAL:=5}
# location for a local or remote /etc/api-gateway folder.
# i.e file:///tmp/api-gateway-config s3://api-gateway-config
: ${REMOTE_CONFIG}
: ${REMOTE_CONFIG_GENERATED}
: ${REMOTE_CONFIG_SYNC_INTERVAL:=10s}
: ${API_GATEWAY_CONFIG_SUPERVISOR_EXTRA} # e.g. --debug

function start_zmq_adaptor()
{
    echo "Starting ZeroMQ adaptor ..."
    # use -d flag to start API Gateway ZMQ adaptor in debug mode to print all messages sent by the GW
    zmq_adaptor_cmd="api-gateway-zmq-adaptor"
    if [[ -n "${ZMQ_PUBLISHER_PORT}" ]]; then
        echo "... ZMQ will publish messages on:" ${ZMQ_PUBLISHER_PORT}
        zmq_adaptor_cmd="${zmq_adaptor_cmd} -p ${ZMQ_PUBLISHER_PORT}"
    fi
    if [[ "${DEBUG}" == "true" ]]; then
        echo "   ...  in DEBUG mode "
        zmq_adaptor_cmd="${zmq_adaptor_cmd} -d"
    fi

    $zmq_adaptor_cmd >> /dev/stderr &
    sleep 3s
    # allow interprocess communication by allowing api-gateway processes to write to the socket
    chown nginx-api-gateway:nginx-api-gateway /tmp/nginx_queue_listen
    chown nginx-api-gateway:nginx-api-gateway /tmp/nginx_queue_push
}
# keep the zmq adaptor running using a simple loop
for ((;;)); do zmq_pid=$(ps aux | grep api-gateway-zmq-adaptor | grep -v grep) || ( echo "Restarting api-gateway-zmq-adaptor" && start_zmq_adaptor ); sleep 60; done &


echo "Starting api-gateway ..."
if [[ "${DEBUG}" == "true" ]]; then
    echo "   ...  in DEBUG mode "
    mv /usr/local/sbin/api-gateway /usr/local/sbin/api-gateway-no-debug
    ln -sf /usr/local/sbin/api-gateway-debug /usr/local/sbin/api-gateway
fi

/usr/local/sbin/api-gateway -V
echo "------"

echo resolver $(awk 'BEGIN{ORS=" "} /nameserver/{print $2}' /etc/resolv.conf | sed "s/ $/;/g") > /etc/api-gateway/conf.d/includes/resolvers.conf
echo "   ...  with dns $(cat /etc/api-gateway/conf.d/includes/resolvers.conf)"

sync_cmd="echo checking for changes ..."
if [[ -n "${REMOTE_CONFIG_GENERATED}" ]]; then
    REMOTE_CONFIG=${REMOTE_CONFIG_GENERATED}
    generated=' generated'
fi
# override sync with generated, if specified
if [[ -n "${REMOTE_CONFIG}" ]]; then
    excludes="--exclude *resolvers.conf --exclude *environment.conf.d/*vars.server.conf --exclude *environment.conf.d/*upstreams.http.conf --exclude *generated-conf.d/*"
    echo "   ... using remote${generated} config from: ${REMOTE_CONFIG}"
    case ${REMOTE_CONFIG} in
      s3://*)
	sync_cmd="aws s3 sync $excludes --delete ${REMOTE_CONFIG} /etc/api-gateway/${generated:+generated-conf.d/}"
        echo "   ... syncing from s3 using command ${sync_cmd}"
	;;
      file:///*)
	REMOTE_CONFIG=${REMOTE_CONFIG:7}
	;& # fallthru
      /*)
	sync_cmd="rclone -q sync $excludes ${REMOTE_CONFIG} /etc/api-gateway/${generated:+generated-conf.d/}"
	echo "   ... syncing with rclone using command ${sync_cmd}"
	;;
      *)
	echo "   ... but this REMOTE_CONFIG${generated:+_GENERATED} is not supported "
    esac
fi
api-gateway-config-supervisor \
        ${API_GATEWAY_CONFIG_SUPERVISOR_EXTRA} \
        --reload-cmd="api-gateway -s reload" \
        --sync-folder=/etc/api-gateway \
        --sync-interval=${REMOTE_CONFIG_SYNC_INTERVAL} \
        --sync-cmd="${sync_cmd}" \
        --http-addr=127.0.0.1:8888 &

if [[ -n "${MARATHON_HOST}" ]]; then
    echo "  ... starting Marathon Service Discovery on ${MARATHON_HOST}"
    touch /var/run/apigateway-config-watcher.lastrun
    # start marathon's service discovery
    for ((;;)); do /etc/api-gateway/marathon-service-discovery.sh > /dev/stderr; sleep ${MARATHON_POLL_INTERVAL}; done &
    # start simple statsd logger
    #
    # ASSUMPTION: there is a graphite app named "api-gateway-graphite" deployed in marathon
    #
    for ((;;)); do \
        statsd_host=$(curl -s ${MARATHON_HOST}/v2/apps/api-gateway-graphite/tasks -H "Accept:text/plain" | grep 8125 | awk '{for(i=3;i<=NF;++i) printf("%s ", $i) }' | awk '{for(i=1;i<=NF;++i) sub(/:[[:digit:]]+/,"",$i); print }' ); \
        if [[ -n "${statsd_host}" ]]; then python /etc/api-gateway/scripts/python/logger/StatsdLogger.py --statsd-host=${statsd_host} > /var/log/api-gateway/statsd-logger.log; fi; \
        sleep 6; \
    done &
fi

echo "   ... testing configuration "
api-gateway -t -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf

echo "   ... using log level: '${LOG_LEVEL}'. Override it with -e 'LOG_LEVEL=<level>' "
api-gateway -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf -g "daemon off; error_log /dev/stderr ${LOG_LEVEL};"
