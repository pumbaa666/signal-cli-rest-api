#!/bin/sh

 # TODO créer fichier build.sh qui fait le docker build --target -t etc et trouver comment passer la target que je veux en ARG

$target=$1
$imageName=$2
$args="TODO lle reste" # --build-arg SIGNAL_CLI_VERSION=0.7.4 --build-arg JAVA_MINIMAL=/opt/java-minimal --build-arg API_UID=1010 --build-arg API_GID=1010
docker build --target $target -t $imageName $args .