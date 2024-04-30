#CLEAN TOUT !!!
#docker system prune -af

# Clean les images sans nom
docker rmi $(docker images --filter "dangling=true") --force

#docker stop $(docker ps -a -q)
#docker container prune
#docker volume prune
#docker image prune
#docker rmi $(docker images -q) --force
