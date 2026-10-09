#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
cd $DIR

# uv replaces pyenv + poetry: it downloads the pinned Python and installs
# the pinned packages from requirements.txt into ./.venv
if ! command -v "uv" > /dev/null 2>&1; then
  echo "uv install ..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  touch "$HOME/.openpilot_installed_uv"  # so tools/ubuntu_uninstall.sh knows it can remove uv
  export PATH="$HOME/.local/bin:$PATH"
fi

export MAKEFLAGS="-j$(nproc)"

PYTHON_VERSION=$(cat .python-version)
echo "python ${PYTHON_VERSION} install ..."
uv python install ${PYTHON_VERSION}

if [ ! -d ".venv" ]; then
  uv venv --python ${PYTHON_VERSION} .venv
fi

echo "pip packages install..."
uv pip sync --python .venv/bin/python --build-constraints build-constraints.txt requirements.txt

source .venv/bin/activate
export PYTHONPATH="$DIR"

if [ "$(uname)" != "Darwin" ]; then
  echo "pre-commit hooks install..."
  shopt -s nullglob
  for f in .pre-commit-config.yaml */.pre-commit-config.yaml; do
    cd $DIR/$(dirname $f)
    if [ -e ".git" ]; then
      pre-commit install
    fi
  done
fi
