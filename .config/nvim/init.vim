" chlorochrule's init.vim
"
set encoding=utf-8
scriptencoding utf-8

let g:python3_host_prog=expand(system("which python | tr -d '\n'"))

if &compatible
  set nocompatible
endif

if has('nvim')
    let $NVIM_TUI_ENABLE_TRUE_COLOR = 1
endif

augroup vimrc_augroup
  autocmd!
augroup END

" command alias
command! -nargs=* Gautocmd autocmd vimrc_augroup <args>
command! -nargs=* Gautocmdft autocmd vimrc_augroup FileType <args>


" true color setting
set termguicolors
set t_8b=^[[48;2;%lu;%lu;%lum
set t_8f=^[[38;2;%lu;%lu;%lum


" vim-plug setting
let s:nvim_home = expand($XDG_CACHE_HOME . '/nvim/vim-plug')
let s:plug_dir = s:nvim_home . '/site'
let g:plug = {
    \ 'home':    s:plug_dir,
    \ 'plug':    s:plug_dir . '/autoload/plug.vim',
    \ 'base':    s:nvim_home . '/plugged',
    \ 'url' :    'https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim',
    \ }

if !filereadable(g:plug.plug)
    execute '!mkdir -p ' . g:plug.home
    execute '!curl -fLo ' . g:plug.plug . ' --create-dirs ' . g:plug.url
endif

if !isdirectory(g:plug.base)
    execute '!mkdir -p ' . g:plug.base
endif

execute 'set runtimepath^=' . g:plug.home
execute 'set runtimepath^=' . g:plug.base

call plug#begin(g:plug.base)

Plug 'airblade/vim-gitgutter'
Plug 'christoomey/vim-tmux-navigator'
Plug 'cocopon/vaffle.vim'
Plug 'cohama/lexima.vim'
Plug 'davidhalter/jedi-vim', {'for': 'python'}
Plug 'itchyny/lightline.vim'
Plug 'joshdick/onedark.vim'
Plug 'junegunn/vim-easy-align'
Plug 'mengelbrecht/lightline-bufferline'
Plug 'Shougo/neosnippet'
Plug 'Shougo/neosnippet-snippets'
Plug 'Shougo/deoplete.nvim'
Plug 'Shougo/denite.nvim'
Plug 'thinca/vim-quickrun'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-fugitive'
Plug 'tyru/caw.vim'
Plug 'Vimjas/vim-python-pep8-indent', {'for': 'python'}
Plug 'w0rp/ale'
Plug 'zchee/deoplete-jedi', {'for': 'python'}

call plug#end()

for [name, spec] in items(g:plugs)
    if !isdirectory(spec.dir)
        PlugInstall
        break
    endif
endfor

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
set showtabline=2

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

" cmd
set wildmenu
set history=5000
set showcmd

" misc
set clipboard=unnamedplus
set showmatch
set backspace=indent,eol,start
set whichwrap=b,s,h,l,<,>,[,],~
set matchpairs+=<:>
set wildignore+=*.so,*.swp,*.o
set scrolloff=5
set sidescrolloff=15
set sidescroll=1
set ambiwidth=single
set synmaxcol=320
set history=1000
set fileformats=unix,dos,mac
set completeopt=menu,longest,noinsert
set mouse=a

" keymapping


" tmux ignore keys
noremap <C-g> <Nop>
noremap <C-t> <Nop>

" nnoremap
" leader
let mapleader = "\<Space>"
nnoremap <Space> <Nop>

function! s:quit_buffer() abort
    if len(getbufinfo({'buflisted': 1})) != 1
        bd
    else
        q
    endif
endfunction
command! QuitBuffer call <SID>quit_buffer()

nnoremap <silent>q :QuitBuffer<CR>
nnoremap <silent><ESC> :<C-u>nohlsearch<CR>
nnoremap > >>
nnoremap < <<
nnoremap <C-r> r
nnoremap r <C-r>
nnoremap <silent>R :<C-u>e!<CR>
nnoremap : ;
nnoremap ; :
nnoremap j gj
nnoremap gj j
nnoremap k gk
nnoremap gk k
nnoremap ZQ <Nop>
nnoremap s *N
nnoremap x "_x
nnoremap <silent>L :<C-u>bnext<CR>
nnoremap <silent>H :<C-u>bprevious<CR>
nnoremap K 5gk
nnoremap J 5gj
nnoremap Y y$
nnoremap z g;
nnoremap Z g,
nnoremap <Tab> %
nnoremap <silent><Leader>w :<C-u>w<CR>
nnoremap <silent><Leader>q :<C-u>q<CR>
nnoremap <silent><Leader>Q :<C-u>bd<CR>
nnoremap <silent><Leader>- :<C-u>split<CR>
nnoremap <silent><Leader>\ :<C-u>vsplit<CR>
nnoremap <C-o> o<ESC>
nnoremap <silent>X <C-o>

" inoremap
inoremap jj <ESC>
inoremap <C-d> <Delete>
inoremap <C-o> <C-o>o
inoremap <C-w> <ESC>ciw
inoremap <C-r> <C-o><C-r>
inoremap <C-u> <C-o>u
inoremap <C-d> <C-u>
inoremap <C-h> <Left>
inoremap <expr><C-j> pumvisible() ? "\<C-n>" : "\<Down>"
inoremap <expr><C-k> pumvisible() ? "\<C-p>" : "\<Up>"
inoremap <C-l> <Right>
" inoremap <C-t> <ESC>g;
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
vnoremap u <ESC>ugv
vnoremap s y/<C-r>"<CR>N
vnoremap <Tab> %

" readonly
Gautocmd BufReadPost * if &readonly | nnoremap <buffer>q :<C-u>bd<CR> | endif
Gautocmd BufWritePost ~/.config/nvim/init.vim :<C-u>source ~/.config/nvim/init.vim<CR>


" quickfix
if has_key(g:plugs, 'vim-quickrun')
    let g:quickrun_config = get(g:, 'quickrun_config', {})
    let g:quickrun_config._ = {
        \ 'runner'    : 'vimproc',
        \ 'runner/vimproc/updatetime' : 60,
        \ 'outputter' : 'error',
        \ 'outputter/error/success' : 'buffer',
        \ 'outputter/error/error'   : 'quickfix',
        \ 'outputter/buffer/split'  : ':rightbelow 8sp',
        \ 'outputter/buffer/close_on_empty' : 1,
        \ }
    nnoremap <silent><Leader>e :<C-u>cclose<CR>:w<CR>:QuickRun<CR>
endif

" plugin
" neosnippet, deoplete
" call deoplete#custom#source('jedi', 'matchers', ['matcher_fuzzy'])
if has_key(g:plugs, 'lexima.vim')
    call lexima#init()
endif

if has_key(g:plugs, 'neosnippet') 
    imap <expr><CR> neosnippet#expandable() ?
        \ "\<Plug>(neosnippet_expand)" : "\<CR>"
    smap <expr><Tab> neosnippet#jumpable() ? "\<Plug>(neosnippet_jump)" : "\<Tab>"
    if has_key(g:plugs, 'deoplete.nvim')
        imap <expr><Tab> neosnippet#jumpable() ? "\<Plug>(neosnippet_jump)" :
            \ pumvisible() ? deoplete#mappings#close_popup() : "\<Tab>"
    endif
endif

if has_key(g:plugs, 'deoplete.nvim')
    let g:deoplete#auto_complete_delay = 0
    let g:deoplete#enable_at_startup = 1
    let g:deoplete#enable_smart_case = 1
    let g:deoplete#enable_refresh_always = 0
    let g:deoplete#auto_refresh_delay = 100
    let g:deoplete#max_list = 1000
    let g:deoplete#auto_complete_start_length = 2
endif

if has_key(g:plugs, 'denite.nvim')
    nnoremap <silent>m :<C-u>Denite -mode=normal -immediately buffer<CR>
    nnoremap <silent>t :<C-u>tabe %<CR>:Denite -mode=normal -immediately buffer<CR>
    nnoremap <silent>T :<C-u>-tabe %<CR>:Denite -mode=normal -immediately buffer<CR>
    nnoremap <silent><Leader>o :<C-u>Denite -mode=normal -default-action=tabopen file_rec<CR>
    nnoremap <silent><Leader>O :<C-u>DeniteBufferDir -mode=normal -default-action=tabopen file_rec<CR>
    nnoremap <silent><Leader>g :<C-u>Denite -mode=normal -default-action=tabopen -auto-preview -buffer-name=search-buffer-denite grep<CR>
    nnoremap <silent><Leader>G :<C-u>Denite -resume -buffer-name=search-buffer-denite<CR>
    nnoremap <silent><Leader>s :<C-u>DeniteCursorWord -mode=normal -default-action=tabopen -auto-preview -buffer-name=search-buffer-denite grep<CR>
    nnoremap <silent><Leader>b :<C-u>Denite -mode=normal buffer<CR>
endif

if has_key(g:plugs, 'vaffle.vim')
    let g:vaffle_force_delete = 1
    let g:vaffle_show_hidden_files = 1
    nnoremap <silent><Leader>v :<C-u>Vaffle<CR>
    Gautocmdft vaffle nmap <silent><buffer><nowait> q <Plug>(vaffle-quit)
endif

if has_key(g:plugs, 'jedi-vim')
    let g:jedi#auto_initialization = 0
    let g:jedi#auto_vim_configuration = 0
    let g:jedi#completions_enabled = 0
    let g:jedi#smart_auto_mappings = 0
    let g:jedi#completions_command = ""
    let g:jedi#goto_command = ""
    let g:jedi#goto_assignments_command = "<Leader>a"
    let g:jedi#documentation_command = "<Leader>k"
    let g:jedi#rename_command = "<Leader>r"
    let g:jedi#usages_command = ""
    Gautocmdft python nnoremap <silent><buffer><Leader>k :<C-u>call jedi#show_documentation()<CR>
    Gautocmdft python nnoremap <silent><buffer><Leader>a :<C-u>call jedi#goto_assignments()<CR>
    Gautocmdft python nnoremap <silent><buffer><Leader>r :<C-u>call jedi#rename()<CR>
endif

if has_key(g:plugs, 'deoplete.jedi')
    let g:deoplete#sources#jedi#statement_length = 0
    let g:deoplete#sources#jedi#short_types = 0
    let g:deoplete#sources#jedi#show_docstring = 0
    let g:deoplete#sources#jedi#worker_threads = 2
    let g:deoplete#sources#jedi#python_path = g:python3_host_prog
endif

if has_key(g:plugs, 'vim-fugitive')
    nmap [fugitive] <Nop>
    nmap <C-f> [fugitive]
    nnoremap <silent>[fugitive]b :<C-u>Gblame<CR>
    nnoremap <silent>[fugitive]d :<C-u>Gdiff<CR>
    nnoremap <silent>[fugitive]l :<C-u>Glog<CR>
    nnoremap <silent>[fugitive]s :<C-u>Gstatus<CR>
endif

if has_key(g:plugs, 'ale')
    let g:ale_sign_column_always = 1
    let g:ale_lint_on_text_changed = 0
    let g:ale_fixers = {
        \ 'python': ['autopep8', 'isort']
        \ }
    nnoremap <silent><Leader>f :<C-u>ALEFix<CR>
    nmap <C-n> <Plug>(ale_next)
    nmap <C-p> <Plug>(ale_previous)
endif

if has_key(g:plugs, 'vim-surround')
    vmap ' S'gv
    vmap " S"gv
    vmap ` S`gv
    vmap ( S)gv
    vmap ) S(gv
    vmap { S}gv
    vmap } S{gv
    Gautocmd BufEnter * vmap <buffer><nowait> [ S]gv
    Gautocmd BufEnter * vmap <buffer><nowait> ] S[gv
endif

if has_key(g:plugs, 'vim-easy-align')
    xmap ga <Plug>(EasyAlign)
    nmap ga <Plug>(EasyAlign)
endif

if has_key(g:plugs, 'caw.vim')
    let g:caw_no_default_keymappings = 1
    nmap <C-_> <Plug>(caw:hatpos:toggle)
    vmap <C-_> <Plug>(caw:hatpos:toggle)
    imap <expr><C-_> "\<ESC>\<Plug>(caw:hatpos:toggle)a"
endif

if has_key(g:plugs, 'vim-gitgutter')
    set signcolumn=yes
    set updatetime=200
endif

if has_key(g:plugs, 'lightline.vim')
    let g:lightline = {
        \ 'colorscheme': 'one',
        \ 'tabline': {'left': [['buffers']], 'right': [['close']]},
        \ 'component_expand': {'buffers': 'lightline#bufferline#buffers'},
        \ 'component_type': {'buffers': 'tabsel'},
        \ 'active': {
        \     'left' : [['mode', 'paste'], ['fugitive', 'filename', 'readonly', 'modified']],
        \     'right': [['lineinfo'], ['percent'], ['ale', 'char_code', 'fileformat', 'fileencoding', 'filetype']]
        \ }, 
        \ 'component': {
        \   'lineinfo': ' %3l:%-2v',
        \ },
        \ 'component_function': {
        \   'readonly': 'LightlineReadonly',
        \   'fugitive': 'LightlineFugitive',
        \   'ale'     : 'LightlineAleInfo'
        \ },
        \ 'separator': { 'left': '', 'right': '' },
        \ 'subseparator': { 'left': '', 'right': '' }
        \ }
    function! LightlineReadonly()
        return &readonly ? '' : ''
    endfunction
    function! LightlineFugitive()
        if exists('*fugitive#head')
            let branch = fugitive#head()
            return branch !=# '' ? ''.branch : ''
        endif
        return ''
    endfunction
    function! LightlineAleInfo()
        if !exists('g:ale_buffer_info')
            return ''
        endif
        let l:ale_info = ale#statusline#Count(bufnr('%'))
        let l:warn_info = l:ale_info.warning ? "\uf420 " . l:ale_info.warning : ''
        let l:error_info = l:ale_info.error ? "\uf071 " . l:ale_info.error : ''
        return l:warn_info . ' ' . l:error_info
    endfunction
endif
