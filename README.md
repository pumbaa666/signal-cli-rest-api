# About
**signal-web** is a local web-server for Signal messenger https://signal.org
Served as a docker image it runs on signal-cli api https://github.com/AsamK/signal-cli and signal-cli-rest-api https://github.com/bbernhard/signal-cli-rest-api/

# Versions
```
docker-ce 19.03.14
docker-compose 1.27.4
java jdk 11.0.6
```

# Install Java
```
sudo apt update
sudo apt install openjdk-11-jdk
```

# Install Docker
https://docs.docker.com/engine/install/debian/#install-using-the-repository

```
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

#Add Docker’s official GPG key:
$ curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

#Verify that you now have the key with the fingerprint
sudo apt-key fingerprint 0EBFCD88

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
```

# Install docker-compose
https://stackoverflow.com/questions/42139982/version-in-docker-compose-yml-is-unsupported-you-might-be-seeing-this-error
```
which docker-compose
	/usr/bin/docker-compose
sudo rm /usr/bin/docker-compose
curl -L https://github.com/docker/compose/releases/download/1.20.0/docker-compose-`uname -s`-`uname -m` -o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose
```

# API
https://github.com/bbernhard/signal-cli-rest-api/blob/master/doc/HOMEASSISTANT.md
