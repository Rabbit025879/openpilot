#!/bin/bash
# Undo tools/ubuntu_setup.sh: removes only the apt packages that setup newly
# installed (recorded in ~/.openpilot_apt_installed.txt), the uv-managed Python,
# the .venv and the ~/.bashrc / ~/.zshrc line. The openpilot checkout itself is kept.

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
ROOT="$(cd $DIR/../ && pwd)"
APT_LOG="$HOME/.openpilot_apt_installed.txt"

SUDO=""
if [[ ! $(id -u) -eq 0 ]]; then
  SUDO="sudo"
fi

PKGS=""
if [ -f "$APT_LOG" ]; then
  # only packages that are still installed
  PKGS=$(dpkg-query -W -f='${db:Status-Status} ${binary:Package}\n' $(cat "$APT_LOG") 2>/dev/null | awk '$1=="installed"{print $2}' | xargs)
fi

echo "This will remove:"
echo "  - $(echo $PKGS | wc -w) apt packages listed in $APT_LOG"
echo "  - $ROOT/.venv"
echo "  - uv-managed Python $(cat $ROOT/.python-version)"
[ -f "$HOME/.openpilot_installed_uv" ] && echo "  - uv itself (installed by openpilot setup)"
echo "  - the openpilot_env.sh line in ~/.bashrc / ~/.zshrc"
read -p "Continue? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

if [ -n "$PKGS" ]; then
  # no -y: apt shows what it will remove (including anything installed later that depends on these) and asks
  $SUDO apt-get remove $PKGS
fi
rm -f "$APT_LOG"

rm -rf "$ROOT/.venv"
if command -v uv > /dev/null 2>&1; then
  uv python uninstall $(cat $ROOT/.python-version) || true
fi
if [ -f "$HOME/.openpilot_installed_uv" ]; then
  rm -f "$HOME/.local/bin/uv" "$HOME/.local/bin/uvx"
  rm -rf "$HOME/.cache/uv" "$HOME/.local/share/uv"
  rm -f "$HOME/.openpilot_installed_uv"
fi

for rc in ~/.bashrc ~/.zshrc; do
  [ -f "$rc" ] && sed -i '\|tools/openpilot_env.sh|d' "$rc"
done

echo "openpilot dependencies removed. Delete $ROOT yourself if you no longer need it."
