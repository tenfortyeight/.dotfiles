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
brew "zsh-autosuggestions"          # plugin, loaded from .zshrc
brew "zsh-syntax-highlighting"      # plugin, must stay last in the plugins list

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
brew "terraform"                    # .terraformrc sets a shared plugin cache

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
