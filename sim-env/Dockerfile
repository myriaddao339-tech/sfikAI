# =============================================================================
# sim-env — UAV simulation image (CPU only)
#   Ubuntu 22.04 · ROS 2 Humble · MAVROS · Gazebo Harmonic · ArduPilot SITL
#   + ardupilot_gazebo plugin built against Harmonic
#
# No GPU needed: rendering goes through Mesa llvmpipe (software rasterizer).
#
# Build (x86_64, internet required):   ./sim.sh build
# =============================================================================
FROM osrf/ros:humble-desktop

SHELL ["/bin/bash", "-c"]
ARG DEBIAN_FRONTEND=noninteractive

# Pinned versions (ardupilot_gazebo has no tags -> commit SHA)
ARG AP_GAZEBO_SHA=082a0fe231f6e63bc8d1598f1cba461d9e2ea7f5
ARG ARDUPILOT_SHA=9bbfed9c910699892251f76d0a604b4c9ac398dc

LABEL org.opencontainers.image.title="sim-env" \
      org.opencontainers.image.description="ROS 2 Humble + Gazebo Harmonic + ArduPilot SITL + MAVROS (CPU only)" \
      sim.ardupilot_gazebo="${AP_GAZEBO_SHA}" \
      sim.ardupilot="${ARDUPILOT_SHA}"

# -----------------------------------------------------------------------------
# 1. Gazebo Harmonic apt repository (packages.osrfoundation.org)
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release \
 && curl -fsSL https://packages.osrfoundation.org/gazebo.gpg \
      -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/gazebo-stable.list \
 && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Gazebo Harmonic + Python gz bindings + MAVROS + build tools + software GL
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        gz-harmonic \
        libgz-sim8-dev rapidjson-dev \
        libopencv-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
        gstreamer1.0-plugins-bad gstreamer1.0-libav gstreamer1.0-gl \
        python3-gz-transport13 python3-gz-msgs10 \
        python3-opencv python3-numpy \
        ros-humble-mavros ros-humble-mavros-extras \
        ros-humble-cv-bridge ros-humble-image-transport \
        mesa-utils libgl1-mesa-dri libglx-mesa0 libegl-mesa0 \
        build-essential cmake pkg-config git wget \
        python3-dev python3-pip python3-setuptools python3-wheel \
        python3-future python3-lxml python3-empy python3-pexpect \
        libtool autoconf automake rsync \
        x11-utils xauth psmisc iproute2 nano \
 && rm -rf /var/lib/apt/lists/*

# MAVProxy (used by sim_vehicle.py)
RUN python3 -m pip install --no-cache-dir "MAVProxy>=1.8,<2" \
 && rm -rf /root/.cache/pip

# GeographicLib datasets (MAVROS will not start without them)
RUN /opt/ros/humble/lib/mavros/install_geographiclib_datasets.sh \
 && rm -rf /usr/share/GeographicLib/geoids/*.tar.bz2 2>/dev/null || true

# -----------------------------------------------------------------------------
# 3. ardupilot_gazebo plugin, built against Harmonic
# -----------------------------------------------------------------------------
ENV GZ_VERSION=harmonic
RUN git init -q /opt/ardupilot_gazebo \
 && cd /opt/ardupilot_gazebo \
 && git remote add origin https://github.com/ArduPilot/ardupilot_gazebo.git \
 && git fetch -q --depth 1 origin "${AP_GAZEBO_SHA}" \
 && git checkout -q --detach FETCH_HEAD \
 && cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo \
 && cmake --build build -j"$(nproc)" \
 && test -f build/libArduPilotPlugin.so

# -----------------------------------------------------------------------------
# 4. ArduPilot SITL (Copter) at a pinned commit — longest step (~10-20 min).
#    .git is kept: sim_vehicle.py uses it for versioning.
# -----------------------------------------------------------------------------
RUN git init -q /opt/ardupilot \
 && cd /opt/ardupilot \
 && git remote add origin https://github.com/ArduPilot/ardupilot.git \
 && git fetch -q --depth 1 origin "${ARDUPILOT_SHA}" \
 && git checkout -q --detach FETCH_HEAD \
 && (git submodule update -q --init --recursive --depth 1 \
     || git submodule update -q --init --recursive) \
 && ./waf configure --board sitl \
 && ./waf copter -j"$(nproc)" \
 && test -x build/sitl/bin/arducopter

# -----------------------------------------------------------------------------
# 5. Runtime environment (software rendering, simple Qt render loop)
# -----------------------------------------------------------------------------
ENV GZ_VERSION=harmonic \
    GZ_SIM_SYSTEM_PLUGIN_PATH=/opt/ardupilot_gazebo/build \
    GZ_SIM_RESOURCE_PATH=/opt/ardupilot_gazebo/models:/opt/ardupilot_gazebo/worlds \
    PATH=/opt/ardupilot/Tools/autotest:${PATH} \
    LIBGL_ALWAYS_SOFTWARE=1 \
    GALLIUM_DRIVER=llvmpipe \
    QSG_RENDER_LOOP=basic \
    QT_X11_NO_MITSHM=1 \
    ROS_DOMAIN_ID=0

# Runtime lib needed by libGstCameraPlugin.so (camera streaming plugin);
# without it Gazebo logs "libdebuginfod.so.1: cannot open shared object file".
RUN apt-get update && apt-get install -y --no-install-recommends libdebuginfod1 \
 && rm -rf /var/lib/apt/lists/* \
 && ! ldd /opt/ardupilot_gazebo/build/libGstCameraPlugin.so | grep -q "not found"

COPY scripts/ /opt/sim/
# Strip CRLF in case the folder was edited/copied on Windows
RUN sed -i 's/\r$//' /opt/sim/*.sh \
 && chmod +x /opt/sim/*.sh \
 && echo 'source /opt/sim/env.sh' >> /root/.bashrc

# Sanity check: the build fails if any component is missing
RUN gz sim --versions >/dev/null \
 && test -f /opt/ardupilot_gazebo/build/libArduPilotPlugin.so \
 && test -x /opt/ardupilot/build/sitl/bin/arducopter \
 && python3 -c "import gz.transport13, gz.msgs10, cv2, numpy" \
 && source /opt/ros/humble/setup.bash && ros2 pkg prefix mavros >/dev/null

WORKDIR /workspace
CMD ["bash"]
