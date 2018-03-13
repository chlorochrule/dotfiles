" chlorochrule's init.vim
"
set encoding=utf-8
scriptencoding utf-8
let g:python3_host_prog = expand(system("which python | tr -d '\n'"))

if &compatible
  set nocompatible
endif

augroup MyAutoCmd
  autocmd!
augroup END


" vim-one setting
set background=dark
let g:airline_theme='one'
let g:one_allow_italics = 1

" true color setting
set termguicolors
set t_8b=^[[48;2;%lu;%lu;%lum
set t_8f=^[[38;2;%lu;%lu;%lum


" dein settings
let s:config = expand($XDG_CONFIG_HOME . '/nvim')
let s:cache = expand($XDG_CACHE_HOME . '/nvim')

let s:dein_cache = s:cache . '/dein/repos/github.com/Shougo/dein.vim'

if !isdirectory(s:dein_cache)
    execute '!git clone https://github.com/Shougo/dein.vim' . s:dein_cache
endif
execute 'set runtimepath^=' . s:dein_cache

if dein#load_state(s:dein_cache)
  call dein#begin(s:dein_cache)

  let s:toml = s:config . '/dein.toml'
  let s:lazy_toml = s:config . '/dein_lazy.toml'

  call dein#load_toml(s:toml, {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 1})

  call dein#end()
  call dein#save_state()
endif

if dein#check_install()
  call dein#install()
endif


" set vim-one colorscheme
colorscheme one


" option settings

" display
set number
set cursorline
set ruler
set nowrap
set notitle
set colorcolumn=79
set laststatus=2

" case
set ignorecase
set smartcase
set infercase

" tab and indent
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
set smarttab
set shiftround
set autoindent 
set smartindent
set cindent

" search
set wrapscan
set hlsearch
set incsearch

" io
set autoread
set hidden
set nobackup
set nowritebackup
set noswapfile
set undodir=~/.cache/nvim/undo
set undofile

" misc
set clipboard=unnamedplus
set showcmd
set showmatch
set backspace=indent,eol,start
set whichwrap=b,s,h,l,<,>,[,],~
set matchpairs+=<:>
set wildignore+=*.so,*.swp
set scrolloff=5
set sidescrolloff=15
set sidescroll=1
set ambiwidth=single
set synmaxcol=320
set history=1000
set fileformats=unix,dos,mac


" keymapping

" leader
let mapleader = "\<Space>"
nnoremap <Space> <Nop>
" tmux prefix
nnoremap <C-g> <Nop>

" nnoremap
nnoremap <silent> <ESC><ESC> :nohlsearch<CR>
nnoremap > >>
nnoremap < <<
nnoremap <C-r> r
nnoremap r <C-r>
nnoremap : ;
nnoremap ; :
nnoremap j gj
nnoremap gj j
nnoremap k gk
nnoremap gk k
nnoremap ZQ <Nop>
nnoremap s *N
nnoremap x "_x
nnoremap H gT
nnoremap L gt
nnoremap K 5k
nnoremap J 5j
nnoremap Y y$
nnoremap t g;
nnoremap T g,
nnoremap <Tab> %
vnoremap <Tab> %
nnoremap <Leader>w :w<CR>
nnoremap <Leader>q :q<CR>
nnoremap <Leader>Q :q!<CR>
nnoremap <Leader>h <C-w>h
nnoremap <Leader>j <C-w>j
nnoremap <Leader>k <C-w>k
nnoremap <Leader>l <C-w>l
nnoremap <Leader>- :split<CR>
nnoremap <Leader>\| :vsplit<CR>
nnoremap <Leader>t :tabnew<CR>
nnoremap <Leader>; :!
nnoremap <Leader>m <C-^>
nnoremap <C-H> <C-w><
nnoremap <C-J> <C-w>+
nnoremap <C-K> <C-w>-
nnoremap <C-L> <C-w>>
nnoremap <C-o> o<ESC>
" denite
nnoremap <Leader>o :Denite -mode=normal -default-action=tabopen file_rec<CR>
nnoremap <Leader>O :DeniteBufferDir -mode=normal -default-action=tabopen file_rec<CR>
nnoremap <Leader>g :Denite -mode=normal -default-action=tabopen -auto-preview -buffer-name=search-buffer-denite grep<CR>
nnoremap <Leader>G :Denite -resume -buffer-name=search-buffer-denite<CR>
nnoremap <Leader>s :DeniteCursorWord -mode=normal -default-action=tabopen -auto-preview -buffer-name=search-buffer-denite grep<CR>
nnoremap <Leader>b :Denite -mode=normal buffer<CR>

" inoremap
inoremap jj <ESC>
inoremap <C-d> <Delete>
inoremap <C-o> <BS>
inoremap <C-h> <Left>
inoremap <C-j> <Down>
inoremap <C-k> <Up>
inoremap <C-l> <Right>
inoremap <C-m> <CR>
inoremap <C-t> <ESC>g;

" cnoremap
cnoremap jj <C-c>
cnoremap <C-d> <Delete>
cnoremap <C-o> <BS>
cnoremap <C-h> <Left>
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-l> <Right>
cnoremap <C-m> <CR>

" vnoremap
vnoremap ; <ESC>
vnoremap > >gv
vnoremap < <gv

