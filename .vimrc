set relativenumber
set numberwidth=3
set laststatus=2
set statusline += "%F"

let mapleader = "\<Space>"
nnoremap <Leader>o :Files<CR>
nnoremap <Leader>b :Buffer<CR>

let g:airline#extensions#tabline#enabled = 1
let g:indent_guides_enable_on_vim_startup=1
let g:rg_command = '
  \ rg --column --line-number --no-heading --fixed-strings --ignore-case --follow --color "always"
  \ -g "*.{js,json,php,md,styl,jade,html,config,py,cpp,c,go,hs,rb,conf}"
  \ -g "!{.git,node_modules,dist,vendor}/*" '

command! -bang -nargs=* F call fzf#vim#grep(g:rg_command .shellescape(<q-args>), 1, <bang>0)

call plug#begin('~/.vim/plugged')
  Plug 'morhetz/gruvbox'
  Plug 'nathanaelkane/vim-indent-guides'
  Plug 'airblade/vim-gitgutter'
  Plug 'jremmen/vim-ripgrep'
  Plug 'qpkorr/vim-bufkill'
  Plug 'vim-airline/vim-airline'

  Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
  Plug 'junegunn/fzf.vim'
call plug#end()

" Turn on syntax highlighting on mac
filetype plugin indent on
set term=xterm-256color
syntax on
set termguicolors
colorscheme gruvbox

" Set space indentation
filetype plugin indent on
set tabstop=2
set shiftwidth=2
set expandtab
