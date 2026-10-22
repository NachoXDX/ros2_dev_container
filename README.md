# ROS 2 Lyrical Dev Container Template

A starting point for ROS 2 projects developed inside a VS Code Dev Container.
Clone it, open it in VS Code, reopen in the container, and start adding packages to `src/`.

What you get out of the box:

- **ROS 2 Lyrical Luth** (LTS, Ubuntu 26.04), desktop variant: RViz, rqt, demos
- **GPU**: NVIDIA via the container toolkit (PRIME offload for hybrid laptops)
- **Display**: X11 (works on Wayland desktops through XWayland)
- **Devices**: serial, USB, cameras, joysticks and GPUs from the host's `/dev`, including devices plugged in after start, through an allowlist (no `--privileged`)
- **Networking**: host network + host IPC, so Fast DDS discovery and shared-memory transport work with the host and other containers
- **Non-root user** `ros`, with UID/GID remapped to yours so files in the workspace stay owned by you
- **Read-only container config**: `.devcontainer/`, `.vscode/`, `.git/hooks/` and `.git/config` can't be changed from inside the container, so code running there can't make your host run commands
- **Claude Code** (optional): CLI installed in the image, login kept across rebuilds
- C++/Python IntelliSense wired to `compile_commands.json` and the ROS Python packages

## Host prerequisites

1. **Docker** (Engine, not rootless) and your user in the `docker` group.
2. **NVIDIA**: the proprietary driver plus the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html):
   ```bash
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```
   Check it with: `docker run --rm --gpus all ubuntu nvidia-smi`
3. **VS Code** with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension.
4. **xhost** (`sudo apt install x11-xserver-utils`), used to let the container draw on your display.

## Usage

```bash
git clone <this-repo> my_robot && cd my_robot
code .
```

Then run **Dev Containers: Reopen in Container**. Rendering and CUDA run on the NVIDIA GPU.

The first build pulls `osrf/ros:lyrical-desktop` and takes a few minutes. After that:

```bash
cd src && ros2 pkg create --build-type ament_cmake --dependencies rclcpp my_pkg && cd ..
rosdep install --from-paths src --ignore-src -y   # after adding dependencies
colcon build
source install/setup.bash
colcon test && colcon test-result --verbose
```

### Dependencies

Don't `sudo apt install` things your code needs: it works until the next rebuild and leaves no record. Instead:

- **Packages your code uses**: add a `<depend>` (or `<build_depend>`, `<exec_depend>`, `<test_depend>`) with the rosdep key to the package's `package.xml`, then `rosdep install --from-paths src --ignore-src -y`. Look keys up with `rosdep resolve <key>` or in [rosdistro](https://github.com/ros/rosdistro/blob/master/rosdep/base.yaml). `post-create.sh` reinstalls them on every new container.
- **Developer tools** (debuggers, linters, CLIs): add them to the `apt-get install` list in the `Dockerfile`.

Ad hoc installs are fine for trying something out; move it to one of the two places above once you keep it.

`colcon_defaults.yaml` turns on `--symlink-install`, `RelWithDebInfo`, `CMAKE_EXPORT_COMPILE_COMMANDS` and ccache as the compiler launcher, so plain `colcon build` is enough. The ccache directory is a named volume, so rebuilding the container (or wiping `build/`) doesn't throw the cache away; `ccache -s` shows hit rates. New terminals source `install/setup.bash` automatically when it exists.

## Layout

```
.
├── .devcontainer/
│   ├── Dockerfile               # image definition
│   ├── devcontainer.json        # container config (NVIDIA)
│   ├── post-create.sh           # rosdep init/update/install (on container creation)
│   └── post-start.sh            # joins the groups that own host device nodes (on every start)
├── .vscode/settings.json        # workspace settings (ROS distro for the ROS extension)
├── src/                         # your packages
├── colcon_defaults.yaml         # default colcon build flags
├── CLAUDE.md                    # project instructions for Claude Code
├── LICENSE
└── README.md
```

The repo root is the colcon workspace and is mounted at `/home/ros/ws`. `build/`, `install/` and `log/` are gitignored.

## Optional stacks

Set these build args to `"true"` in the `build.args` block of `.devcontainer/devcontainer.json`, then run **Dev Containers: Rebuild Container**:

