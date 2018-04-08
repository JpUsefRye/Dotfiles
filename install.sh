#1/bin/sh

echo "Installing .gdbinit"
cp .gdbinit ~/

echo "Installing .vimrc"
cp .vimrc ~/

echo "Installing vim colorscheme 'tender'"
mkdir -p ~/.vim/colors
cp vim/colors/tender.vim ~/.vim/colors

echo "Installing .bashrc"
cp .bashrc ~/
source ~/.bashrc

echo "Done"
