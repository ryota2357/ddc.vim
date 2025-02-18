function! ddc#map#complete(ui) abort
  if !ddc#_denops_running()
    return
  endif

  call denops#notify('ddc', 'show', [a:ui])
  return ''
endfunction

function! ddc#map#manual_complete(...) abort
  if !ddc#_denops_running()
    call ddc#enable()
    call denops#plugin#wait('ddc')
  endif

  let arg = get(a:000, 0, [])
  let sources = type(arg) == v:t_list ? arg : [arg]
  return printf(
        \ "\<Cmd>call denops#notify('ddc', 'manualComplete', %s)\<CR>",
        \ string([sources, get(a:000, 1, '')]))
endfunction

function! ddc#map#can_complete() abort
  return !empty(get(g:, 'ddc#_items', []))
        \ && get(g:, 'ddc#_complete_pos', -1) >= 0
endfunction

function! ddc#map#extend(confirm_key) abort
  if !exists('g:ddc#_sources')
    return ''
  endif
  return a:confirm_key . ddc#map#manual_complete(g:ddc#_sources)
endfunction

function! ddc#map#complete_common_string() abort
  if empty(g:ddc#_items) || g:ddc#_complete_pos < 0
    return ''
  endif

  " Get cursor word.
  let input = ddc#util#get_input('')
  let complete_str = input[g:ddc#_complete_pos : s:col() - 1]

  let common_str = g:ddc#_items[0].word
  for item in g:ddc#_items[1:]
    while stridx(tolower(item.word), tolower(common_str)) != 0
      let common_str = common_str[: -2]
    endwhile
  endfor

  if common_str ==# '' || complete_str ==? common_str
    return ''
  endif

  let chars = ''
  " Note: Change backspace option to work <BS> correctly
  if mode() ==# 'i'
    let chars .= "\<Cmd>set backspace=start\<CR>"
  endif
  let chars .= repeat("\<BS>", strchars(complete_str))
  let chars .= common_str
  if mode() ==# 'i'
    let chars .= printf("\<Cmd>set backspace=%s\<CR>", &backspace)
  endif
  return chars
endfunction

function! ddc#map#insert_item(number, cancel_key) abort
  let word = get(g:ddc#_items, a:number, #{ word: '' }).word
  if word ==# ''
    return ''
  endif

  call ddc#_hide('CompleteDone')
  call ddc#complete#_on_complete_done(g:ddc#_items[a:number])

  " Get cursor word.
  let input = ddc#util#get_input('')
  let complete_str = input[g:ddc#_complete_pos : s:col() - 1]

  let chars = ''
  " Note: Change backspace option to work <BS> correctly
  if mode() ==# 'i'
    let chars .= "\<Cmd>set backspace=start\<CR>"
  endif
  let chars .= repeat("\<BS>", strchars(complete_str))
  let chars .= word
  if mode() ==# 'i'
    let chars .= printf("\<Cmd>set backspace=%s\<CR>", &backspace)
  endif
  let chars .= a:cancel_key
  return chars
endfunction

function! s:col() abort
  let col = mode() ==# 't' && !has('nvim') ?
        \ term_getcursor(bufnr('%'))[1] :
        \ mode() ==# 'c' ? getcmdpos() :
        \ mode() ==# 't' ? col('.') : col('.')
  return col
endfunction
