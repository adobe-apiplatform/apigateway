#!/bin/sh
log_level=${LOG_LEVEL:-warn}
marathon_host=$(echo $MARATHON_HOST)

echo "Starting api-gateway ..."
/usr/local/sbin/api-gateway -V
echo "------"

echo resolver $(awk 'BEGIN{ORS=" "} /nameserver/{print $2}' /etc/resolv.conf | sed "s/ $/;/g") > /etc/api-gateway/conf.d/includes/resolvers.conf
echo "   ...  with dns $(cat /etc/api-gateway/conf.d/includes/resolvers.conf)"

if [[ -n "${marathon_host}" ]]; then
    echo "  ... starting Marathon Service Discovery "
    touch /var/run/apigateway-config-watcher.lastrun
    while true; do /etc/api-gateway/marathon-service-discovery.sh > /dev/stderr; sleep 5; done &
fi

echo "   ...  testing configuration "
api-gateway -t -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf

echo "   ... using log level: '${log_level}'. Override it with -e 'LOG_LEVEL=<level>' "
api-gateway -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf -g "daemon off; error_log /dev/stderr ${log_level};"
