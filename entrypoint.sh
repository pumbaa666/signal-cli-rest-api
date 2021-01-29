#!/bin/sh
set -x
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

API_UID=$1
API_GID=$2
if [ -z "$API_UID" ]; then
  API_UID=1010
  echo -e "${RED}API_UID should have been set.{NC} Using default"
fi
echo "API_UID : $API_UID"

if [ -z "$API_GID" ]; then
  API_GID=$API_UID
  echo -e "${RED}API_GID should have been set{NC} Using default"
fi
echo "API_GID : $API_GID"

export SIGNAL_WEB_APP_DIR=/app/signal-web
export SIGNAL_CLI_CONFIG_DIR=/home/.local/share/signal-cli

# Fix permissions to ensure backward compatibility
chown -R $API_UID:$API_GID -R ${SIGNAL_WEB_APP_DIR}
chown -R $API_UID:$API_GID -R ${SIGNAL_CLI_CONFIG_DIR} # TODO garder ??

# Show warning on docker exec
cat <<EOF >> /root/.bashrc
echo "WARNING: The application runs as signal-api (not as root!)"
echo "Run 'su signal-api' before using signal-cli!"
echo "If you want to use signal-cli directly, don't forget to specify the config directory. e.g: \"signal-cli --config ${SIGNAL_CLI_CONFIG_DIR}\""
EOF

cap_prefix="-cap_"
caps="$cap_prefix$(seq -s ",$cap_prefix" 0 $(cat /proc/sys/kernel/cap_last_cap))"

# Start API as signal-api user
echo "Running signal-web with UID $API_UID and GID $API_GID"
cd /app/signal-web && \
  exec setpriv --reuid=$API_UID --regid=$API_GID --init-groups --inh-caps=$caps node src/http_server.js
