# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

ZSH_DISABLE_COMPFIX=true

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
# Homebrew is set up in ~/.zprofile (login shell), so it is already on PATH by
# the time we get here. Only personal bin dirs belong below.
# `typeset -U` keeps the array de-duplicated no matter how often this is sourced.
typeset -U path PATH
path=("$HOME/bin" "$HOME/.local/bin" "$HOME/go/bin" $path)

# ---------------------------------------------------------------------------
# oh-my-zsh
# ---------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# git/github/brew/kubectl ship with oh-my-zsh. jq, zsh-autosuggestions and
# zsh-syntax-highlighting do not — install.sh clones them into
# $ZSH_CUSTOM/plugins. Note the Homebrew builds of the zsh-users plugins land in
# the brew prefix, which oh-my-zsh does not look at, so brew alone is not enough.
#
# Only list what is actually installed: oh-my-zsh prints an error for every
# missing plugin on every shell start, which is noise you cannot act on until
# you next run install.sh.
#
# NOTE: zsh-syntax-highlighting must stay last — it wraps the line editor and
# anything loaded after it will not be highlighted.
plugins=()
for _p in git github brew kubectl jq zsh-autosuggestions zsh-syntax-highlighting; do
  if [[ -d "$ZSH/plugins/$_p" || -d "${ZSH_CUSTOM:-$ZSH/custom}/plugins/$_p" ]]; then
    plugins+=("$_p")
  fi
done
unset _p

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#333333,bg=black,bold,underline"

source "$ZSH/oh-my-zsh.sh"

# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------
export GIT_EDITOR="vim"
export VISUAL="vim"
export EDITOR="$VISUAL"

# ---------------------------------------------------------------------------
# Tooling
# ---------------------------------------------------------------------------
export HOMEBREW_AUTO_UPDATE_SECS=604800

# nvm — the path expression is the one nvm's own installer writes.
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# bun
export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && path=("$BUN_INSTALL/bin" $path)
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# fzf
[ -f "$HOME/.fzf.zsh" ] && source "$HOME/.fzf.zsh"

# Google Cloud SDK (installed by the gcloud-cli cask)
_gcloud_sdk="${HOMEBREW_PREFIX:-/opt/homebrew}/share/google-cloud-sdk"
[ -f "$_gcloud_sdk/path.zsh.inc" ] && source "$_gcloud_sdk/path.zsh.inc"
[ -f "$_gcloud_sdk/completion.zsh.inc" ] && source "$_gcloud_sdk/completion.zsh.inc"
unset _gcloud_sdk

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
# ~/.env holds machine-local key/value secrets and is never committed.
# `set -a` exports everything the file defines; quoted values and spaces survive.
if [ -f "$HOME/.env" ]; then
  set -a
  source "$HOME/.env"
  set +a
fi

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias tf='terraform'
alias kc='kubectl'
alias wind='windsurf'
alias python='python3'
alias pip='pip3'

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[ -f "$HOME/.p10k.zsh" ] && source "$HOME/.p10k.zsh"

# ---------------------------------------------------------------------------
# Machine-local overrides — last, so they win. Not in git.
# ---------------------------------------------------------------------------
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