| Arg | Installs |
| --- | --- |
| `INSTALL_GAZEBO` | `ros-lyrical-ros-gz` (Gazebo plus the ROS bridge) |
| `INSTALL_NAV2` | `ros-lyrical-navigation2`, `ros-lyrical-nav2-bringup` |
| `INSTALL_MOVEIT` | `ros-lyrical-moveit` |
| `INSTALL_CUDA` | CUDA toolkit from NVIDIA's apt repo |
| `INSTALL_CLAUDE_CODE` | Claude Code CLI, see [Developing with Claude Code](#developing-with-claude-code) |

Anything project-specific should go through `package.xml` and rosdep rather than the Dockerfile.

## Devices

The container does **not** use `--privileged`. Host `/dev` is bind-mounted so devices plugged in later show up, but the container can only open device classes allowed by a `--device-cgroup-rule` in `runArgs`. Everything else (disks, `/dev/mem`, …) is visible but returns `Operation not permitted`, even for root.

| Rule | Devices |
| --- | --- |
| `c 226:* rmw` | `/dev/dri/*` (GPU render/display nodes) |
| `c 81:* rmw` | `/dev/video*` (V4L2 cameras) |
| `c 188:* rmw` | `/dev/ttyUSB*` (USB-serial adapters) |
| `c 166:* rmw` | `/dev/ttyACM*` (Arduino, many microcontrollers) |
| `c 13:* rmw` | `/dev/input/*` (joysticks, gamepads) |
| `c 189:* rmw` | `/dev/bus/usb/*/*` (raw USB via libusb, e.g. RealSense) |

NVIDIA devices are added separately by `--gpus=all`.

**Adding a device class**: find its major number on the host, then add a rule to `runArgs` in `.devcontainer/devcontainer.json` and rebuild:

```bash
ls -l /dev/ttyS0          # crw-rw---- 1 root dialout 4, 64 ...  -> major 4
grep -w ttyS /proc/devices
```

```jsonc
"--device-cgroup-rule=c 4:* rmw",
```

Some majors are assigned at boot (`media`, `hidraw`, …; see `/proc/devices`), so check them on the machine you use. For a single fixed device you can use `--device=/dev/ttyUSB0` instead of a rule, but it has to be plugged in when the container starts. To give a device a stable name, use `/dev/serial/by-id/...` or a udev rule on the host.

**CAN**: SocketCAN interfaces are network interfaces, so they show up through `--network=host`. Bringing one up (`ip link set can0 up type can bitrate 500000`) needs `--cap-add=NET_ADMIN`, or do it on the host.

## Read-only paths

These are mounted from the host read-only:

| Path | Why |
| --- | --- |
| `.devcontainer/` | `initializeCommand` runs on the host before the container starts |
| `.vscode/` | tasks and launch configs can run on the host |
| `.git/hooks/` | git hooks run when you commit from the host |
| `.git/config` | `core.hooksPath`, `core.fsmonitor`, `core.sshCommand` etc. run commands on the host |

So code inside the container (a build script, a dependency, Claude Code) can't plant something that runs outside it. The cost is that you make these changes **from the host**, not from a container terminal:

- editing `devcontainer.json`, the Dockerfile, scripts or VS Code settings
- `git config`, `git remote add/set-url`, `git branch -u`, `git push -u` (they write `.git/config`)
- installing git hooks (e.g. `pre-commit install`)

Everyday git (commit, branch, fetch, push to an existing upstream) works inside the container. `post-create.sh` and `post-start.sh` only need to be read, so they're unaffected.

What the read-only mounts **don't** cover:

- **A root-level `.devcontainer.json`**: Dev Containers also accepts a config there, and its `initializeCommand` would run on the host. The template doesn't ship one, so if one appears, don't pick it when VS Code asks which config to open.
- **Git submodules**: `.git/modules/*/config` and `.git/modules/*/hooks` are writable. ROS workspaces usually pull other repos with `vcs import` instead, which avoids this.

## Developing with Claude Code

The Claude Code VS Code extension is installed in the container by default (it ships its own copy of the CLI). To also get the `claude` command in terminals, set `"INSTALL_CLAUDE_CODE": "true"` in `build.args` of `.devcontainer/devcontainer.json` and run **Dev Containers: Rebuild Container**. To drop the extension, remove `"anthropic.claude-code"` from `customizations.vscode.extensions`.

The login is stored in a named volume at `~/.claude` (`CLAUDE_CONFIG_DIR`), so you log in once per container, not once per rebuild.

Claude Code runs with the same access as the rest of the container: your display, the GPU, allowlisted devices and the host network (see [Security note](#security-note)). What it can't do is change the [read-only paths](#read-only-paths). Use Claude Code's own permission prompts for anything touching hardware or the network.

## Troubleshooting

**`cannot open display` / `could not connect to display`**
The container is allowed onto your display by `xhost +SI:localuser:$USER`, which runs on the host before each start. Check that `xhost` is installed and `echo $DISPLAY` is set in the shell VS Code was started from. After a logout/login, rebuild or reopen the container.

**GUI runs but on the wrong GPU**
Run `glxinfo -B | grep renderer` inside the container. On the NVIDIA config it should name your GeForce card. If it says `llvmpipe`, the container toolkit isn't active: check `docker info | grep -i runtimes`.

**Nodes in the container and on the host (or another container) don't see each other**
Both sides need the same `ROS_DOMAIN_ID` (unset means 0) and the same RMW. Fast DDS shared memory needs `--ipc=host`, which is already set. If a peer runs without it, set `FASTDDS_BUILTIN_TRANSPORTS=UDPv4` on both sides.

**Permission denied / Operation not permitted on a device**
`Operation not permitted` (even with sudo) means the device class isn't in the allowlist: add a rule, see [Devices](#devices). `Permission denied` is a group problem: `post-start.sh` adds `ros` to whatever groups own `/dev/dri`, `/dev/video*`, `/dev/tty{USB,ACM}*`, `/dev/input` and `/dev/bus/usb` at start. For a device added later with an unusual group, run `bash .devcontainer/post-start.sh` and open a new terminal.

**`warning: Error disabling address space randomization` in gdb**
Harmless without `--privileged`. Silence it with `set disable-randomization off` in `~/.gdbinit`.

**RViz's 3D view flickers after resizing or maximizing (HiDPI displays)**
With a display scaled to 200% (GNOME Xwayland native scaling), Qt runs RViz at a 2x scale factor. After every resize, RViz's embedded Ogre render window keeps switching between its real size and half of it. This happens on every GPU and every monitor, and only in the 3D view. The `rviz2` alias in the image's `.bashrc` works around it by turning off Qt HiDPI scaling for RViz and doubling the font DPI to keep text readable:

```bash
QT_ENABLE_HIGHDPI_SCALING=0 QT_FONT_DPI=192 rviz2
```

`ros2 run rviz2 rviz2` and launch files bypass the alias. Prefix those variables, or set them in the launch file with `SetEnvironmentVariable`. Plain Qt widget apps such as rqt don't need it; apps that embed RViz's render panel do. If your scale is not 200%, set `QT_FONT_DPI` to 96 × scale.

## Security note

The container avoids `--privileged` and keeps the host-executed files read-only, but it is still not a sandbox:

- **Host network and IPC**: nodes can reach any service on your machine and LAN, and share memory segments with host processes. DDS discovery needs this. Root in the container (one `sudo` away) also has `CAP_NET_RAW` on the host's interfaces, so it can sniff host and LAN traffic. Add `--cap-drop=NET_RAW` to `runArgs` if you don't need `ping` or packet capture.
- **Allowlisted devices**: anything in the device table above, e.g. all cameras and input devices, including your laptop's webcam and keyboard.
- **X11 access**: any GUI client can read input and take screenshots of other X (XWayland) windows.
- **Writable workspace**: everything outside the [read-only paths](#read-only-paths) can be changed, including your source, build scripts and `package.xml`s. Review changes before running them on the host.
- **Passwordless sudo**: needed for rosdep and `post-start.sh`. Without `--privileged` it gives root over the container only, but it removes the user/root boundary inside it.
- **Unpinned inputs**: the base image is pulled by tag (`osrf/ros:lyrical-desktop`) and Claude Code comes from its install script, so a rebuild gets whatever is current. For reproducible builds, pin the image by digest (`FROM osrf/ros:lyrical-desktop@sha256:...`).

Only run code you trust in this container. Before re-adding `--privileged` for an exotic device, try a device rule or a single capability (`--cap-add`) first.