call plug#begin('~/.vim/plugged')
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
  Plug 'tpope/vim-commentary'
call plug#end()

colorscheme onedark
syntax on
set number
set relativenumber
hi LineNr ctermfg=DarkGray
" make background translucent
hi Normal ctermbg=None

set tabstop=4
set softtabstop=4
set shiftwidth=4
set autoindent
set copyindent
" Render tab, eol and trailing whitespaces
set list
set listchars=tab:»\ ,eol:¬,trail:·

" Set .pl to prolog
autocmd BufNewFile,BufRead *.pl set filetype=prolog
