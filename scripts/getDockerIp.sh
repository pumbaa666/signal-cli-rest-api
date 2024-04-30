#!/bin/sh

# For Windows 7 and Docker-for-Windows compatibility
# https://github.com/docker/for-win/issues/204

dockerIp=$(docker-machine ip)
if [ -z "dockerIp" ]; then
  echo "Cant find docker-machine ip"
  exit -1
fi

echo $dockerIp > ./conf/docker-ip
echo "Docker network ip : $dockerIp"
echo "saved in ./conf/docker-ip"
