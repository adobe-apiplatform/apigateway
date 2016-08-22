#!/bin/bash
# Try to workaround unreliable subdirectory sync by watching sync output and touching file in parent directory

function trigger_sync {
	echo "Trigger sync!"
	UP="/etc/api-gateway/update.txt"
	touch $UP && sleep 0.25 && touch $UP
	# still problems, force the reload
	api-gateway -s reload
}

if [ "$1" == "--gen" ]; then
	rclone sync "$2" /etc/api-gateway/generated-conf.d/ 2>&1 | grep -q "Transferred: *[1-9]" && trigger_sync
else
	rclone sync --exclude *resolvers.conf --exclude *environment.conf.d/*vars.server.conf --exclude *environment.conf.d/*upstreams.http.conf "$2" /etc/api-gateway/ 2>&1 | grep -q "Transferred: *[1-9]" && trigger_sync
fi

exit 0
