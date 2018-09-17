#!/usr/bin/env bash

function is-executable {
	if type "$1" >/dev/null 2>&1; then
		echo ""
	else
 		echo "command not found: $1"
	fi
}

# Get current dir so script can run from anywhere
export DOTFILES_DIR
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# self-update
if is-executable git -a -d "$DOTFILES_DIR/.git";
	then git --work-tree="$DOTFILES_DIR" --git-dir="$DOTFILES_DIR/.git" pull origin master;
fi

# install some tools
if is-executable brew; then
	# oh my zsh
	brew install zsh zsh-completions
	sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
	
	brew install git node yarn;
fi

# symlink dotfiles
for file in `find . -type f -name ".*[^\.swp]"`
do
	ln -sfv "$DOTFILES_DIR/${file##*/}" ~
done

# vim stuff
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
echo "Remember to run :PlugInstall in vim aswell...\n"

# setup ssh-keys and gitconfig
read -p "Git config display name: " name
read -p "Git config email and ssh email: " email

git config --global user.name "$name"
git config --global user.email "$email"

ssh-keygen -t rsa -b 4096 -C "$email"
eval "$(ssh-agent -s)"
ssh-add -K ~/.ssh/id_rsa
pbcopy < ~/.ssh/id_rsa.pub
echo "Your public sshkey is available in the clipboard\n"
