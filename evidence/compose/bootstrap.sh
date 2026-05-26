#!/bin/bash
set -e

echo "Starting Evidence.dev environment mounted on $(pwd) in the container."
echo "Provided arguments => $@"

RUN_DEV_COMMAND="npm run sources && npm run dev -- --host 0.0.0.0"
RUN_PROD_COMMAND="npm run sources && npm run build && npm run preview"
COMMAND="npm install && $RUN_DEV_COMMAND"

case $1 in
    init)
        echo "Starting with a blank template project."
        npx degit evidence-dev/template . --force && npm install
        if [ $# -gt 1 ];
        then
            COMMAND=${@:2}
        else
            COMMAND=$RUN_DEV_COMMAND
        fi
        ;;
    dev)
        echo "Starting in development mode."
        COMMAND="npm install && $RUN_DEV_COMMAND"
        ;;
    prod)
        echo "Starting in production mode (build + periodic rebuild + preview)."
        REBUILD_INTERVAL=${EVIDENCE_REBUILD_INTERVAL:-1200}
        npm install
        npm run sources && npm run build
        (
          while true; do
            sleep "$REBUILD_INTERVAL"
            echo "[refresh] npm run sources && npm run build"
            npm run sources && npm run build || echo "[refresh] failed, will retry next cycle"
          done
        ) &
        COMMAND="npm run preview"
        ;;
    *)
        if [ $# -gt 0 ];
        then
            COMMAND=$@
        fi
        ;;
esac

echo "Running command => $COMMAND"
eval $COMMAND