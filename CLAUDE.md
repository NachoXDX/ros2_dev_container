# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A template colcon workspace for ROS 2 Lyrical Luth (Ubuntu 26.04, Python 3.14) developed inside a VS Code Dev Container. The repo root *is* the workspace (mounted at `/home/ros/ws` in the container); packages go in `src/`. All build/run commands assume you are inside the container with `/opt/ros/lyrical/setup.bash` sourced (done by `.bashrc`).

## Commands

```bash
rosdep install --from-paths src --ignore-src -y     # after adding deps to a package.xml
colcon build                                        # defaults come from colcon_defaults.yaml
colcon build --packages-select <pkg>                # build one package
source install/setup.bash
colcon test && colcon test-result --verbose
colcon test --packages-select <pkg> --ctest-args -R <test_regex>   # single C++ test
colcon test --packages-select <pkg> --pytest-args -k <expr>        # single Python test
```

Never `apt install` a dependency ad hoc: runtime/build deps go in the package's `package.xml` as rosdep keys, dev tools go in `.devcontainer/Dockerfile`.

`colcon_defaults.yaml` is picked up via `COLCON_DEFAULTS_FILE` (set in the Dockerfile) and enables `--symlink-install`, `RelWithDebInfo`, ccache as the compiler launcher, and `CMAKE_EXPORT_COMPILE_COMMANDS` (colcon merges these into `build/compile_commands.json`, which IntelliSense reads). `build/`, `install/`, `log/` are gitignored.

## Dev container layout

- Single config: `.devcontainer/devcontainer.json` builds `.devcontainer/Dockerfile` with NVIDIA GPU access (`--gpus=all` + PRIME offload env). The Claude Code VS Code extension (`anthropic.claude-code`) is installed by default.
- Optional stacks are Dockerfile build args (`INSTALL_GAZEBO`, `INSTALL_NAV2`, `INSTALL_MOVEIT`, `INSTALL_CUDA`, `INSTALL_CLAUDE_CODE`), toggled in `build.args` of `devcontainer.json`. Project-specific dependencies belong in `package.xml` + rosdep, not the Dockerfile.
- `post-create.sh`: rosdep init/update and installs deps for `src/` (runs once on container creation).
- `post-start.sh`: on every start, adds the `ros` user to whatever groups own host device nodes (`/dev/dri`, video, tty USB/ACM, input, usb), since host GIDs don't match image groups. Re-run it manually for devices with unusual groups.
- The container is **not** `--privileged`: host `/dev` is bind-mounted for hotplug, and access is limited by `--device-cgroup-rule` entries (dri, video4linux, ttyUSB, ttyACM, input, usb_device; table in README "Devices"). New hardware means adding a rule, not `--privileged`. It uses host network/IPC (DDS) and X11 via `xhost` in `initializeCommand`; RMW is `rmw_fastrtps_cpp`.
- `.devcontainer/`, `.vscode/`, `.git/hooks`, `.git/config` are bind-mounted read-only (they can trigger host-side execution), so inside the container they are not editable; changes to them, and `git config`/`git remote`/`git push -u`, must be done on the host. `~/.claude` (`CLAUDE_CONFIG_DIR`) is a named volume so the Claude Code login survives rebuilds.
- Non-root user `ros` with passwordless sudo; UID remapped to the host user.
- RViz on HiDPI (200% scaling): its Ogre render window oscillates between N and N/2 px after resizes under Qt HiDPI scaling; the Dockerfile adds an `rviz2` alias to `.bashrc` with `QT_ENABLE_HIGHDPI_SCALING=0 QT_FONT_DPI=192`. `ros2 run`/launch files need the vars set explicitly.

## Conventions

- Code style is whatever the ament linters enforce (`ament_uncrustify`, `ament_cpplint`, `ament_flake8`, `ament_pep257`, ...). New packages should declare `ament_lint_auto` and `ament_lint_common` as `<test_depend>` and call `ament_lint_auto_find_test_dependencies()` (CMake) so `colcon test` runs them.
- Changes to read-only paths (`.devcontainer/`, `.vscode/`) can't be made from inside the container. Write them as a unified diff (paths relative to the repo root) to a scratch file and tell the user to `git apply` it on the host, then rebuild the container if the image or `devcontainer.json` changed.
