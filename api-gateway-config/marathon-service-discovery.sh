#!/bin/sh

#
#  Overview:
#    It reads the list of tasks from Marathon and it dynamically generates the Nginx configuration with the upstreams.
#
#    In order to gather the information the script needs to know where to find Marathon
#       so it looks for the $MARATHON_HOST environment variable.
#

TMP_FILE=/tmp/api-gateway-upstreams.http.conf
UPSTREAM_FILE=/etc/api-gateway/environment.conf.d/api-gateway-upstreams.http.conf
marathon_host=$(echo $MARATHON_HOST)

function do_log() {
        local _MSG=$1
        echo "`date +'%Y/%m/%d %H:%M:%S'` - marathon-service-discovery: ${_MSG}"
}

function fatal_error() {
        local _MSG=$1
        do_log "ERROR: ${_MSG}"
        exit 255
}

function info_log() {
        local _MSG=$1
        do_log "${_MSG}"
}

# 1. create the new upstream config
# NOTE: for the moment when tasks expose multiple ports, only the first one is exposed through nginx
curl -s ${marathon_host}/v2/tasks -H "Accept:text/plain" | awk 'NF>2' | grep -v :0 | awk '!seen[$1]++' | awk ' {s=""; for (f=3; f<=NF; f++) s = s  "\n server " $f " fail_timeout=10s;" ; print "upstream " $1 " {"  s  "\n keepalive 16;\n}" }'  > $TMP_FILE
# 2. diff with an existing one
cmp -b $TMP_FILE $UPSTREAM_FILE || (info_log "discovered a change..." && cp $TMP_FILE $UPSTREAM_FILE && info_log "reloading gateway ..." && service api-gateway configtest && service api-gateway reload)