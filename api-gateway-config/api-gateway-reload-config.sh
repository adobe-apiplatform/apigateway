#!/bin/sh

# this script checks to see if there's any modification to the configuration files in the past 2 minutes
# to automatically reload the configuration.

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


find /etc/api-gateway -type f -newermt '2 minutes ago' | xargs -r sh -c 'service api-gateway configtest && service api-gateway reload | tee -a $LOG_FILE'

if [ $? = 0 ];
then
    info_log "api-gateway config check"
else
    fatal_error "failed to reload api-gateway. Check configs. RC=$?"
fi
