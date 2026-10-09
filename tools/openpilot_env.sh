if [ -z "$OPENPILOT_ENV" ]; then
  # path of this file in both bash and zsh
  if [ -n "$BASH_VERSION" ]; then
    _OP_ENV_FILE="${BASH_SOURCE[0]}"
  else
    _OP_ENV_FILE="${(%):-%x}"
  fi
  OPENPILOT_ROOT="$( cd "$( dirname "$_OP_ENV_FILE" )/.." >/dev/null && pwd )"
  unset _OP_ENV_FILE
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
