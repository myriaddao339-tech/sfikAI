#!/usr/bin/env bash
# Common environment, sourced by every script and by interactive shells.

export GZ_SIM_SYSTEM_PLUGIN_PATH="/opt/ardupilot_gazebo/build:${GZ_SIM_SYSTEM_PLUGIN_PATH:-}"
# Project models/worlds first, then the ardupilot_gazebo ones
export GZ_SIM_RESOURCE_PATH="/workspace/models:/workspace/worlds:/opt/ardupilot_gazebo/models:/opt/ardupilot_gazebo/worlds"

# Software rendering (no GPU in the container)
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export QSG_RENDER_LOOP=basic
export QT_X11_NO_MITSHM=1

# ROS 2 setup files do not support `set -u`: disable it while sourcing,
# then restore the caller's state.
_sim_nounset=0
case $- in *u*) _sim_nounset=1 ;; esac
set +u
source /opt/ros/humble/setup.bash
# Project overlay, once built with colcon in /workspace
if [ -f /workspace/install/setup.bash ]; then
    source /workspace/install/setup.bash
fi
if [ "$_sim_nounset" = 1 ]; then
    set -u
fi
unset _sim_nounset
