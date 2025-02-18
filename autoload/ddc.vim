function! ddc#enable() abort
  " Dummy call
  silent! call denops#plugin#is_loaded('ddc')
  if !exists('*denops#plugin#is_loaded')
    call ddc#util#print_error('denops.vim is not released or too old.')
    return
  endif

  if denops#plugin#is_loaded('ddc')
    return
  endif

  if !has('patch-8.2.0662') && !has('nvim-0.8')
    call ddc#util#print_error(
          \ 'ddc requires Vim 8.2.0662+ or neovim 0.8.0+.')
    return
  endif

  augroup ddc
    autocmd!
    autocmd User DDCReady :
    autocmd InsertLeave * call ddc#_hide('InsertLeave')
  augroup END

  " Force context_filetype call
  silent! call context_filetype#get_filetype()

  let g:ddc#_started = reltime()

  " Note: ddc.vim must be registered manually.
  autocmd ddc User DenopsReady silent! call ddc#_register()
  if exists('g:loaded_denops') && denops#server#status() ==# 'running'
    silent! call ddc#_register()
  endif
endfunction
function! ddc#enable_cmdline_completion() abort
  call ddc#enable()

  augroup ddc-cmdline
    autocmd!
    autocmd CmdlineLeave <buffer> call ddc#_hide('CmdlineLeave')
    autocmd CmdlineEnter <buffer> call ddc#_on_event('CmdlineEnter')
    autocmd CmdlineChanged <buffer>
          \ if getcmdtype() !=# '=' && getcmdtype() !=# '@' |
          \ call ddc#_on_event('CmdlineChanged') | endif
  augroup END
  if exists('##ModeChanged')
    autocmd ddc-cmdline ModeChanged *:n
          \ call ddc#disable_cmdline_completion()
  else
    autocmd ddc-cmdline CmdlineLeave <buffer>
          \ if get(v:event, 'cmdlevel', 1) == 1 |
          \   call ddc#disable_cmdline_completion() |
          \ endif
  endif

  " Note: command line window must be disabled
  let s:save_cedit = &cedit
  let b:ddc_cmdline_completion = v:true
  set cedit=
endfunction
function! ddc#disable_cmdline_completion() abort
  augroup ddc-cmdline
    autocmd!
  augroup END

  if exists('s:save_cedit')
    let &cedit = s:save_cedit
  endif

  unlet! b:ddc_cmdline_completion

  if exists('#User#DDCCmdlineLeave')
    doautocmd <nomodeline> User DDCCmdlineLeave
  endif
endfunction
function! ddc#disable() abort
  augroup ddc
    autocmd!
  augroup END
  call ddc#disable_cmdline_completion()
endfunction

function! ddc#on_complete_done(completed_item) abort
  call ddc#complete#_on_complete_done(a:completed_item)
endfunction

let s:root_dir = fnamemodify(expand('<sfile>'), ':h:h')
let s:sep = has('win32') ? '\' : '/'
function! ddc#_register() abort
  call denops#plugin#register('ddc',
        \ join([s:root_dir, 'denops', 'ddc', 'app.ts'], s:sep),
        \ #{ mode: 'skip' })

  autocmd ddc User DenopsStopped call s:stopped()
endfunction

function! s:stopped() abort
  unlet! g:ddc#_initialized

  " Restore custom config
  if exists('g:ddc#_customs')
    for custom in g:ddc#_customs
      call ddc#_notify(custom.method, custom.args)
    endfor
  endif
endfunction

function! ddc#_denops_running() abort
  return exists('g:loaded_denops')
        \ && denops#server#status() ==# 'running'
        \ && denops#plugin#is_loaded('ddc')
endfunction

function! ddc#_on_event(event) abort
  " Note: If denops isn't running, stop
  if !ddc#_denops_running()
    return
  endif

  call denops#notify('ddc', 'onEvent', [a:event])
endfunction

function! ddc#syntax_in(groups) abort
  return ddc#syntax#in(a:groups)
endfunction

function! ddc#_notify(method, args) abort
  if ddc#_denops_running()
    call denops#notify('ddc', a:method, a:args)
  else
    execute printf('autocmd User DDCReady call ' .
          \ 'denops#notify("ddc", "%s", %s)',
          \ a:method, string(a:args))
  endif
endfunction

function! ddc#callback(id, ...) abort
  if !ddc#_denops_running()
    return
  endif

  let payload = get(a:000, 0, v:null)
  call denops#notify('ddc', 'onCallback', [a:id, payload])
endfunction

function! ddc#update_items(name, items) abort
  if !ddc#_denops_running()
    return
  endif

  call denops#notify('ddc', 'updateItems', [a:name, a:items])
endfunction

function! ddc#_hide(event) abort
  if !ddc#_denops_running()
    return
  endif

  call denops#notify('ddc', 'hide', [a:event])
endfunction

function! ddc#complete_info() abort
  return exists('*pum#complete_info') ? pum#complete_info() : complete_info()
endfunction
