" Title: syncfile
" Description: Upload and download files through sftp || rsync
" Usage: :Supload :Sdownload : Ssync
"        See README for more
" Github: https://github.com/sohunjug/syncfile.vim
" Author: sohunjug
" License: MIT
"
"
if get(g:, 'loaded_syncfile', 0)
  finish
endif

let g:loaded_syncfile = 1

if !exists(':Supdate')
  command! SDiff call syncfile#diff_remote()
  command! SDownload call syncfile#download_file()
  command! SUpload call syncfile#upload_file()
  command! SConnectToRemote call syncfile#connect_to_remote()
  command! SCopyRemoteToBuffer call syncfile#copy_remote()
endif

function! s:find_config_file()
  let l:cpath = expand('%:p:h')
  let l:cfile = l:cpath . '/.sync'
  let l:config = ''
  if filereadable(l:cfile)
    let l:config = l:cfile
  else
    while !filereadable(l:cfile)
      let sindex = strridx(l:cpath, '/')
      if sindex >= 0
        let l:cpath = l:cpath[0:sindex]
        let l:cfile = l:cpath . '.sync'
        let l:cpath = l:cpath[0:sindex-1]
        if filereadable(l:cfile)
          let l:config = l:cfile
          break
        endif
        if sindex == 0 && !filereadable(l:cfile)
          break
        endif
      else
        break
      endif
    endwhile
  endif

  return l:config
endfunction

function! s:is_enabled()
  let l:cpath = s:find_config_file()
  if strlen(l:cpath) > 0
    if !has_key(g:sync_config, 'host') || (get(g:sync_config, 'local', '') != fnamemodify(l:cpath, ':h:p') . '/')
      let g:sync_config = s:load_config()
    endif
    return 1
  else
    call s:warning_message('Not found config file!')
    return 0
  endif
endfunction

function! s:load_config()
  let conf = {}
  let l:cpath = s:find_config_file()

  if strlen(l:cpath) > 0
    let options = readfile(l:cpath)
    let conf = json_decode(options)
    let l:rpath = get(conf, 'remote', '')
    if strlen(l:rpath) > 0 && strridx(l:rpath, '/') != strlen(l:rpath)
      let conf['remote'] = l:rpath . '/'
    endif
    let conf['local'] = fnamemodify(l:cpath, ':h:p') . '/'
  endif

  return conf
endfunction

if !exists('g:prompt')
  let g:prompt = 'syncfile => '
endif

if !exists('g:sync_config')
  let g:command = 'scp'
  let g:sync_config = s:load_config()
  if has_key(g:sync_config, 'upload_on_save')
    if g:sync_config['upload_on_save'] == 1
      augroup upload_on_save
        au!
        au BufWritePost * call g:upload_on_save()
      augroup END
    else
      augroup upload_on_save
        au!
      augroup END
      augroup! upload_on_save
    endif
  endif
endif

let s:win_list=[]
let s:global_echo_str=[]

function! NvimCloseWin(timer) abort
    call timer_info(a:timer)
    let l:flag=0
    try
        call nvim_win_close(s:win_list[0], v:true)
    catch
        call remove(s:win_list, 0)
        let l:flag=1
    endtry
    if !empty(s:win_list) && l:flag == 0
        call remove(s:win_list, 0)
    endif
endfunction

"echo warning messag
"a:1-->err or warn or info,default is warn
"a:2-->flag of VimEnter,0 or 1
function! s:popup_message(level,prompt,str,...) abort
    if has('nvim') && exists('*nvim_open_win') && exists('*nvim_win_set_config')
        let l:str='['.a:prompt.'] '.a:str
        let l:bufnr = nvim_create_buf(v:false, v:false)
        let l:opts = {'relative': 'editor', 'width': strlen(l:str)+3, 'height': 1, 'col': &columns,
                    \ 'row': 3+len(s:win_list), 'anchor': 'NW'}
        let l:win=nvim_open_win(l:bufnr, v:false,l:opts)
        call nvim_buf_set_lines(l:bufnr, 0, -1, v:false, [l:str])
        hi def NvimFloatingWindow  term=None guifg=black guibg=#f94e3e ctermfg=black ctermbg=210
        call nvim_win_set_option(l:win, 'winhl', 'Normal:NvimFloatingWindow')
        call nvim_win_set_option(l:win, 'number', v:false)
        call nvim_win_set_option(l:win, 'relativenumber', v:false)
        call nvim_buf_set_option(l:bufnr, 'buftype', 'nofile')
        call nvim_buf_set_option(l:bufnr, 'bufhidden', 'wipe')
        call nvim_buf_set_option(l:bufnr, 'modified', v:false)
        call nvim_buf_set_option(l:bufnr, 'buflisted', v:false)
        call add(s:win_list, l:win)
        call timer_start(5000, 'NvimCloseWin', {'repeat': 1})
    else
        redraw!
        execut 'echohl '.a:level | echom '['.a:prompt.'] '.a:str | echohl None
    endif
