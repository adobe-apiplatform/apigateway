#!/bin/sh
echo "Starting api-gateway"
/usr/local/sbin/api-gateway -V
echo "------"

echo resolver $(awk 'BEGIN{ORS=" "} /nameserver/{print $2}' /etc/resolv.conf | sed "s/ $/;/g") > /etc/api-gateway/conf.d/includes/resolvers.conf
echo "   ...  with dns $(cat /etc/api-gateway/conf.d/includes/resolvers.conf)"

api-gateway -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf -g "daemon off; error_log /dev/stderr info;"
