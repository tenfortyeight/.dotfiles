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
  brew update
  brew tap caskroom/cask

	# oh my zsh
	brew install zsh zsh-completions
	sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
	
	brew install git node yarn ripgrep

  # dotnet core with extra symlink
  brew cask install dotnet
  ln -s /usr/local/share/dotnet/dotnet /usr/local/bin/

  # skaffold for K8s
  curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-darwin-amd64 && chmod +x skaffold && sudo mv skaffold /usr/local/bin
fi

# symlink dotfiles
for file in `find . -type f -name ".*[^\.swp]"`
do
	ln -sfv "$DOTFILES_DIR/${file##*/}" ~
done

source ./.zshrc
source ./.bashrc

# vim stuff
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
echo "Remember to run :PlugInstall in vim aswell...\n"

# zsh stuff
cp ./bullet-train.zsh-theme ~/.oh-my-zsh/custom/themes/
git clone https://github.com/powerline/fonts.git --depth=1
./fonts/install.sh
rm -rf fonts/
echo "Change font to Roboto Mono Medium 12 pt for both ascii and non-ascii fonts i iTerm\n"

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
echo "Remember to source .vimrc in vim\n"

