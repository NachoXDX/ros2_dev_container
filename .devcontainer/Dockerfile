FROM osrf/ros:lyrical-desktop

ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000

# Optional stacks (off by default to keep the image lean)
ARG INSTALL_GAZEBO=false
ARG INSTALL_NAV2=false
ARG INSTALL_MOVEIT=false
ARG INSTALL_CUDA=false
ARG INSTALL_CLAUDE_CODE=false

ENV DEBIAN_FRONTEND=noninteractive

# Base dev tooling, GPU/display diagnostics and device utilities
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        build-essential gdb ccache clang-format git curl ca-certificates \
        python3-colcon-common-extensions python3-rosdep python3-vcstool python3-pip \
        ros-${ROS_DISTRO}-rmw-fastrtps-cpp \
        mesa-utils vulkan-tools libgl1 libegl1 libglvnd0 x11-apps \
        usbutils can-utils \
        bash-completion sudo less nano \
    && rm -rf /var/lib/apt/lists/*

RUN if [ "$INSTALL_GAZEBO" = "true" ]; then \
        apt-get update && apt-get install -y --no-install-recommends ros-${ROS_DISTRO}-ros-gz \
        && rm -rf /var/lib/apt/lists/*; \
    fi

RUN if [ "$INSTALL_NAV2" = "true" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            ros-${ROS_DISTRO}-navigation2 ros-${ROS_DISTRO}-nav2-bringup \
        && rm -rf /var/lib/apt/lists/*; \
    fi

RUN if [ "$INSTALL_MOVEIT" = "true" ]; then \
        apt-get update && apt-get install -y --no-install-recommends ros-${ROS_DISTRO}-moveit \
        && rm -rf /var/lib/apt/lists/*; \
    fi

RUN if [ "$INSTALL_CUDA" = "true" ]; then \
        . /etc/os-release && repo="ubuntu$(echo "$VERSION_ID" | tr -d .)" \
        && curl -fsSL -o /tmp/cuda-keyring.deb \
            "https://developer.download.nvidia.com/compute/cuda/repos/${repo}/x86_64/cuda-keyring_1.1-1_all.deb" \
        && dpkg -i /tmp/cuda-keyring.deb && rm /tmp/cuda-keyring.deb \
        && apt-get update && apt-get install -y --no-install-recommends cuda-toolkit \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# Replace the stock 'ubuntu' user (UID 1000) with a non-root dev user.
# VS Code's updateRemoteUserUID remaps UID/GID to the host user at startup.
RUN userdel -r ubuntu 2>/dev/null || true \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} \
    && for g in video render dialout plugdev input; do \
           getent group $g >/dev/null || groupadd -r $g; usermod -aG $g ${USERNAME}; \
       done \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp \
    QT_X11_NO_MITSHM=1 \
    COLCON_DEFAULTS_FILE=/home/${USERNAME}/ws/colcon_defaults.yaml

RUN { \
        echo ''; \
        echo "source /opt/ros/${ROS_DISTRO}/setup.bash"; \
        echo '[ -f ~/ws/install/setup.bash ] && source ~/ws/install/setup.bash'; \
        echo '[ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ] && source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash'; \
    } >> /home/${USERNAME}/.bashrc

USER ${USERNAME}

# Claude Code (native installer, per-user). Config lives in CLAUDE_CONFIG_DIR so a
# single volume mounted there keeps the login across rebuilds.
ENV PATH=/home/${USERNAME}/.local/bin:${PATH} \
    CLAUDE_CONFIG_DIR=/home/${USERNAME}/.claude
RUN mkdir -p /home/${USERNAME}/.claude \
    && if [ "$INSTALL_CLAUDE_CODE" = "true" ]; then \
        curl -fsSL https://claude.ai/install.sh | bash; \
    fi

WORKDIR /home/${USERNAME}/ws
