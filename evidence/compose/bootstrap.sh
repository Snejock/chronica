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

        # `build` is always a symlink to a timestamped release directory, never a real
        # directory itself. Each rebuild compiles into a brand-new release dir (via
        # EVIDENCE_BUILD_DIR), leaving the currently-served release untouched, then
        # repoints `build` at it with a single atomic rename. `npm run preview` resolves
        # the `build` symlink on every request, so the swap is instant and the site never
        # 404s while a rebuild is in progress. If the build fails, `build` is left as-is.
        #
        # Old release dirs are kept around for GRACE_MIN minutes after being replaced,
        # not deleted the instant the symlink flips: a browser tab open across the swap
        # still requests the previous release's content-hashed JS/data chunks by their
        # old filename, and removing that directory immediately 404s those in-flight
        # requests from tabs that were open at deploy time.
        GRACE_MIN=${EVIDENCE_RELEASE_GRACE_MIN:-10}
        rebuild() {
            local release="build_$(date +%Y%m%d%H%M%S%N)"
            rm -rf "$release"
            if npm run sources && EVIDENCE_BUILD_DIR="./$release" npm run build; then
                ln -sfn "$release" build.tmp
                mv -T build.tmp build
                find . -maxdepth 1 -type d -name 'build_*' -mmin "+$GRACE_MIN" ! -name "$release" -exec rm -rf {} +
                return 0
            else
                echo "[build] failed, keeping previous release"
                rm -rf "$release"
                return 1
            fi
        }

        rebuild || true
        (
          while true; do
            sleep "$REBUILD_INTERVAL"
            echo "[refresh] rebuilding..."
            rebuild || echo "[refresh] failed, will retry next cycle"
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