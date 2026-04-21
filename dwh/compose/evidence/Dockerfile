FROM sitespeedio/node:ubuntu-24-04-nodejs-24.14.0
ARG WORKSPACE_DIR=/evidence

RUN apt-get update && apt-get install -y \
    curl wget nano git xdg-utils && \
    npm install -g degit && \
    mkdir -p ${WORKSPACE_DIR} && \
    mkdir -p /evidence-bin && \
    rm -rf /var/lib/apt/lists/*

COPY bootstrap.sh /evidence-bin/bootstrap.sh
WORKDIR ${WORKSPACE_DIR}

ENTRYPOINT [ "bash", "/evidence-bin/bootstrap.sh" ]