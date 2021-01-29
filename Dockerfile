# https://docs.docker.com/develop/develop-images/multistage-build/

ARG SIGNAL_CLI_VERSION=0.7.4
ARG ZKGROUP_VERSION=0.7.0

FROM adoptopenjdk:15-jre-hotspot-focal AS signalApiContainer
ARG SIGNAL_CLI_VERSION
ARG ZKGROUP_VERSION

COPY ext/libraries/zkgroup/v${ZKGROUP_VERSION} /tmp/zkgroup-libraries

# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run
RUN arch="$(uname -m)"; \
        case "$arch" in \
            aarch64) cp /tmp/zkgroup-libraries/arm64/libzkgroup.so /tmp/libzkgroup.so ;; \
			armv7l) cp /tmp/zkgroup-libraries/armv7/libzkgroup.so /tmp/libzkgroup.so ;; \
            x86_64) cp /tmp/zkgroup-libraries/x86-64/libzkgroup.so /tmp/libzkgroup.so ;; \
        esac;

# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run
RUN apt-get update \
	&& apt-get install -y --no-install-recommends \
	    default-jre \
	    file \
	    git \
	    locales \
	    software-properties-common \
	    wget \
	    zip \
	&& rm -rf /var/lib/apt/lists/*

RUN cd /tmp/ \
	&& git clone https://github.com/AsamK/signal-cli.git signal-cli-${SIGNAL_CLI_VERSION} \
	&& cd signal-cli-${SIGNAL_CLI_VERSION} \
	&& git checkout v${SIGNAL_CLI_VERSION} \
	&& ./gradlew build \
	&& ./gradlew installDist \
	&& ./gradlew distTar

RUN cd /tmp/ \
	&& zip -u /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/install/signal-cli/lib/zkgroup-java-${ZKGROUP_VERSION}.jar libzkgroup.so

RUN cd /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/distributions/ \
	&& mkdir -p signal-cli-${SIGNAL_CLI_VERSION}/lib/ \
	&& cp /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/install/signal-cli/lib/zkgroup-java-${ZKGROUP_VERSION}.jar signal-cli-${SIGNAL_CLI_VERSION}/lib/ \
	# update zip
	&& zip -u /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/distributions/signal-cli-${SIGNAL_CLI_VERSION}.zip signal-cli-${SIGNAL_CLI_VERSION}/lib/zkgroup-java-${ZKGROUP_VERSION}.jar \
	# update tar
	&& tar --delete -vPf /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/distributions/signal-cli-${SIGNAL_CLI_VERSION}.tar signal-cli-${SIGNAL_CLI_VERSION}/lib/zkgroup-java-${ZKGROUP_VERSION}.jar \
	&& tar --owner='' --group='' -rvPf /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/distributions/signal-cli-${SIGNAL_CLI_VERSION}.tar signal-cli-${SIGNAL_CLI_VERSION}/lib/zkgroup-java-${ZKGROUP_VERSION}.jar

# Start a fresh container for release container
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#use-multi-stage-builds
FROM node:15.7-alpine3.10 AS signalWebContainer
ARG SIGNAL_CLI_VERSION
ARG API_UID
ARG API_GID

RUN apk update \
    && apk add -q setpriv \
    && rm -rf /var/lib/apt/lists/*

COPY --from=signalApiContainer /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/distributions/signal-cli-${SIGNAL_CLI_VERSION}.tar /tmp/signal-cli-${SIGNAL_CLI_VERSION}.tar
RUN tar xf /tmp/signal-cli-${SIGNAL_CLI_VERSION}.tar -C /opt
RUN rm -rf /tmp/signal-cli-${SIGNAL_CLI_VERSION}

RUN mkdir -p /app/signal-web/
COPY src /app/signal-web/src
COPY node_modules /app/signal-web/node_modules
COPY views /app/signal-web/views
COPY scripts /app/signal-web/scripts

# TODO delete et debugger docker-compose.yml
COPY conf/log4js.json /app/signal-web/conf/
COPY conf/app.js /app/signal-web/conf/

COPY entrypoint.sh /entrypoint.sh

RUN addgroup -g ${API_GID} signal-api \
	&& adduser -D -H -u ${API_UID} -G signal-api -s /bin/bash signal-api \
	&& ln -s /opt/signal-cli-${SIGNAL_CLI_VERSION}/bin/signal-cli /usr/bin/signal-cli \
	&& mkdir -p /signal-cli-config/ \
	&& mkdir -p /home/.local/share/signal-cli

EXPOSE ${PORT}

# https://stackoverflow.com/questions/37904682/how-do-i-use-docker-environment-variable-in-entrypoint-array
ENTRYPOINT /entrypoint.sh ${API_UID} ${API_GID}

# TODO check l'url et la réponse
HEALTHCHECK --interval=20s --timeout=10s --retries=3 \
    CMD curl -f http://192.168.99.100/ || exit 1
#    CMD curl -f http://localhost:${PORT}/v1/health || exit 1
