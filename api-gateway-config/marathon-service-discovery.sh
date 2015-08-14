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

do_log() {
        local _MSG=$1
        echo "`date +'%Y/%m/%d %H:%M:%S'` - marathon-service-discovery: ${_MSG}"
}

fatal_error() {
        local _MSG=$1
        do_log "ERROR: ${_MSG}"
        exit 255
}

info_log() {
        local _MSG=$1
        do_log "${_MSG}"
}

# 1. create the new upstream config
# NOTE: for the moment when tasks expose multiple ports, only the first one is exposed through nginx
curl -s ${marathon_host}/v2/tasks -H "Accept:text/plain" | awk 'NF>2' | grep -v :0 | awk '!seen[$1]++' | awk ' {s=""; for (f=3; f<=NF; f++) s = s  "\n server " $f " fail_timeout=10s;" ; print "upstream " $1 " {"  s  "\n keepalive 16;\n}" }'  > $UPSTREAM_FILE
# 2 check for changes
# TODO: WIP first make sure that the upstream file DID really change, OR if there are other changes pushed to /etc/api-gateway since last run
changed_files=$(find /etc/api-gateway -type f -newer /var/run/apigateway-config-watcher.lastrun -print)
if [[ -n "${changed_files}" ]]; then
    info_log "discovered changed files ..."
    info_log ${changed_files}
    echo `date` > /var/run/apigateway-config-watcher.lastrun
    info_log "reloading gateway ..."
    api-gateway -t -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf && api-gateway -s reload
fi

# 2. diff with an existing one
# cmp -b $TMP_FILE $UPSTREAM_FILE || (info_log "discovered a change..." && cp $TMP_FILE $UPSTREAM_FILE && info_log "reloading gateway ..." && api-gateway -t -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf && api-gateway -s reload)