set nocompatible

" Keybindings
nmap ; :
nmap j gj
nmap k gk

" w!! to write a file as sudo
" stolen from Steve Losh
cmap w!! w !sudo tee % >/dev/null

set mouse=a
set noerrorbells
set tabstop=4
set softtabstop=4
set smarttab
set number
filetype indent on
set wildmenu
set lazyredraw

" Search settings
set showmatch
set incsearch
set hlsearch
nmap <silent> // :nohlsearch<CR>

" Fold Settings
set foldenable
nnoremap <space> za
set foldmethod=indent

" Vim-Plug Section
call plug#begin('~/.vim/plugged')

Plug 'tpope/vim-sensible'
Plug 'tpope/vim-git'
Plug 'henrik/vim-indexed-search'
Plug 'christoomey/vim-tmux-navigator'
Plug 'tpope/vim-commentary'

" Basic C# language support. Omnisharp is too heavy-weight for the editing I do in VIM.
Plug 'OrangeT/vim-csharp'

" Language features
Plug 'sheerun/vim-polyglot'
Plug 'jtratner/vim-flavored-markdown'
Plug 'vim-syntastic/syntastic'

" Display features
Plug 'chriskempson/base16-vim'
Plug 'airblade/vim-gitgutter'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'nathanaelkane/vim-indent-guides'

call plug#end()

" Airline customization
let g:airline_theme='base16'
let g:airline_powerline_fonts = 1

" Include base16 info. Make sure to run base16-ocean from the command line
" first
if filereadable(expand("~/.vimrc_background"))
  let base16colorspace=256
  source ~/.vimrc_background
endif

" Change the mintty cursor when changing modes
let &t_ti.="\e[1 q"
let &t_SI.="\e[5 q"
let &t_EI.="\e[1 q"
let &t_te.="\e[0 q"

" Indent guids config
let g:indent_guides_auto_colors = 1
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size = 1
