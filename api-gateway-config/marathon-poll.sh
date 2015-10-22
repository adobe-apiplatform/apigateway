#!/bin/sh
#/*
# * Copyright (c) 2015 Adobe Systems Incorporated. All rights reserved.
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
#    Render the upstreams config once, using goji to fetch marathon tasks and render the template specified in $GOJI_CONF
#    If the rendered output changes, goji will execute the command specified in the $GOJI_CONF after config is updated
#    This script should be called periodically to force resync of marathon task config to the api gateway config, incase the callbacks fail.


GOJI_CONF=/tmp/goji.conf.replaced



do_log() {
        local _MSG=$1
        echo "`date +'%Y/%m/%d %H:%M:%S'` - marathon-poll: ${_MSG}"
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

info_log "polling with goji conf $GOJI_CONF"
goji -conf $GOJI_CONF
#currently goji replaces all appId slashes with underscore, remove this prefix in the command conf



# 1.1. check redis upstreams
#
# ASSUMPTION:  there is a redis app named "api-gateway-redis" deployed in marathon and optionally another app named "api-gateway-redis-replica"
#
#redis_master=$(cat ${TMP_FILE} | grep api-gateway-redis | wc -l)
#redis_replica=$(cat ${TMP_FILE} | grep api-gateway-redis-replica | wc -l)
##      if api-gateway-redis upstream exists but api-gateway-redis-replica does not, then create the replica
#if [ ${redis_master} -gt 0 ] && [ ${redis_replica} -eq 0 ]; then
#    # clone api-gateway-redis block
#    sed -e '/api-gateway-redis/,/}/!d' ${TMP_FILE} | sed 's/-redis/-redis-replica/' >> ${TMP_FILE}
#fi
#
#if [ ${redis_master} -eq 0 ]; then
#    echo "upstream api-gateway-redis { server 127.0.0.1:6379; }" >> ${TMP_FILE}
#fi
