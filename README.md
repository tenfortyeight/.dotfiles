# dotfiles

zsh + oh-my-zsh + powerlevel10k, vim, git, Claude Code, and the handful of apps I
want on a Mac. Everything here is public, so nothing machine- or job-specific
lives in it — see [Machine-local config](#machine-local-config) for where that
goes.

[`claude/`](claude/) holds the portable half of `~/.claude`: global engineering
instructions, nine enforcement hooks, four skills and four agents. Transcripts,
history and per-project memory stay machine-local and gitignored. See
[claude/README.md](claude/README.md).

## Bootstrap a new Mac

```sh
git clone https://github.com/tenfortyeight/.dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` is idempotent — re-run it any time. It installs Homebrew if it is
missing, applies the `Brewfile`, sets up oh-my-zsh and powerlevel10k, symlinks
everything into `$HOME`, links the VS Code key bindings, puts the macOS window
shortcuts on Rectangle's chords, points iTerm2's split panes at the current
directory, generates an ed25519 SSH key if there isn't one (copying the public
half to the clipboard), and logs in to `gh`.

If the machine will pull private packages from a registry, `gh` needs scopes
beyond its defaults of `repo`, `read:org` and `gist`. Pass them in rather than
committing them here — which registry and which scopes is job-specific, and
naming either would tie this repo to an employer:

```sh
GH_SCOPES=read:packages ./install.sh
```

Which extra scopes a given machine actually needed is recorded in that
machine's own [machine-local files](#machine-local-config), not in this repo.
Those files are deliberately not backed up anywhere, so treat this as the only
reminder that the step exists — if a private install 401s or 404s on a new
machine, a missing scope is the first thing to check, and `gh auth refresh -s
<scope>` adds one without redoing the login.

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

**Install the vim plugins.** `install.sh` fetches vim-plug, but the plugins in
`.vimrc` are pulled by vim itself:

```sh
vim +PlugInstall +qall
```

Or open vim and run `:PlugInstall`. Re-run it after adding a `Plug` line;
`:PlugClean` removes ones you have deleted.

Optionally, `p10k configure` to re-run the prompt wizard — though `.p10k.zsh` is
committed here, so the prompt should already look right.

## Machine-local config

**This repo is public.** Nothing that identifies an employer, a client, or an
internal system belongs in it — not just credentials, but names too: private
registry hostnames, package scopes, internal CLIs, service names, work
directory paths. Any one of those is enough to tie this repo to a company.

Everything of that kind goes in a file under `$HOME` that this repo never
tracks. `install.sh` does not create or symlink any of them, and each is
optional — the shell and git both work with none of them present.

| File | |
|---|---|
| `~/.zshrc.local` | shell config for this machine or this job: work-only `PATH` entries, per-employer CLI completions, tool env vars. `.zshrc` sources it **last**, so it can override anything above |
| `~/.env` | secrets as `KEY=value` pairs. `.zshrc` exports the lot with `set -a` if the file exists |
| `~/.gitconfig.local` | git config for this machine. `.gitconfig` includes it last, so a `[user]` block here overrides the personal identity. The right place for a `includeIf "gitdir:…"` that switches identity per work directory |
| `~/.gitconfig.work` | the per-job identity itself, pulled in by the conditional include above |
| `~/.npmrc` | private package scope → registry mappings, and the auth token for them |

**Keep tokens out of files.** Where a tool reads `${VAR}` from the environment
— `.npmrc` does — point it at a variable and export that from
`~/.zshrc.local`, sourcing the value from a credential store rather than
writing it down:

```sh
export SOME_TOKEN="$(gh auth token 2>/dev/null)"
```

The token then lives only in the macOS keychain. The cost is about 100 ms per
interactive shell, and that the variable is absent in contexts that never
source `~/.zshrc.local` — a `launchd` job, some IDE task runners — where the
tool will fail to authenticate rather than fail obviously. Put the token
literally in the file if you need it to work everywhere, and `chmod 600` it.

## What's here