endfunction

function! s:warning_message(msg)
  call s:popup_message('WarningMsg', 'warn', a:msg)
endfunction

function! s:info_message(msg)
  call s:popup_message('WarningMsg', 'info', a:msg)
endfunction

function! s:get_local_path()
  return expand('%:p')
endfunction

function! s:get_remote_path()
  let l:localpath = s:get_local_path()
  return g:sync_config['remote'] . l:localpath[strlen(g:sync_config['local']):]
endfunction

function! s:finished_cb(channel)
  s:info_message('Done!')
endfunction

function! s:on_upload_cb(job_id, data, event) dict
  if a:event == 'stderr'
    call s:warning_message('Upload error ')
  else
    call s:info_message('Upload finished')
  endif
endfunction

function! syncfile#diff_remote()
  if s:is_enabled() && has_key(g:sync_config, 'host')
    let remotepath = s:get_remote_path()
    let cmd = printf('diffsplit scp://%s@%s/%s|windo wincmd H', g:mmsftp#config['user'], g:mmsftp#config['host'], remotepath)
    silent execute cmd
  endif
endfunction

function! syncfile#download_file()
  if s:is_enabled() && has_key(g:sync_config, 'host')
    let remotepath = s:get_remote_path()
    let cmd = printf('1,$d|0Nr "sftp://%s@%s/%s"', g:mmsftp#config['user'], g:sync_config['host'], remotepath)
    call s:info_message(printf('Downloading %s from %s...', remotepath, g:sync_config['host']))
    silent execute cmd
    call s:info_message('Done! Saving...')
    silent execute 'w'
  endif
endfunction

function! syncfile#upload_file()
  if s:is_enabled() && has_key(g:sync_config, 'host')
    let localpath = s:get_local_path()
    let remotepath = s:get_remote_path()
    call s:info_message('Upload start '.localpath.' '.' to '.g:sync_config['host'].' '.remotepath)
    let cmd = printf(g:command . ' %s %s@%s:%s', localpath, g:sync_config['user'], g:sync_config['host'], remotepath)
    call jobstart(cmd, {'on_exit': function('s:on_upload_cb')})
  endif
endfunction

function! syncfile#connect_to_remote()
  if s:is_enabled() && has_key(g:sync_config, 'host')
    let cmd = 'vsplit term://sshpass -p ' . g:sync_config['pass'] . ' ssh -p ' . get(g:sync_config, 'port', 22) . '-t ' . g:sync_config['user'] . '@' . g:sync_config['host']
    if has_key(g:sync_config, 'remote')
      let cmd = cmd . ' \"cd ' . g:sync_config['remote'] . ' && bash\"'
    endif
    silent execute cmd
  endif
endfunction

function! syncfile#copy_remote()
  if s:is_enabled() && has_key(g:sync_config, 'remote')
    let @+=g:sync_config['remote']
  else
    call s:info_message('No remote set in .sync')
  endif
endfunction

function! s:upload_on_save()
  if s:is_enabled() && has_key(g:sync_config, 'upload_on_save')
    if g:sync_config['upload_on_save'] == 1
      let localpath = s:get_local_path()
      let remotepath = s:get_remote_path()
      let cmd = printf(g:command . ' %s %s@%s:%s', localpath, g:sync_config['user'], g:sync_config['host'], remotepath)
      call jobstart(cmd, {'on_exit': function('s:on_upload_cb')})
    endif
  endif
endfunction

function! s:configure()
  call s:info_message('Reloading SFTP configuration')
  let g:sync_config = s:load_config()

  if has_key(g:sync_config, 'upload_on_save')
    if g:sync_config['upload_on_save'] == 1
      augroup upload_on_save
        au!
        au BufWritePost * call s:upload_on_save()
      augroup END
    else
      augroup upload_on_save
        au!
      augroup END
      augroup! upload_on_save
    endif
  endif
endfunction

augroup syncfile
  au! BufWritePost .sync call s:configure()
augroup END

au BufNewFile,BufRead .sync set filetype=json


