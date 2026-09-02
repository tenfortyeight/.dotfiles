# Everything this setup needs, declaratively. Install with:
#
#   brew bundle --file="$HOME/dotfiles/Brewfile"
#
# Safe to re-run — brew skips what is already present. Add to it freely; this
# file is meant to be edited by hand, not generated.

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

# ---------------------------------------------------------------------------
# Languages and runtimes
# ---------------------------------------------------------------------------
brew "nvm"                          # .zshrc sources it from either brew or ~/.nvm
brew "node"
brew "go"

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
cask "rectangle"                    # window snapping via keyboard shortcuts
cask "claude"                       # Anthropic's desktop app
cask "aldente"                      # cap the battery charge percentage
cask "notunes"                      # stop Apple Music hijacking the play key
