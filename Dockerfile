# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run
# https://stackoverflow.com/questions/53669151/java-11-application-as-lightweight-docker-image
# $ docker build --target packagerContainer -t signal-web-packager --build-arg SIGNAL_CLI_VERSION=0.7.4 --build-arg ZKGROUP_VERSION=0.7.0 --build-arg JAVA_MINIMAL=/opt/java-minimal .
FROM alpine:latest AS packagerContainer
ARG SIGNAL_CLI_VERSION
ARG ZKGROUP_VERSION
ARG JAVA_MINIMAL

RUN apk --no-cache add openjdk11-jdk openjdk11-jmods git tar zip gzip

# build minimal JRE
RUN /usr/lib/jvm/java-11-openjdk/bin/jlink \
    --verbose \
    --add-modules \
        java.base,java.sql,java.naming,java.desktop,java.management,java.security.jgss,java.instrument \
    --compress 2 --strip-debug --no-header-files --no-man-pages \
    --release-info="add:IMPLEMENTOR=radistao:IMPLEMENTOR_VERSION=radistao_JRE" \
    --output "$JAVA_MINIMAL"

# build signal-cli with zkgroup lib
ENV ZKGROUP_DIRECTORY=/tmp/zkgroup-libraries
RUN mkdir ${ZKGROUP_DIRECTORY}
COPY ext/libraries/zkgroup/v${ZKGROUP_VERSION} ${ZKGROUP_DIRECTORY}
RUN arch="$(uname -m)"; \
        case "$arch" in \
            aarch64) cp ${ZKGROUP_DIRECTORY}/arm64/libzkgroup.so /tmp/libzkgroup.so ;; \
			armv7l) cp ${ZKGROUP_DIRECTORY}/armv7/libzkgroup.so /tmp/libzkgroup.so ;; \
            x86_64) cp ${ZKGROUP_DIRECTORY}/x86-64/libzkgroup.so /tmp/libzkgroup.so ;; \
        esac;

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
	&& zip -u /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/distributions/signal-cli-${SIGNAL_CLI_VERSION}.zip signal-cli-${SIGNAL_CLI_VERSION}/lib/zkgroup-java-${ZKGROUP_VERSION}.jar \
	&& tar --delete -vPf /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/distributions/signal-cli-${SIGNAL_CLI_VERSION}.tar signal-cli-${SIGNAL_CLI_VERSION}/lib/zkgroup-java-${ZKGROUP_VERSION}.jar \
	&& tar --owner='' --group='' -rvPf /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/distributions/signal-cli-${SIGNAL_CLI_VERSION}.tar signal-cli-${SIGNAL_CLI_VERSION}/lib/zkgroup-java-${ZKGROUP_VERSION}.jar

RUN mkdir /opt/signal-cli \
    && tar xf /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/distributions/signal-cli-${SIGNAL_CLI_VERSION}.tar -C /opt/signal-cli --strip-components 1

#ENTRYPOINT ["/bin/sh"] # TODO tester

# https://stackoverflow.com/questions/58971382/how-to-give-name-or-tag-for-intermediate-image
# $ docker build --target signalWebContainer -t signal-web-http --build-arg SIGNAL_CLI_VERSION=0.7.4 --build-arg ZKGROUP_VERSION=0.7.0 --build-arg JAVA_MINIMAL=/opt/java-minimal --build-arg API_UID=1010 --build-arg API_GID=1010 .
FROM node:15.7-alpine3.12 as signalWebContainer
COPY --from=packagerContainer "/opt" "/opt"
ARG JAVA_MINIMAL
ENV JAVA_HOME=$JAVA_MINIMAL
ENV PATH="$PATH:$JAVA_HOME/bin"
ENV PATH="$PATH:/opt/signal-cli/bin"
ARG API_UID
ARG API_GID

RUN echo "JAVA_HOME=$JAVA_HOME / JAVA_MINIMAL=$JAVA_MINIMAL / UID : ${API_UID} / GID : ${API_GID}"

RUN apk update \
    && apk add --upgrade --no-cache -q setpriv

RUN java --version \
    && signal-cli -v

# RUN adduser -s /bin/sh -S -D -H -u ${API_UID} signal-api \
#     && addgroup -g ${API_GID} -S signal-api \
#     && mkdir -p /home/.local/share/signal-cli

# ENV APP_DIRECTORY=/app/signal-web

# RUN mkdir -p ${APP_DIRECTORY}/conf
# COPY src ${APP_DIRECTORY}/src
# COPY package.json ${APP_DIRECTORY}/
# COPY views ${APP_DIRECTORY}/views
# COPY scripts ${APP_DIRECTORY}/scripts
# COPY entrypoint.sh /entrypoint.sh

# # workaround car je n'arrive pas à bind un dossier dans docker-compose.yml depuis docker-toolbox
# COPY conf/log4js.json /app/signal-web/conf/
# COPY conf/app.js /app/signal-web/conf/

# RUN cd ${APP_DIRECTORY} \
#     && yarn install

EXPOSE ${PORT}

# https://stackoverflow.com/questions/37904682/how-do-i-use-docker-environment-variable-in-entrypoint-array
ENTRYPOINT /entrypoint.sh ${API_UID} ${API_GID}

# TODO check l'url et la réponse
# https://blog.couchbase.com/docker-health-check-keeping-containers-healthy/
HEALTHCHECK --interval=20s --timeout=10s --retries=3 \
    CMD curl -f http://192.168.99.100/ || exit 1
#    CMD curl -f http://localhost:${PORT}/v1/health || exit 1
