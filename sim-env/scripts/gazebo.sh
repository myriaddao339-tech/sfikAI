#!/usr/bin/env bash
# Start Gazebo Harmonic with a world.
#   gazebo.sh                    -> iris_runway.sdf (ardupilot_gazebo demo world)
#   gazebo.sh my_world.sdf       -> looked up in /workspace/worlds, then ardupilot_gazebo
#   gazebo.sh /path/to/w.sdf     -> explicit path
#   HEADLESS=1 gazebo.sh ...     -> server only, no GUI
set -euo pipefail
source /opt/sim/env.sh

WORLD="${1:-iris_runway.sdf}"
shift || true

resolve_world() {
    local w="$1"
    for candidate in "$w" "/workspace/$w" "/workspace/worlds/$w" "/opt/ardupilot_gazebo/worlds/$w"; do
        if [ -f "$candidate" ]; then
            readlink -f "$candidate"
            return 0
        fi
    done
    return 1
}

if ! WORLD_PATH="$(resolve_world "$WORLD")"; then
    echo "World not found: $WORLD" >&2
    echo "Available worlds:" >&2
    ls -1 /workspace/worlds/*.sdf /opt/ardupilot_gazebo/worlds/*.sdf 2>/dev/null | sed 's|^|  |' >&2 || true
    exit 1
fi

# Do NOT run from a folder containing several .sdf files: the GUI can hang on
# "requesting list of world names". Start from a neutral directory.
cd /tmp

# An orphan `gz sim` keeps the plugin ports 9002/9003 and the next launch shows
# an empty world: clean up first.
pkill -f "gz sim" 2>/dev/null || true
fuser -k 9002/udp 9003/udp >/dev/null 2>&1 || true
sleep 1

ARGS=(-v2 -r)
if [ "${HEADLESS:-0}" = 1 ]; then
    ARGS+=(-s)
fi

echo "Gazebo: $WORLD_PATH"
exec gz sim "${ARGS[@]}" "$@" "$WORLD_PATH"
