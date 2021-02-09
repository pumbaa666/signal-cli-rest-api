# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run
# https://stackoverflow.com/questions/53669151/java-11-application-as-lightweight-docker-image
# $ docker build --target packagerContainer -t signal-web-packager --build-arg ZKGROUP_VERSION=0.7.0 --build-arg JAVA_MINIMAL=/opt/java-minimal .
FROM alpine:latest AS packagerContainer
#ENV JAVA_MINIMAL="/opt/java-minimal"
ARG JAVA_MINIMAL
ARG ZKGROUP_VERSION

RUN apk --no-cache add openjdk11-jdk openjdk11-jmods

RUN echo "JAVA_MINIMAL=$JAVA_MINIMAL"

# build minimal JRE
RUN /usr/lib/jvm/java-11-openjdk/bin/jlink \
    --verbose \
    --add-modules \
        java.base,java.sql,java.naming,java.desktop,java.management,java.security.jgss,java.instrument \
    --compress 2 --strip-debug --no-header-files --no-man-pages \
    --release-info="add:IMPLEMENTOR=radistao:IMPLEMENTOR_VERSION=radistao_JRE" \
    --output "$JAVA_MINIMAL"

ENV ZKGROUP_DIRECTORY=/tmp/zkgroup-libraries
RUN mkdir ${ZKGROUP_DIRECTORY}
COPY ext/libraries/zkgroup/v${ZKGROUP_VERSION} ${ZKGROUP_DIRECTORY}
RUN arch="$(uname -m)"; \
        case "$arch" in \
            aarch64) cp ${ZKGROUP_DIRECTORY}/arm64/libzkgroup.so /tmp/libzkgroup.so ;; \
			armv7l) cp ${ZKGROUP_DIRECTORY}/armv7/libzkgroup.so /tmp/libzkgroup.so ;; \
            x86_64) cp ${ZKGROUP_DIRECTORY}/x86-64/libzkgroup.so /tmp/libzkgroup.so ;; \
        esac;
#ENTRYPOINT ["/bin/sh"] # TODO tester

# fresh node alpine image
# $ docker build --target signalCliContainer -t signal-web-cli --build-arg SIGNAL_CLI_VERSION=0.7.4 --build-arg ZKGROUP_VERSION=0.7.0 --build-arg JAVA_MINIMAL=/opt/java-minimal .
FROM alpine:latest AS signalCliContainer
LABEL builder=true
ARG SIGNAL_CLI_VERSION
# TODO factoriser
ARG JAVA_MINIMAL
ARG ZKGROUP_VERSION
ENV JAVA_HOME=$JAVA_MINIMAL
ENV PATH="$PATH:$JAVA_HOME/bin"
ARG API_UID
ARG API_GID

RUN echo "SIGNAL_CLI_VERSION=$SIGNAL_CLI_VERSION / JAVA_HOME=$JAVA_HOME / JAVA_MINIMAL=$JAVA_MINIMAL / UID : ${API_UID} / GID : ${API_GID}"
COPY --from=packagerContainer "$JAVA_HOME" "$JAVA_HOME"
COPY --from=packagerContainer /tmp/libzkgroup.so /tmp/

# RUN apk --no-cache add zip

RUN cd /tmp/ \
	&& wget https://github.com/AsamK/signal-cli/releases/download/v"${SIGNAL_CLI_VERSION}"/signal-cli-"${SIGNAL_CLI_VERSION}".tar.gz \
	# && zip -u /tmp/signal-cli-${SIGNAL_CLI_VERSION}/build/install/signal-cli/lib/zkgroup-java-${ZKGROUP_VERSION}.jar libzkgroup.so \
	&& tar xf signal-cli-"${SIGNAL_CLI_VERSION}".tar.gz -C /opt \
	&& ln -sf /opt/signal-cli-"${SIGNAL_CLI_VERSION}"/bin/signal-cli /usr/local/bin/ \
	&& rm -rf signal-cli-"${SIGNAL_CLI_VERSION}".tar.gz

ENTRYPOINT ["signal-cli"]

#RUN java --version \
#	&& signal-cli -v

# https://stackoverflow.com/questions/58971382/how-to-give-name-or-tag-for-intermediate-image
# $ docker build --target signalWebContainer -t signal-web-http --build-arg SIGNAL_CLI_VERSION=0.7.4 --build-arg ZKGROUP_VERSION=0.7.0 --build-arg JAVA_MINIMAL=/opt/java-minimal --build-arg API_UID=1010 --build-arg API_GID=1010 .
FROM node:15.7-alpine3.12 as signalWebContainer
ARG API_UID
ARG API_GID
ARG JAVA_MINIMAL
ENV JAVA_HOME=$JAVA_MINIMAL
COPY --from=packagerContainer "$JAVA_HOME" "$JAVA_HOME"
COPY --from=signalCliContainer /usr/local/bin/signal-cli /usr/local/bin/signal-cli

RUN apk update \
    && apk add --upgrade --no-cache -q setpriv

RUN adduser -s /bin/sh -S -D -H -u ${API_UID} signal-api \
    && addgroup -g ${API_GID} -S signal-api \
    && mkdir -p /home/.local/share/signal-cli

ENV APP_DIRECTORY=/app/signal-web

RUN mkdir -p ${APP_DIRECTORY}/conf
COPY src ${APP_DIRECTORY}/src
COPY package.json ${APP_DIRECTORY}/
COPY views ${APP_DIRECTORY}/views
COPY scripts ${APP_DIRECTORY}/scripts
COPY entrypoint.sh /entrypoint.sh

# workaround car je n'arrive pas à bind un dossier dans docker-compose.yml depuis docker-toolbox
COPY conf/log4js.json /app/signal-web/conf/
COPY conf/app.js /app/signal-web/conf/

RUN cd ${APP_DIRECTORY} \
    && yarn install

EXPOSE ${PORT}

# https://stackoverflow.com/questions/37904682/how-do-i-use-docker-environment-variable-in-entrypoint-array
ENTRYPOINT /entrypoint.sh ${API_UID} ${API_GID}

# TODO check l'url et la réponse
# https://blog.couchbase.com/docker-health-check-keeping-containers-healthy/
HEALTHCHECK --interval=20s --timeout=10s --retries=3 \
    CMD curl -f http://192.168.99.100/ || exit 1
#    CMD curl -f http://localhost:${PORT}/v1/health || exit 1
