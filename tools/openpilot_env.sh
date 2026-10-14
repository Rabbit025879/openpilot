# Safe to source repeatedly (e.g. `source ~/.zshrc` again): every run
# re-activates the venv, in case the rc file reset PATH before this line.

# openpilot root from the path of this file, in both bash and zsh (zsh without
# `cd`, so a chpwd hook such as openpilot_autoenv.sh's isn't triggered)
if [ -n "$BASH_VERSION" ]; then
  OPENPILOT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null && pwd )"
else
  OPENPILOT_ROOT="${${(%):-%x}:A:h:h}"
fi

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

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
