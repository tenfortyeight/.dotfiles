# Claude Code config

The portable half of `~/.claude` — generic engineering practice only, no job- or
machine-specific content. `../install.sh` symlinks it into place; `link.sh` does
the work and is safe to run on its own. It also removes links left dangling by a
file retired from this repo, so a deleted hook or agent doesn't linger.

## What is here

| Path | What it is |
|---|---|
| `CLAUDE.md` | Global instructions: TDD cycle, code principles, error handling, security basics, quality gates, git workflow, "verify don't recall", working hands-off, subagent delegation, definition of done |
| `settings.json` | Hook wiring, generic permission allow rules, theme, effort level, transcript retention. All paths `$HOME`-relative. Merged with the machine-local overlay, see below |
| `hooks/` | Eight enforcement hooks plus `test-guards.sh` |
| `skills/` | `go` (pre-PR chain), `scope`, `verify`, `checkpoint` |
| `agents/` | Four stack-generic Node.js reviewer agents |

## settings.json is built, not linked

Claude Code has only one settings file that applies in every project,
`~/.claude/settings.json`. It reads `~/.claude/settings.local.json` just for
sessions started in `~` itself. So a machine's own permissions, hooks and model
can't go in a file of their own that Claude Code picks up everywhere, and they
can't go here either, because this repo is public.

`link.sh` therefore **builds** `~/.claude/settings.json` by merging this
`settings.json` with an optional, untracked `~/.claude/settings.local.json`:
objects merge recursively, lists concatenate without duplicates, and a scalar in
the local file wins. Job-specific allow rules (internal CLIs, container names,
work directories) and machine-specific hooks go in the local file.

Two consequences:

- **Edit a source, then re-run `link.sh`.** Changing `claude/settings.json` does
  nothing until the next build.
- **Changes made inside Claude Code don't survive a build.** `/config`, `/model`
  and "don't ask again" write to the built file. The next build notices the
  drift, saves the old file to `~/.claude/backups/replaced-*/`, and overwrites
  it. Move anything worth keeping into `settings.local.json`.

## Auto mode

The auto mode classifier reads its `autoMode` block from `~/.claude/settings.json`
only — never from a repo's `.claude/settings*.json` — so the built file is the
one place it can live. Its three lists do different jobs, and mixing them up is
why routine deploys stayed blocked:

- **`allow`** is the only lever that clears a block. Each entry is a prose
  exception that overrides a matching `soft_deny` rule. The generic ones live
  here: user-requested operations, consent relayed to subagents, read-only
  diagnosis of your own prod host, decrypting your own sops secrets.
- **`environment`** is context, not permission. Telling it "operations the user
  asked for are routine" changes nothing; naming the deploy target, the prod host
  and the secrets store does. Those facts are job-specific, so they go in
  `settings.local.json`.
- **`soft_deny`** adds blocks. Here it only adds force-push and history rewrite on
  a default branch.

Every list starts with `"$defaults"`. Setting a list without it **replaces** the
shipped entries rather than adding to them. The lists concatenate on build, so
the one `"$defaults"` here covers the local entries too.

A subagent's classifier sees only the subagent's own transcript, not the "go"
you gave its parent — hence the relayed-consent rule. The classifier also
refuses to let a session widen its own `allow`. That is deliberate, so expect to
apply changes to it yourself.

`claude auto-mode config` prints what is in effect; `claude auto-mode critique`
reviews the custom rules.

## The hooks

Claude Code delivers each hook its payload as **JSON on stdin**. There is no
`$CLAUDE_TOOL_INPUT` or `$CLAUDE_FILE_PATH` environment variable — a hook written
against those greps an empty string, matches nothing, and exits 0. It looks
configured and enforces nothing. Every hook here reads stdin with `jq`.

| Hook | Event | Enforces |
|---|---|---|
| `deploy-ref-guard` | PreToolUse | No deploy unless `HEAD == origin/<default>` and the tree is clean (`# REF-OVERRIDE`) |
| `sops-guard` | PreToolUse | Never edit an encrypted SOPS file in place |
| `aws-profile-guard` | PreToolUse | Mutating AWS calls must name an explicit profile |
| `commit-hygiene` | PreToolUse | Oneliner commit messages, no heredocs |
| `stale-base-guard` | PreToolUse | Warns when committing onto a base that is behind origin |
| `terraform-push-reminder` | PreToolUse | Warns that CI is linux/amd64 before pushing `.tf` changes |
| `post-edit-validate` | PostToolUse | terraform fmt / yamllint / shellcheck / kustomize / JSON validity |
| `verifier-gate` | Stop | Blocks ending a turn on substantive unverified source changes |

Whether to deploy at all is left to auto mode and the instructions; the guard
only makes sure what gets deployed is what is on origin.

Run `bash ~/.claude/hooks/test-guards.sh` to confirm it fires.

### Per-repo specifics

The guards stay generic; a repo declares its own particulars:

- `.claude/deploy-commands` — extra deploy entrypoints, one extended-regex per
  line. Universal verbs (kubectl, terraform, helm, `gh pr merge`, `deploy.sh`)
  are already covered globally.
- `.claude/notify` — channel and target id for the optional `/go` notify step.
  Absent means the chain ends after the PR.

## Requirements

`jq` is required — every hook parses its payload with it. Without it the deploy
guard and `verifier-gate` warn on stderr and stand down; the remaining six go
quiet, so check for `jq` first if a hook seems inert. `verifier-gate` stands down
rather than blocking because its loop guard reads `stop_hook_active` through `jq`,
and a Stop hook that cannot read that flag could block repeatedly.

`jq`, `shellcheck` and `yamllint` are in the `Brewfile`. `terraform` and `kustomize`
are **not** — `post-edit-validate` skips whichever validators are absent, so install
them only if you work with those file types.

`peon-ping` is a Homebrew formula, not tracked here. The hook entries that call it
are guarded, so nothing breaks when it is absent.

## What is deliberately NOT here

`~/.claude` also holds transcripts (`projects/`), typed history, per-project
memory, caches and machine-local settings. Those are gitignored: they contain
employer work product, and memory holds personal notes. This repo is public.

`~/.claude` itself is a real directory, not a symlink to this one — only the files
in `link.sh`'s explicit list are linked, for the same reason the dotfiles symlink
loop uses a list rather than a glob.
