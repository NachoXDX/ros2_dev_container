#!/usr/bin/env bash
set -eo pipefail

# ROS setup scripts are not nounset-safe, so source them before enabling -u
source "/opt/ros/${ROS_DISTRO}/setup.bash"
set -u

if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    sudo rosdep init
fi
rosdep update --rosdistro "${ROS_DISTRO}"

sudo apt-get update
rosdep install --from-paths src --ignore-src -y --rosdistro "${ROS_DISTRO}"
