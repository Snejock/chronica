FROM sitespeedio/node:ubuntu-24-04-nodejs-24.14.0
ARG WORKSPACE_DIR=/evidence

RUN apt-get update && apt-get install -y \
    curl wget nano git xdg-utils && \
    npm install -g degit && \
    mkdir -p ${WORKSPACE_DIR} && \
    mkdir -p /evidence-bin && \
    chown -R 1000:1000 ${WORKSPACE_DIR} && \
    chown -R 1000:1000 /evidence-bin && \
    rm -rf /var/lib/apt/lists/*

COPY --chown=1000:1000 bootstrap.sh /evidence-bin/bootstrap.sh
RUN chmod +x /evidence-bin/bootstrap.sh

WORKDIR ${WORKSPACE_DIR}

USER 1000

ENTRYPOINT [ "bash", "/evidence-bin/bootstrap.sh" ]