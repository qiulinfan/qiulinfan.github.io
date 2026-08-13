syntax on
filetype plugin indent on

set tabstop=2       " 设置Tab键的宽度
set softtabstop=2   " 按 Tab 键时插入的空格数
set shiftwidth=2    " 设置每级缩进的空格数
set expandtab       " 将Tab转换为相应的空格数，使用空格代替Tab
set autoindent      " 新行的缩进值与上一行相同
set smartindent     " 智能缩进，自动调整新行的缩进量

set rnu

"下面这段为支持C++开发如标准库代码补全的功能
call plug#begin()
Plug 'neoclide/coc.nvim'
Plug 'jiangmiao/auto-pairs'
Plug 'gruvbox-community/gruvbox'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'preservim/nerdtree'
call plug#end()

"下面这段为Tab代码补全
"use <tab> for trigger completion and navigate to the next complete item
function! CheckBackSpace() abort
    let col = col('.') - 1
    return !col || getline('.')[col - 1] =~ '\s'
endfunction

inoremap <silent><expr> <Tab> pumvisible() ? coc#pum#confirm() : "\<Tab>"

"nerdtree快捷键
inoremap <C-b> <Esc>:NERDTreeToggle<cr>
nnoremap <C-b> <Esc>:NERDTreeToggle<cr>

"下面这段为更改ll代替dd为删除一行
" 定义一个函数用于处理连续按下 l  的情况
function! DeleteLineIfPressedTwice()
    if exists('g:press_count') && g:press_count == 1
        " 执行删除行操作
        normal! dd
        " 重置按键计数
        let g:press_count = 0
    else
        " 设置按键计数
        let g:press_count = 1
        " 设置一个定时器，如果一定时间内没有再次按下，则重置按键计数
        call timer_start(500, {tid -> execute('let g:press_count = 0', '')})
    endif
endfunction
" 映射 l 键，以便调用上述函数
nnoremap <silent> l :call DeleteLineIfPressedTwice()<CR>

" 废弃 dd 按键映射
" nnoremap dd <Nop>

"d: 向右一个单词
nnoremap d w
"a: 向左一个单词
nnoremap a b
"w: 向上一行
nnoremap w k
"s: 向下一行
nnoremap s j
"Space: insert 模式
nnoremap <Space> i
nnoremap k <Nop>
nnoremap b <Nop>
nnoremap j <Nop>
nnoremap i <Nop>

set timeoutlen=500 " 映射等待时间减少到 500 毫秒
set ttimeoutlen=10 " 键码等待时间减少到 10 毫秒

"设置backspace 能够删除insert 模式下的输入
set backspace=indent,eol,start

"下面这段为更改<S-x>+<S-c>为insert模式进入normal模式
function! s:check_for_c()
    " 等待用户输入下一个字符
    let l:char = getchar()
    " 检查字符是否为 'c' 或 'C'
    if l:char == char2nr('c') || l:char == char2nr('C')
        " 如果是 'c'，则模拟按下 Esc
        call feedkeys("\<Esc>")
    else
        " 如果不是 'c'，则将之前按下的 'X' 和当前按键插入到文本中
        call feedkeys('X' . nr2char(l:char), 'n')
    endif
endfunction
" 在插入模式下，当按下 'X' 时，调用上面的函数
inoremap <expr> X '<Esc>:call <SID>check_for_c()<CR>'

" nerdtree 中光标的上下移动键位
autocmd FileType nerdtree map <buffer> w <Up>
autocmd FileType nerdtree map <buffer> s <Down>