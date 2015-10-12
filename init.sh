#!/bin/sh
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
debug_mode=$(echo $DEBUG)
log_level=${LOG_LEVEL:-warn}
marathon_host=$(echo $MARATHON_HOST)
sleep_duration=${MARATHON_POLL_INTERVAL:-5}

apk update
apk add jq

VAULT_RESPONSE=`curl http://54.186.36.101:8200/v1/secret/gatewayssl`

echo $VAULT_RESPONSE | jq -r .data.key > /etc/ssl/certs/api.concursolutions.com.key
echo $VAULT_RESPONSE | jq -r .data.cert > /etc/ssl/certs/api.concursolutions.com.cert

echo "Starting api-gateway ..."
if [ "${debug_mode}" == "true" ]; then
    echo "   ...  in DEBUG mode "
    mv /usr/local/sbin/api-gateway /usr/local/sbin/api-gateway-no-debug
    ln -sf /usr/local/sbin/api-gateway-debug /usr/local/sbin/api-gateway
fi

/usr/local/sbin/api-gateway -V
echo "------"

echo resolver $(awk 'BEGIN{ORS=" "} /nameserver/{print $2}' /etc/resolv.conf | sed "s/ $/;/g") > /etc/api-gateway/conf.d/includes/resolvers.conf
echo "   ...  with dns $(cat /etc/api-gateway/conf.d/includes/resolvers.conf)"

if [[ -n "${marathon_host}" ]]; then
    echo "  ... starting Marathon Service Discovery on ${marathon_host}"
    touch /var/run/apigateway-config-watcher.lastrun
    # start marathon's service discovery
    while true; do /etc/api-gateway/marathon-service-discovery.sh > /dev/stderr; sleep ${sleep_duration}; done &
    # start simple statsd logger
    #
    # ASSUMPTION: there is a graphite app named "api-gateway-graphite" deployed in marathon
    #
    while true; do \
        statsd_host=$(curl -s ${marathon_host}/v2/apps/api-gateway-graphite/tasks -H "Accept:text/plain" | grep 8125 | awk '{for(i=3;i<=NF;++i) printf("%s ", $i) }' | awk '{for(i=1;i<=NF;++i) sub(/\:\d+/,"",$i); print }' ); \
        if [[ -n "${statsd_host}" ]]; then python /etc/api-gateway/scripts/python/logger/StatsdLogger.py --statsd-host=${statsd_host} > /var/log/api-gateway/statsd-logger.log; fi; \
        sleep 6; \
    done &
fi

echo "   ...  testing configuration "
api-gateway -t -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf

echo "   ... using log level: '${log_level}'. Override it with -e 'LOG_LEVEL=<level>' "
api-gateway -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf -g "daemon off; error_log /dev/stderr ${log_level};"
