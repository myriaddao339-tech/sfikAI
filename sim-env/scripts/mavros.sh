#!/usr/bin/env bash
# Start MAVROS connected to SITL (SITL streams to UDP 14555).
#   mavros.sh                 -> fcu_url udp://:14555@
#   FCU_URL=... mavros.sh     -> another connection
set -euo pipefail
source /opt/sim/env.sh

# namespace:=mavros -> standard topic names (/mavros/state, ...);
# apm.launch defaults to an empty namespace (/state, ...).
exec ros2 launch mavros apm.launch \
    fcu_url:="${FCU_URL:-udp://:14555@}" \
    namespace:=mavros \
    "$@"
