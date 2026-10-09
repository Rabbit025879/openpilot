# openpilot v0.9.1 on Ubuntu 24.04 with uv

Branch: `v0.9.1-ubuntu24-uv` in Rabbit025879/openpilot (a few commits on top of the official v0.9.1 tag).
Tested on Ubuntu 24.04.5, gcc 13.3, clang 18, uv 0.11.

## Install steps

```bash
git clone -b v0.9.1-ubuntu24-uv https://github.com/Rabbit025879/openpilot.git
cd openpilot
git submodule update --init
sudo apt install git-lfs          # needed before the next line; setup installs it too, but runs later
git lfs install                   # one-time: enables Git LFS for your user
git lfs pull                      # downloads the large files (models, images, prebuilt libs, ~250 MB)
tools/ubuntu_setup.sh             # apt packages + uv + Python 3.8.10 + .venv
source ~/.zshrc                   # or ~/.bashrc; setup writes to the rc file of your login shell
scons -u -j$(nproc)
```

Then copy the course data (only step needed from tools092, see below):

```bash
cp -r /path/to/tools092/replay/dataC tools/replay/
```

`tools/openpilot_env.sh` activates `.venv` and sets `PYTHONPATH`. It replaces `poetry shell`.

## Run the UI with replay

Two terminals, both with the venv active:

```bash
# terminal 1: the openpilot UI
cd ~/AI-Course/openpilot && ./selfdrive/ui/ui

# terminal 2a: Taiwan course data (dataC), with the course's replayJLL
cd ~/AI-Course/openpilot/tools/replay
./replayJLL --data_dir dataC "8bfda98c9c9e4291|2020-05-11--03-00-57--61"

# terminal 2b: or comma's demo drive (downloads from comma's server)
cd ~/AI-Course/openpilot && tools/replay/replay --demo
```

## tools092 (course files)

The PDF says to replace `tools/` with `tools092`. **Don't**: it would delete this branch's 24.04/uv/zsh/uninstall fixes.

What tools092 contains:
- The official openpilot **v0.9.2** `tools/` folder (newer cabana, plotjuggler layouts, small script changes). Not needed for the course.
- **replayJLL** (`tools/replay/*JLL.*`, `mainJLL.cc`): the professor's copy of the v0.9.1 replay. It loads local data laid out as `dataC/<dongle|timestamp>/<segment>/`, which stock `replay` can't (it fails with "failed to load route"). It also reuses the previous camera frame when a decode fails, and prints debug lines.
- **dataC** (84 MB): one segment (61) of a Taiwan drive, Toyota Prius 2017.
- A prebuilt `replayJLL` binary from 2023, linked to old libraries (`libcapnp-0.7.0.so`, `libcrypto.so.1.1`), so it won't run on 24.04.

What this branch does with it:
- Added the 11 JLL source files to `tools/replay/` and a `replayJLL` target in `tools/replay/SConscript`. It builds as a separate program and library (`qt_replayJLL`), so `replay` and cabana are unchanged. It shares the unmodified `filereader.cc`, `logreader.cc` and `util.cc` (with the `va_start` fix).
- `tools/replay/.gitignore` ignores `replayJLL` (the built binary) and `dataC/`. The data stays local: it's 84 MB and course material, and the fork is public.
- Tested: replayJLL loads dataC, plays it, and publishes carState and camera frames.

So the only manual step from tools092 is copying `dataC` into `tools/replay/`. After that tools092 can be deleted.

## Uninstall

`tools/ubuntu_setup.sh` records every apt package it newly installs (dependencies included, nothing you already had) in `~/.openpilot_apt_installed.txt`. To undo everything except the checkout itself:

```bash
tools/ubuntu_uninstall.sh   # asks before removing; apt shows the exact list first
rm -rf ~/openpilot          # if you no longer need the code
```

It removes the recorded apt packages, `.venv`, the uv-managed Python 3.8.10, uv itself only if setup installed it, and the `~/.bashrc` / `~/.zshrc` line. Packages that apt upgraded during setup stay at the newer version.

## What I changed from v0.9.1

