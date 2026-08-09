# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
# /etc/omarchy.conf is written by omarchy-dev-link. When absent, force the
# package default instead of preserving a stale inherited dev-link value before
# we decide which rc file to source.
if [[ -f /etc/omarchy.conf ]]; then
  source /etc/omarchy.conf
  export OMARCHY_PATH="${OMARCHY_PATH:-/usr/share/omarchy}"
else
  export OMARCHY_PATH=/usr/share/omarchy
fi
source "$OMARCHY_PATH/default/bash/rc"

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

# ---------------------------------------------------------
# 🔧  direnv
# ---------------------------------------------------------

# Guarded so the shell still works on a machine without direnv installed
command -v direnv &>/dev/null && eval "$(direnv hook bash)"

# ---------------------------------------------------------
# 💻  Functions
# ---------------------------------------------------------

# Delete local branches whose remote tracking branch is gone
git-unload() {
  echo -e "\e[33m\e[0m Unloading dead branches..."
  git fetch -p && git branch -vv | grep ": gone]" | awk '{print $1}' | xargs -r git branch -D
}

# Refresh the git index so .gitignore updates take effect on tracked files
git-reindex() {
  git rm -r --cached . >/dev/null 2>&1
  git add -A
  git status --short
  echo "📋 Manifest updated. Ignored files have been offloaded!"
}

secret() {
  echo -e "\e[33m\e[0m Generating secret..."
  openssl rand -base64 32
}

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end

# ---------------------------------------------------------
# 🔒  Machine-side identity
# ---------------------------------------------------------

# Anything carrying a name, email, account or secret lives here, untracked.
# Sourced last so it can override anything above. Missing file is fine.
[[ -f ~/.bashrc.local ]] && source ~/.bashrc.local
