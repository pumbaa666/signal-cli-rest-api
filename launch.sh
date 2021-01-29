#!/bin/sh
. scripts/bash-colors.sh # Load echo colors

#Running
docker-compose up -d

#Checking
signalWebContainerId=$(docker ps -qf name=pumbaa-signal-web)

if [ -z "$signalWebContainerId" ]; then
  echo -e "${RED}signal-web has not started${NC}"
else
  url="http://192.168.99.100/" # TODO
  echo -e "${GREEN}signal-web is running in background${NC}"
  echo -e "Open your browser on $url"
fi