| File | Change | Why |
|---|---|---|
| `update_requirements.sh` | Rewritten: installs uv if missing, `uv python install 3.8.10`, `uv venv .venv`, `uv pip sync requirements.txt` | Replaces pyenv + poetry |
| `requirements.txt` (new) | Pinned list exported from `poetry.lock` (main + dev groups) | uv can't read poetry's lock directly |
| `requirements.txt` | `av` 9.2.0 → 12.3.0 | See error 2 |
| `requirements.txt` | `opencv-python-headless`: PyPI 4.5.5.64 wheel instead of comma's custom wheel | See error 3 |
| `requirements.txt` | Removed `poetry`, `poetry-plugin-export` | No longer used |
| `build-constraints.txt` (new) | `cython<3` for packages built from source | See error 1 |
| `tools/openpilot_env.sh` | Activate `.venv` and set `PYTHONPATH` instead of pyenv init | Replaces `poetry shell` and the `.env` plugin |
| `tools/ubuntu_setup.sh` | Added `noble` case; use `libglib2.0-0t64`, `libpng16-16t64` on 24.04 | Script rejected 24.04 and fell back to 20.04 packages |
| `SConstruct` | Added `-Wno-vla-cxx-extension` | See error 4 |
| `common/statlog.cc`, `common/swaglog.cc`, `tools/replay/util.cc` | `#include <cstdarg>` | See error 5 |
| `selfdrive/boardd/panda.h`, `panda_comms.h` | `#include <string>` | See error 5 |
| `tools/ubuntu_setup.sh` | Records newly installed apt packages in `~/.openpilot_apt_installed.txt` | Clean uninstall |
| `tools/ubuntu_uninstall.sh` (new) | Removes exactly what setup added | Clean uninstall |
| `requirements.txt` | Removed `shellingham` | Only poetry used it; 1.5.0 is yanked on PyPI |
| `tools/ubuntu_setup.sh` | Writes the `openpilot_env.sh` line to `~/.zshrc` or `~/.bashrc` depending on your login shell; no duplicates on re-run | zsh support |
| `tools/openpilot_env.sh` | Works in bash and zsh; re-activates `.venv` every time it's sourced | zsh support; re-sourcing `~/.zshrc` used to drop out of the venv |
| `tools/replay/*JLL.*`, `SConscript`, `.gitignore` | Added course replayJLL; ignore `replayJLL` binary and `dataC/` | See "tools092" above |
| `tools/README.md`, `.gitignore` | Docs for 24.04 and uv; ignore `.venv/` | |

Submodules (cereal, panda, opendbc, ...) are untouched.

## Errors hit and fixes

1. **`av` failed to build with Cython 3**: `av/logging.pyx: Cannot assign type ... Exception values are incompatible. Suggest adding 'noexcept'`. Build isolation pulls the latest Cython. Fix: `build-constraints.txt` pins `cython<3`.
2. **`av==9.2.0` failed to compile against FFmpeg 6**: `src/av/stream.c: error: 'struct AVStream' has no member named ...`. 9.2.0 has no wheel and only supports FFmpeg 4. Fix: av 12.3.0 (prebuilt cp38 wheel with its own FFmpeg). Only `tools/camerastream/compressed_vipc.py` uses it.
3. **`import cv2` failed**: `ImportError: libavcodec.so.58: cannot open shared object file`. comma's opencv wheel links FFmpeg 4, and 24.04 ships FFmpeg 6 (libavcodec.so.60). Fix: the standard PyPI wheel of the same version (4.5.5.64), which bundles its own libraries.
4. **clang 18 VLA error**: `cereal/visionipc/ipc.cc:62:20: error: variable length arrays in C++ are a Clang extension [-Werror,-Wvla-cxx-extension]`. Fixed with a compiler flag so the cereal submodule stays untouched.
5. **Missing includes with newer libstdc++**: `use of undeclared identifier 'va_start'` (statlog.cc, swaglog.cc, replay/util.cc) and `implicit instantiation of undefined template 'std::basic_string<char>'` (boardd/panda.h, panda_comms.h). Older headers pulled these in indirectly. Fix: explicit includes.

## What I verified

- `tools/ubuntu_setup.sh` runs to completion on 24.04.
- `scons -j4` builds everything with no errors (ui, modeld, boardd, replay, replayJLL, cabana, controls/acados).
- replayJLL plays dataC (stock replay can't read it).
- zsh: setup writes only to `~/.zshrc`; a new zsh and a re-sourced `~/.zshrc` both use `.venv`.
- `pytest` on `test_following_distance.py`, `test_lateral_mpc.py` and `test_car_interfaces.py`: 206 passed.
- `selfdrive/ui/ui` starts and keeps running. My environment has no display, so I couldn't see it draw.
