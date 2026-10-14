# Sourced from ~/.zshrc or ~/.bashrc by tools/ubuntu_setup.sh.
# Activates the openpilot environment (tools/openpilot_env.sh) only while the
# current directory is inside this openpilot checkout, and deactivates it on
# leaving. Other directories keep your normal Python.

# path of this file in both bash and zsh
if [ -n "$BASH_VERSION" ]; then
  _OP_AUTOENV_FILE="${BASH_SOURCE[0]}"
else
  _OP_AUTOENV_FILE="${(%):-%x}"
fi
_OP_AUTOENV_ROOT="$( cd "$( dirname "$_OP_AUTOENV_FILE" )/.." >/dev/null && pwd )"
unset _OP_AUTOENV_FILE

_openpilot_autoenv() {
  case "$PWD/" in
    "$_OP_AUTOENV_ROOT"/*)
      # (re)activate if the venv isn't on PATH, e.g. after `source ~/.zshrc`
      case ":$PATH:" in
        *":$_OP_AUTOENV_ROOT/.venv/bin:"*) ;;
        *) source "$_OP_AUTOENV_ROOT/tools/openpilot_env.sh" ;;
      esac
      ;;
    *)
      if [ "$VIRTUAL_ENV" = "$_OP_AUTOENV_ROOT/.venv" ] && command -v deactivate > /dev/null 2>&1; then
        deactivate
      fi
      if [ "$PYTHONPATH" = "$_OP_AUTOENV_ROOT" ]; then
        unset PYTHONPATH
      fi
      unset OPENPILOT_ENV
      ;;
  esac
}

if [ -n "$ZSH_VERSION" ]; then
  autoload -Uz add-zsh-hook
  add-zsh-hook chpwd _openpilot_autoenv
elif [ -n "$BASH_VERSION" ]; then
  case ";$PROMPT_COMMAND;" in
    *";_openpilot_autoenv;"*) ;;
    *) PROMPT_COMMAND="_openpilot_autoenv${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
  esac
fi
_openpilot_autoenv
