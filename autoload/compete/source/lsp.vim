let s:state = {
\   'ids': [],
\ }

"
" compete#source#lsp#register
"
function! compete#source#lsp#register() abort
  augroup compete#source#lsp#register
    autocmd!
    autocmd User lsp_server_init call s:source()
    autocmd User lsp_server_exit call s:source()
  augroup END
endfunction

"
" source
"
function! s:source() abort
  for l:id in s:state.ids
    call compete#source#unregister(l:id)
  endfor
  let s:state.ids = []

  for l:server_name in lsp#get_server_names()
    let l:capabilities = lsp#get_server_capabilities(l:server_name)
    if !has_key(l:capabilities, 'completionProvider')
      continue
    endif

    let l:trigger_chars = []
    if type(l:capabilities.completionProvider) == type({}) && has_key(l:capabilities.completionProvider, 'triggerCharacters')
      let l:trigger_chars = l:capabilities.completionProvider.triggerCharacters
    endif

    let l:server = lsp#get_server_info(l:server_name)
    let s:state.ids += [
    \   compete#source#register({
    \     'name': l:server_name,
    \     'complete': function('s:complete', [l:server_name]),
    \     'filetypes': l:server.whitelist,
    \     'priority': 100,
    \     'trigger_chars': l:trigger_chars,
    \   })
    \ ]
  endfor
endfunction

"
" complete
"
function! s:complete(server_name, context, callback) abort
  call lsp#send_request(a:server_name, {
  \   'method': 'textDocument/completion',
  \   'params': {
  \     'textDocument': lsp#get_text_document_identifier(),
  \     'position': lsp#get_position(),
  \   },
  \   'on_notification': function('s:on_response', [a:server_name, a:context, a:callback])
  \ })
endfunction

"
" on_response
"
function! s:on_response(server_name, context, callback, data) abort
  if lsp#client#is_error(a:data) || !has_key(a:data, 'response') || !has_key(a:data.response, 'result')
    return
  endif

  let l:result = a:data.response.result

  if type(l:result) == type([])
    let l:items = l:result
    let l:incomplete = v:false
  elseif type(l:result) == type({})
    let l:items = l:result.items
    let l:incomplete = l:result.isIncomplete
  else
    let l:items = []
    let l:incomplete = v:false
  endif

  call a:callback({
  \   'items': map(l:items, 'lsp#omni#get_vim_completion_item(v:val, a:server_name)'),
  \   'incomplete': l:incomplete,
  \ })
endfunction

