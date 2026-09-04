# Claude Code config

The portable half of `~/.claude` — generic engineering practice only, no job- or
machine-specific content. `../install.sh` symlinks it into place; `link.sh` does
the work and is safe to run on its own.

## What is here

| Path | What it is |
|---|---|
| `CLAUDE.md` | Global instructions: TDD cycle, code principles, error handling, security basics, quality gates, git workflow, "verify don't recall", definition of done |
| `settings.json` | Hook wiring, theme, effort level, transcript retention. All paths `$HOME`-relative |
| `hooks/` | Nine enforcement hooks plus `test-guards.sh` |
| `skills/` | `go` (pre-PR chain), `scope`, `verify`, `checkpoint` |
| `agents/` | Four stack-generic Node.js reviewer agents |

## The hooks

Claude Code delivers each hook its payload as **JSON on stdin**. There is no
`$CLAUDE_TOOL_INPUT` or `$CLAUDE_FILE_PATH` environment variable — a hook written
against those greps an empty string, matches nothing, and exits 0. It looks
configured and enforces nothing. Every hook here reads stdin with `jq`.

| Hook | Event | Enforces |
|---|---|---|
| `deploy-permission-guard` | PreToolUse | No deploy-shaped command without explicit approval (`# APPROVED`) |
| `deploy-ref-guard` | PreToolUse | No deploy unless `HEAD == origin/<default>` and the tree is clean (`# REF-OVERRIDE`) |
| `review-gate` | PreToolUse | No `gh pr create` without a review receipt for that SHA |
| `sops-guard` | PreToolUse | Never edit an encrypted SOPS file in place |
| `aws-profile-guard` | PreToolUse | Mutating AWS calls must name an explicit profile |
| `commit-hygiene` | PreToolUse | Oneliner commit messages, no heredocs |
| `terraform-push-reminder` | PreToolUse | Warns that CI is linux/amd64 before pushing `.tf` changes |
| `post-edit-validate` | PostToolUse | terraform fmt / yamllint / shellcheck / kustomize / JSON validity |
| `verifier-gate` | Stop | Blocks ending a turn on substantive unverified source changes |

The two deploy guards use **separate** override markers on purpose: approving a
deploy must not silently approve deploying the wrong ref.

Run `bash ~/.claude/hooks/test-guards.sh` to confirm they fire.

### Per-repo specifics

The guards stay generic; a repo declares its own particulars:

- `.claude/deploy-commands` — extra deploy entrypoints, one extended-regex per
  line. Universal verbs (kubectl, terraform, helm, `gh pr merge`, `deploy.sh`)
  are already covered globally.
- `.claude/notify` — channel and target id for the optional `/go` notify step.
  Absent means the chain ends after the PR.

## Requirements

`jq` is required — every hook parses its payload with it. The two deploy guards say
so loudly on stderr if it is missing rather than no-opping silently; the others do
go quiet, so check for it first if a hook seems inert.

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
