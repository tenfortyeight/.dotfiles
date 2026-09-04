# Everything this setup needs, declaratively. Install with:
#
#   brew bundle --file="$HOME/dotfiles/Brewfile"
#
# Safe to re-run — brew skips what is already present. Add to it freely; this
# file is meant to be edited by hand, not generated.

# Adopt, rather than refuse, an app that is already in /Applications.
#
# Applies to every cask below, so nothing here needs a per-app special case. By
# default a cask refuses to install over an app Homebrew did not put there —
# anything installed by hand from a .dmg, or deployed by MDM — and one such
# refusal is enough to make the whole bundle exit non-zero. Adopting takes the
# existing app under management instead, leaving the bundle green.
#
# Adoption still cannot touch a bundle owned by root: it runs a `chmod -R a+rX`
# through sudo, which fails wherever there is no terminal to prompt on. That is
# not fatal either — install.sh treats a failed entry as a warning and reports
# what is still unmet, because an app that is already installed and working
# does not need Homebrew's blessing to be usable.
cask_args adopt: true

# ---------------------------------------------------------------------------
# Shell
# ---------------------------------------------------------------------------
brew "zsh"
brew "zsh-completions"
# NOT zsh-autosuggestions / zsh-syntax-highlighting: the Homebrew builds install
# to the brew prefix, which oh-my-zsh does not scan, so they would appear
# installed while `plugins=(...)` still reported them missing. install.sh clones
# them into $ZSH_CUSTOM/plugins instead, along with the jq plugin.

# ---------------------------------------------------------------------------
# Core CLI
# ---------------------------------------------------------------------------
brew "git"
brew "gh"                           # .gitconfig delegates credentials to this
brew "vim"                          # $EDITOR
brew "ripgrep"                      # also backs the fzf and vim search commands
brew "fzf"
brew "jq"
brew "coreutils"
# Used by the Claude Code hooks in claude/hooks: jq parses every hook payload,
# shellcheck and yamllint back the post-edit validator. Without them the hooks
# degrade silently, which is the failure mode they exist to prevent.
brew "shellcheck"
brew "yamllint"

# ---------------------------------------------------------------------------
# Languages and runtimes
# ---------------------------------------------------------------------------
# nvm.sh lands in the brew prefix, NOT in $NVM_DIR — .zshrc checks both, and
# install.sh creates ~/.nvm, which Homebrew leaves to you.
brew "nvm"
brew "node"
brew "go"
brew "bun"                          # .zshrc puts ~/.bun/bin on PATH and loads its completions

# Python was previously present only because gcloud-cli depends on it, which
# meant `brew uninstall gcloud-cli` would have taken the interpreter with it.
# Declared here so it is installed on its own account. `python` is the alias for
# the current python@3.x, so this tracks a supported version rather than pinning
# one that will eventually go end-of-life.
brew "python"
brew "uv"                           # Python packaging/venv manager; also installs interpreters

# ---------------------------------------------------------------------------
# Infrastructure
# ---------------------------------------------------------------------------
brew "kubectl"
# No terraform: Homebrew dropped it from core after HashiCorp relicensed to BSL,
# so `brew "terraform"` fails the whole bundle. If you want it back, either
# `brew "hashicorp/tap/terraform"` with `tap "hashicorp/tap"` above, or
# `brew "opentofu"` — the drop-in fork, still in core, and it honours the
# .terraformrc plugin cache in this repo.

# ---------------------------------------------------------------------------
# Fonts
# ---------------------------------------------------------------------------
# powerlevel10k needs a Nerd Font. Install it here, then select it in the
# terminal profile by hand — see the README.
cask "font-meslo-lg-nerd-font"

# ---------------------------------------------------------------------------
# Desktop apps
# ---------------------------------------------------------------------------
cask "docker-desktop"               # also provides the built-in Kubernetes
cask "gcloud-cli"                   # .zshrc sources its path/completion from the brew prefix
cask "rectangle"                    # window snapping via keyboard shortcuts
cask "visual-studio-code"           # also puts the `code` CLI on PATH; $EDITOR stays vim
cask "firefox"
cask "google-chrome"
cask "claude"                       # Anthropic's desktop app
cask "claude-code"                  # the CLI
cask "aldente"                      # cap the battery charge percentage
cask "notunes"                      # stop Apple Music hijacking the play key
