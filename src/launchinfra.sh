#!/bin/bash
# LaunchInfra bootstrap: load modules and dispatch CLI
set -eo pipefail

BASEDIR=$(dirname "$0")
LIBDIR="$BASEDIR/lib"

# Se executado de /usr/bin, usar lib compartilhada
if [ "$BASEDIR" = "/usr/bin" ] || [ "$BASEDIR" = "/usr/local/bin" ]; then
    LIBDIR="/usr/share/launchinfra/lib"
fi

for module in logging config utils nginx_project cli; do
    if [ -r "$LIBDIR/$module.sh" ]; then
        # shellcheck disable=SC1090
        . "$LIBDIR/$module.sh"
    fi
done

dispatch_cli "$@"
