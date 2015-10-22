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

#
#  Overview:
#    Initialize goji conf. Goji will fetch tasks from marathon and render the template based on the $GOJI_CONF + marathon task data
#    This script will render the goji conf with the marathon host provided in env
#    Marathon apps that should be managed by goji must be explicitly configured in goji.conf in the "services" section.
#
#  NOTE: The template rendering in goji currently replaces all slashes in the task appId with underscores.
#  (thus this line in the goji executed restart command: sed 's/upstream\\ \\_/upstream\\ /g )
#

marathon_host=$(echo $MARATHON_HOST)

GOJI_CONF_TMPL=/etc/api-gateway/goji.conf
GOJI_CONF=/tmp/goji.conf.replaced
MARATHON_HOSTNAME=$(echo $MARATHON_HOST | awk -F/ '{print $3}' | awk -F: '{print $1}')
MARATHON_PORT=$(echo $MARATHON_HOST | awk -F/ '{print $3}' | awk -F: '{print $2}')



do_log() {
        local _MSG=$1
        echo "`date +'%Y/%m/%d %H:%M:%S'` - marathon-init: ${_MSG}"
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

#update goji conf with env configs
sed "s/\$MARATHON_HOSTNAME/$MARATHON_HOSTNAME/g" $GOJI_CONF_TMPL > $GOJI_CONF
sed -i "s/\$MARATHON_PORT/$MARATHON_PORT/g" $GOJI_CONF

info_log "configured goji conf $GOJI_CONF"