| File | |
|---|---|
| `.zprofile` | Homebrew shellenv — login shells only, so `.zshrc` can assume `brew` is on `PATH` |
| `.zshrc` | shell config: oh-my-zsh, plugins, nvm, bun, fzf, gcloud, aliases |
| `.p10k.zsh` | the prompt itself |
| `.gitconfig` | identity, vim as editor, `gh` as the credential helper, and an include of `~/.gitconfig.local` |
| `.vimrc` | vim-plug plugin set, fzf/ripgrep search bindings |
| `.terraformrc` | shared provider plugin cache, so workspaces don't each download their own |
| `.bashrc` / `.bash_profile` | minimal — bash is the fallback shell, not the daily one |
| `Brewfile` | every package and app, applied by `brew bundle` |
| `claude/` | the portable half of `~/.claude` — instructions, enforcement hooks, skills, agents. `claude/link.sh` symlinks them in; see [claude/README.md](claude/README.md) |
| `vscode/` | VS Code key bindings. Only `keybindings.json` — `settings.json` is left machine-local |
| `macos/` | macOS system settings applied by script rather than symlink — currently the window tiling shortcuts |
| `install.sh` | the bootstrap |

## Notes

**zsh plugins.** `git`, `github`, `brew` and `kubectl` ship with oh-my-zsh.
`jq`, `zsh-autosuggestions` and `zsh-syntax-highlighting` do not — `install.sh`
clones them into `$ZSH_CUSTOM/plugins`. Installing the zsh-users ones with
Homebrew is not enough: those land in the brew prefix, which oh-my-zsh never
scans, so they look installed while every shell start still reports them
missing. `.zshrc` only enables plugins that are actually present, so a fresh
machine is quiet rather than noisy before `install.sh` has run.

`zsh-syntax-highlighting` must stay last in the plugin list — it wraps the line
editor, and anything loaded after it goes unhighlighted. It is also why the
powerlevel10k instant-prompt block at the top of `.zshrc` is commented out: the
two fight over the line editor during startup.

`nvm` is sourced from whichever location it was installed to — Homebrew's prefix
or `~/.nvm` — so it works whether it came from `brew` or from nvm's own
installer.

**Window shortcuts.** macOS has its own window tiling, but it ships on `^🌐` and
`^⇧🌐` chords that need the globe key. `macos/window-shortcuts.sh` moves the
built-in actions onto the `^⌥` layout Rectangle uses, so the muscle memory
carries over without running another app. It writes
`com.apple.symbolichotkeys` and is idempotent.

Two things about that domain are worth knowing before editing the script,
because both fail in the same misleading way — the shortcut appears correctly in
System Settings and then never fires. Values must be written as **integers**,
which is why the script goes through `PlistBuddy` and not `defaults write`; and
the character code must be `65535` for any key that produces no character,
**including return and delete**, not that key's literal ASCII.

Only the actions macOS actually has are mapped. Rectangle's thirds,
maximize-height, grow/shrink and move-to-next-display have no built-in
counterpart, so those still want Rectangle itself.

**iTerm2 split panes.** A new split pane should carry on in the directory the
pane you split was in, while a new tab or window starts clean at `$HOME`.
iTerm2 can express that, but only through the **Advanced** working-directory
mode — the other three modes answer the same way for panes, tabs and windows.
`macos/iterm-working-directory.sh` sets that mode on every profile and is
idempotent. No shell integration is needed: iTerm2 asks the pane's process where
it is, through the `pidinfo` XPC service it ships with.

It is a settings file like any other, with one wrinkle: iTerm2 holds every
profile in memory and writes the whole set back when it quits, so a change made
underneath a running copy can be undone the moment you quit it. The script says
so when it sees iTerm2 running — quit it and re-run.

`vscode/keybindings.json` is part of the same change rather than a separate
concern: VS Code binds `^⌥←`, `^⌥→` and `^⌥⌫` to camelCase sub-word editing
whenever a text input has focus, and an app binding beats a system hotkey. Left
alone, the window stays put and `^⌥⌫` eats half a word instead. VS Code rewrites
that file when you edit shortcuts through its UI, which can replace the symlink
with a plain file — re-run `install.sh` to restore it.

powerlevel10k is cloned by `install.sh` rather than vendored into this repo, so
it updates independently of these dotfiles.
