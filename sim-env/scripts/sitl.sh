#!/usr/bin/env bash
# Start ArduPilot SITL (Copter) with the Gazebo JSON backend.
#   sitl.sh                          -> MAVLink on 127.0.0.1:14550 (GCS) and :14555 (MAVROS)
#   GCS_IP=172.20.0.1 sitl.sh        -> also stream to a ground station on that IP
#   SITL_LOCATION=lat,lon,alt,yaw    -> custom home (default: ArduPilot CMAC)
#   sitl.sh -w                       -> extra args go to sim_vehicle.py (-w = wipe params)
# Gazebo must already be running with an ArduPilot-enabled model (e.g. iris_runway.sdf).
set -euo pipefail
source /opt/sim/env.sh

# Runtime files (eeprom.bin, logs) live here, not in the project folder
mkdir -p /root/sitl
cd /root/sitl

ARGS=(
    -v ArduCopter
    -f gazebo-iris
    --model JSON
    --no-rebuild
    # With --model JSON this ArduPilot version no longer loads the frame's
    # default params on its own (FRAME_CLASS stays 0 -> "Frame: UNSUPPORTED",
    # arming refused). Load them explicitly.
    --add-param-file=/opt/ardupilot/Tools/autotest/default_params/copter.parm
    --add-param-file=/opt/ardupilot/Tools/autotest/default_params/gazebo-iris.parm
    # no --console/--map: they need wxPython, which is not in the image
    --out=udp:127.0.0.1:14550
    --out=udp:127.0.0.1:14555
)

if [ -n "${SITL_LOCATION:-}" ]; then
    ARGS+=(--custom-location="${SITL_LOCATION}")
fi
if [ -n "${GCS_IP:-}" ]; then
    ARGS+=(--out=udp:"${GCS_IP}":14550)
fi

exec sim_vehicle.py "${ARGS[@]}" "$@"
