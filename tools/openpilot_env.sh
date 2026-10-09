if [ -z "$OPENPILOT_ENV" ]; then
  OPENPILOT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null && pwd )"
  export PATH="$HOME/.local/bin:$PATH"

  if [[ "$(uname)" == 'Darwin' ]]; then
    # msgq doesn't work on mac
    export ZMQ=1
    export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
  fi

  # uv-managed virtualenv created by update_requirements.sh
  if [ -f "$OPENPILOT_ROOT/.venv/bin/activate" ]; then
    source "$OPENPILOT_ROOT/.venv/bin/activate"
  fi
  export PYTHONPATH="$OPENPILOT_ROOT"

  export OPENPILOT_ENV=1
fi
