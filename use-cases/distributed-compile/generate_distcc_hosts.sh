# Script: generate_distcc_hosts.sh
#!/bin/bash

set -e

echo "Fetching pod IPs from distcc-headless..."
POD_IPS=$(getent ahosts distcc-headless.default.svc.cluster.local | awk '{print $1}' | sort -u)
DISTCC_HOSTS=""

for ip in $POD_IPS; do
  DISTCC_HOSTS+="$ip/4 "
done

export DISTCC_HOSTS=$(echo $DISTCC_HOSTS | xargs)
echo "DISTCC_HOSTS set to: $DISTCC_HOSTS"

exec "$@"