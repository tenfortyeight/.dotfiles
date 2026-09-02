#!/usr/bin/env bash
#
# Bootstrap a Mac from this repo. Idempotent — re-run it whenever.
#
#   ./install.sh
#
# It installs Homebrew if missing, runs the Brewfile, sets up oh-my-zsh and
# powerlevel10k, symlinks the dotfiles into $HOME, and generates an SSH key if
# there isn't one. Everything it cannot do for you is listed in the README.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '\033[36m▸\033[0m %s\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- Homebrew --------------------------------------------------------------
# Must come first; everything below assumes it. The eval puts brew on PATH for
# the rest of THIS script — .zprofile does the same for future login shells.
info "Homebrew"
if ! have brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$_brew" ] && eval "$("$_brew" shellenv)" && break
done
have brew || { echo "brew still not on PATH — install it manually and re-run" >&2; exit 1; }
ok "brew $(brew --version | head -1 | cut -d' ' -f2)"

# --- Packages --------------------------------------------------------------
info "Packages (Brewfile)"
brew bundle --file="$DOTFILES_DIR/Brewfile"
ok "Brewfile applied"

# --- oh-my-zsh -------------------------------------------------------------
# RUNZSH/CHSH keep the installer from starting a shell or prompting, which is
# what made this script impossible to re-run unattended.
info "oh-my-zsh"
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "installed"
else
  ok "already present"
fi

# --- powerlevel10k ---------------------------------------------------------
# Cloned rather than vendored into this repo, so it updates independently.
info "powerlevel10k"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
  ok "cloned"
else
  git -C "$P10K_DIR" pull --ff-only --quiet || warn "could not update — continuing"
  ok "already present"
fi

# --- zsh plugins -----------------------------------------------------------
# None of these ship with oh-my-zsh, and the Homebrew builds of the zsh-users
# ones install to the brew prefix — which is NOT where oh-my-zsh looks. They
# have to be clones under $ZSH_CUSTOM/plugins or `plugins=(...)` in .zshrc
# reports them as missing on every shell start.
info "zsh plugins"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
clone_plugin() {
  local name=$1 url=$2 dir="$ZSH_CUSTOM_DIR/plugins/$1"
  if [ -d "$dir" ]; then
    git -C "$dir" pull --ff-only --quiet 2>/dev/null || warn "$name: could not update, keeping what is there"
    ok "$name already present"
    return
  fi
  # Loud on failure, and verified afterwards. A silently failed clone would
  # otherwise print a tick and leave the shell reporting a missing plugin.
  if ! git clone --depth=1 "$url" "$dir"; then
    warn "$name: clone FAILED — .zshrc will skip it until this succeeds"
    return
  fi
  if [ -f "$dir/$name.plugin.zsh" ]; then
    ok "$name cloned"
  else
    warn "$name: cloned but no $name.plugin.zsh — oh-my-zsh will not load it"
  fi
}
clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
clone_plugin jq                      https://github.com/reegnz/jq-zsh-plugin.git

# --- Symlinks --------------------------------------------------------------
# An explicit list, not a find(1) glob. The old glob swept up .DS_Store and
# anything else that happened to be lying around.
info "Symlinks"
for file in .zshrc .zprofile .bashrc .bash_profile .gitconfig .gitignore .vimrc .p10k.zsh .terraformrc; do
  src="$DOTFILES_DIR/$file"
  [ -f "$src" ] || continue
  ln -sfn "$src" "$HOME/$file"
  # shellcheck disable=SC2088  # display text, not a path — the link is made above
  ok "~/$file"
done

# --- vim -------------------------------------------------------------------
info "vim-plug"
if [ ! -f "$HOME/.vim/autoload/plug.vim" ]; then
  curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  ok "installed"
else
  ok "already present"
fi

# --- SSH -------------------------------------------------------------------
# ed25519, not RSA. --apple-use-keychain, not the long-deprecated -K.
info "SSH key"
SSH_KEY="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY" ]; then
  email="$(git config --file "$DOTFILES_DIR/.gitconfig" user.email || true)"
  [ -n "$email" ] || read -r -p "  Email for the SSH key: " email
  ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY" -N ""
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add --apple-use-keychain "$SSH_KEY"
  pbcopy < "$SSH_KEY.pub"
  ok "generated — public key copied to the clipboard"
  warn "add it at https://github.com/settings/keys"
else
  ok "already present"
fi

printf '\n\033[32mDone.\033[0m Open a new terminal, then see the README for the few steps\n'
printf 'that cannot be automated (Nerd Font, Docker Desktop, Kubernetes).\n'
