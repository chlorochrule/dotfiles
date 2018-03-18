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


" true color setting
set termguicolors
set t_8b=^[[48;2;%lu;%lu;%lum
set t_8f=^[[38;2;%lu;%lu;%lum


" dein settings
let s:config_dir = expand($XDG_CONFIG_HOME . '/nvim')
let s:cache_dir = expand($XDG_CACHE_HOME . '/nvim')
let s:dein_dir = s:cache_dir . '/dein'

let s:dein_repo_dir = s:dein_dir . '/repos/github.com/Shougo/dein.vim'

if !isdirectory(s:dein_repo_dir)
    execute '!mkdir -p ' . s:dein_repo_dir
    execute '!git clone https://github.com/Shougo/dein.vim ' . s:dein_repo_dir
endif

execute 'set runtimepath^=' . s:dein_repo_dir

if dein#load_state(s:dein_dir)
  call dein#begin(s:dein_dir)

  call dein#add('Shougo/vimproc.vim', {'build' : 'make'})

  let s:toml = s:config_dir . '/dein.toml'
  let s:lazy_toml = s:config_dir . '/dein_lazy.toml'

  call dein#load_toml(s:toml, {'lazy': 0})
  call dein#load_toml(s:lazy_toml, {'lazy': 1})

  call dein#end()
  call dein#save_state()
endif

if dein#check_install()
  call dein#install()
endif


filetype plugin indent on


" set onedark.vim colorscheme
colorscheme onedark


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
set modifiable
set write

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
nnoremap <silent> <ESC><ESC> :<C-u>nohlsearch<CR>
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
nnoremap z g;
nnoremap Z g,
nnoremap m :<C-u>Denite -mode=normal -immediately buffer<CR>
nnoremap t :<C-u>tabe %<CR>:Denite -mode=normal -immediately buffer<CR>
nnoremap T :<C-u>-tabe %<CR>:Denite -mode=normal -immediately buffer<CR>
nnoremap <Tab> %
vnoremap <Tab> %
nnoremap <Leader>w :<C-u>w<CR>
nnoremap <Leader>q :<C-u>q<CR>
nnoremap <Leader>Q :<C-u>bd<CR>
nnoremap <Leader>- :<C-u>split<CR>
nnoremap <Leader>\| :<C-u>vsplit<CR>
nnoremap <C-h> <C-w>k
nnoremap <C-j> <C-w>+
nnoremap <C-k> <C-w>-
nnoremap <C-l> <C-w>j
nnoremap <C-o> o<ESC>
" denite
nnoremap <Leader>o :<C-u>Denite -mode=normal -default-action=tabopen file_rec<CR>
nnoremap <Leader>O :<C-u>DeniteBufferDir -mode=normal -default-action=tabopen file_rec<CR>
nnoremap <Leader>g :<C-u>Denite -mode=normal -default-action=tabopen -auto-preview -buffer-name=search-buffer-denite grep<CR>
nnoremap <Leader>G :<C-u>Denite -resume -buffer-name=search-buffer-denite<CR>
nnoremap <Leader>s :<C-u>DeniteCursorWord -mode=normal -default-action=tabopen -auto-preview -buffer-name=search-buffer-denite grep<CR>
nnoremap <Leader>b :<C-u>Denite -mode=normal buffer<CR>

" inoremap
inoremap jj <ESC>
inoremap <C-d> <Delete>
inoremap <C-o> <BS>
inoremap <C-h> <Left>
inoremap <expr><C-j> pumvisible() ? "\<C-n>" : "\<Down>"
inoremap <expr><C-k> pumvisible() ? "\<C-p>" : "\<Up>"
inoremap <C-l> <Right>
inoremap <C-t> <ESC>g;
inoremap <C-Space> <Space>
inoremap <C-BS> <BS>

" cnoremap
cnoremap jj <C-c>
cnoremap <C-d> <Delete>
cnoremap <C-o> <BS>
cnoremap <C-h> <Left>
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-l> <Right>

" vnoremap
vnoremap ; <ESC>
vnoremap > >gv
vnoremap < <gv

" quickfix
autocmd FileType qf nnoremap <buffer>q :<C-u>q<CR>
nnoremap <Leader>e :<C-u>cclose<CR>:w<CR>:QuickRun<CR>

" plugin
" neosnippet, deoplete
" call deoplete#custom#source('jedi', 'matchers', ['matcher_fuzzy'])
call lexima#init()
imap <expr><CR> neosnippet#expandable() ?
    \ "\<Plug>(neosnippet_expand)" : "\<CR>"
imap <expr><Tab> neosnippet#jumpable() ? "\<Plug>(neosnippet_jump)" :
    \ pumvisible() ? deoplete#mappings#close_popup() : "\<Tab>"

" vaffle
call lexima#init()
nnoremap <Leader>f :<C-u>Vaffle<CR>

" jedi-vim
" autocmd FileType python setlocal completeopt-=preview
autocmd Filetype python nnoremap <silent><buffer><Leader>k :<C-u>call jedi#show_documentation()<CR>
autocmd Filetype python nnoremap <silent><buffer><Leader>a :<C-u>call jedi#goto_assignments()<CR>
autocmd Filetype python nnoremap <silent><buffer><Leader>r :<C-u>call jedi#rename()<CR>

" fugitive
nmap [fugitive] <Nop>
nmap <C-f> [fugitive]
nnoremap [fugitive]b :<C-u>Gblame<CR>
nnoremap [fugitive]d :<C-u>Gdiff<CR>
nnoremap [fugitive]l :<C-u>Glog<CR>
nnoremap [fugitive]s :<C-u>Gstatus<CR>
