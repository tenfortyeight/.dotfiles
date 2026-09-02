# dotfiles

zsh + oh-my-zsh + powerlevel10k, vim, git, and the handful of apps I want on a
Mac. Everything here is public, so nothing machine- or job-specific lives in it
— see [Machine-local config](#machine-local-config) for where that goes.

## Bootstrap a new Mac

```sh
git clone https://github.com/tenfortyeight/.dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` is idempotent — re-run it any time. It installs Homebrew if it is
missing, applies the `Brewfile`, sets up oh-my-zsh and powerlevel10k, symlinks
everything into `$HOME`, and generates an ed25519 SSH key if there isn't one
(copying the public half to the clipboard).

Then open a new terminal and do the three things below that no script can.

## After the bootstrap

**Pick the Nerd Font.** powerlevel10k draws its prompt with glyphs that only
exist in a Nerd Font. The `Brewfile` installs MesloLGS NF, but selecting it is a
terminal setting: Terminal or iTerm → Profiles → Text → Font → **MesloLGS NF**.
Without this the prompt renders as tofu boxes.

**Launch Docker Desktop once.** It installs the `docker` and `docker compose`
CLI shims on first run, so they will not exist until you have opened the app.

**Enable Kubernetes if you want it.** Docker Desktop ships a single-node
cluster: Settings → Kubernetes → Enable. It is off by default and `brew bundle`
cannot turn it on.

Optionally, `p10k configure` to re-run the prompt wizard — though `.p10k.zsh` is
committed here, so the prompt should already look right.

## Machine-local config

Anything specific to one machine or one job goes in `~/.zshrc.local`, which
`.zshrc` sources last (so it wins) and `.gitignore` excludes. Employer tooling,
work-only `PATH` entries, client credentials helpers — all of it belongs there,
never in this repo.

Secrets go in `~/.env` as `KEY=value` pairs. `.zshrc` exports them if the file
exists and ignores it if not. Also gitignored, also never committed.

## What's here

| File | |
|---|---|
| `.zprofile` | Homebrew shellenv — login shells only, so `.zshrc` can assume `brew` is on `PATH` |
| `.zshrc` | shell config: oh-my-zsh, plugins, nvm, bun, fzf, gcloud, aliases |
| `.p10k.zsh` | the prompt itself |
| `.gitconfig` | identity, vim as editor, `gh` as the credential helper |
| `.vimrc` | vim-plug plugin set, fzf/ripgrep search bindings |
| `.terraformrc` | shared provider plugin cache, so workspaces don't each download their own |
| `.bashrc` / `.bash_profile` | minimal — bash is the fallback shell, not the daily one |
| `Brewfile` | every package and app, applied by `brew bundle` |
| `install.sh` | the bootstrap |

## Notes

`nvm` is sourced from whichever location it was installed to — Homebrew's prefix
or `~/.nvm` — so it works whether it came from `brew` or from nvm's own
installer.

powerlevel10k is cloned by `install.sh` rather than vendored into this repo, so
it updates independently of these dotfiles.
