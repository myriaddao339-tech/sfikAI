#!/usr/bin/env bash
# sim-env — host-side helper. Run `./sim.sh help` for the command list.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${SIM_IMAGE:-sim-env:1}"
NAME="${SIM_CONTAINER:-sim-env}"
WS="${SIM_WS:-$HERE/workspace}"

usage() {
    cat <<EOF
Usage: ./sim.sh <command> [args]

  build             Build the Docker image ($IMAGE)
  start             Start the container in the background
  shell             Open a shell in the container (starts it if needed)
  gazebo [world]    Start Gazebo (default: iris_runway.sdf)
  sitl [args]       Start ArduPilot SITL (Copter, JSON backend)
  mavros            Start MAVROS connected to SITL
  exec <cmd...>     Run any command in the container
  status            Show whether the container is running
  stop              Stop the container

Environment:
  SIM_WS=<dir>      Folder mounted in /workspace (default: $HERE/workspace)
  GCS_IP=<ip>       (sitl) also send MAVLink to a ground station on <ip>:14550
  HEADLESS=1        (gazebo) server only, no window
EOF
}

is_running() {
    [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null || true)" = "true" ]
}

ensure_image() {
    if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        echo "Image $IMAGE not found. Build it first: ./sim.sh build" >&2
        exit 1
    fi
}

start() {
    if is_running; then
        echo "Container '$NAME' already running (workspace: $(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$NAME"))."
        return 0
    fi
    ensure_image
    mkdir -p "$WS"
    WS="$(cd "$WS" && pwd)"
    # Let the container (root) draw windows on the host X server
    command -v xhost >/dev/null 2>&1 && xhost +local:root >/dev/null 2>&1 || true
    docker run -d --rm --init \
        --name "$NAME" \
        --network host \
        --ipc host \
        -e DISPLAY="${DISPLAY:-:0}" \
        -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
        -v "$WS":/workspace \
        "$IMAGE" sleep infinity >/dev/null
    echo "Container '$NAME' started. Workspace: $WS -> /workspace"
}

# docker exec with a TTY only when we have one
dexec() {
    local flags=(-i)
    [ -t 0 ] && [ -t 1 ] && flags+=(-t)
    is_running || start
    docker exec "${flags[@]}" \
        -e GCS_IP="${GCS_IP:-}" \
        -e HEADLESS="${HEADLESS:-0}" \
        -e SITL_LOCATION="${SITL_LOCATION:-}" \
        "$NAME" "$@"
}

cmd="${1:-help}"
shift || true

case "$cmd" in
    build)   docker build -t "$IMAGE" "$@" "$HERE" ;;
    start)   start ;;
    shell)   dexec bash ;;
    gazebo)  dexec /opt/sim/gazebo.sh "$@" ;;
    sitl)    dexec /opt/sim/sitl.sh "$@" ;;
    mavros)  dexec /opt/sim/mavros.sh "$@" ;;
    exec)    dexec bash -c "source /opt/sim/env.sh && $*" ;;
    status)  if is_running; then echo "running"; else echo "stopped"; fi ;;
    stop)    if is_running; then docker stop -t 2 "$NAME" >/dev/null && echo "stopped"; else echo "not running"; fi ;;
    help|-h|--help) usage ;;
    *)       echo "Unknown command: $cmd" >&2; usage; exit 1 ;;
esac
