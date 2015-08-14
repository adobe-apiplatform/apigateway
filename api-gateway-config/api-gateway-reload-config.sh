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

# this script checks to see if there's any modification to the configuration files since the last run
# to automatically reload the configuration.

# NOTE: not used for now

# The script may be executed as part of a cronjob running every minute like
# * * * * * /etc/api-gateway/api-gateway-reload-config.sh 1>&2 > /var/log/api-gateway/reload-config-cron.log

LOG_DIR=/var/log/api-gateway
LOG_FILE=$LOG_DIR/reload-config.log

function do_log()
{
        local _MSG=$1
        echo "[`date +'%Y-%m-%d-%H:%M:%S'`] - ${_MSG}"
}

function fatal_error()
{
        local _MSG=$1
        do_log "ERROR: ${_MSG}"
        exit 255
}

function info_log()
{
        local _MSG=$1
        do_log "${_MSG}"
}


changed_files=$(find /etc/api-gateway -type f -newer /var/run/apigateway-config-watcher.lastrun -print)
if [[ -n "${changed_files}" ]]; then
    info_log "discovered changed files ..."
    info_log ${changed_files}
    info_log "reloading gateway ..."
    api-gateway -t -p /usr/local/api-gateway/ -c /etc/api-gateway/api-gateway.conf && api-gateway -s reload
fi
echo `date` > /var/run/apigateway-config-watcher.lastrun