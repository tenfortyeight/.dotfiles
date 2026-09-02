# Login shell. Homebrew belongs here, not in .zshrc — it only needs setting once
# per login, and .zshrc runs for every subshell.
#
# `brew shellenv` exports PATH, MANPATH, INFOPATH and HOMEBREW_PREFIX.
# /opt/homebrew is Apple Silicon, /usr/local is Intel.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  if [ -x "$_brew" ]; then
    eval "$("$_brew" shellenv)"
    break
  fi
done
unset _brew
