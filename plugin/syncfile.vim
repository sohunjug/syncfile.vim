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
let s:win_list=[]
let s:global_echo_str=[]


if has('g:syncfile_mapping') && g:syncfile_mapping
  call syncfile#key_mapping()
endif

if !exists(':SUpdate')
  command! SyncConfig call syncfile#showconf()
  command! SDiff call syncfile#diff_remote()
  command! SDownload call syncfile#download_file()
  command! SUpload call syncfile#upload_file()
  command! SRsyncAll call syncfile#sync('updelete')
  command! SRsyncUp call syncfile#sync('up')
  command! SRsyncDown call syncfile#sync('down')
  command! SConnectToRemote call syncfile#connect_to_remote()
  command! SCopyRemoteToBuffer call syncfile#copy_remote()
endif

function! syncfile#key_mapping()
  nnoremap <leader>uc <esc>:SyncConfig<CR>
  nnoremap <leader>ua <esc>:SRsyncAll<CR>
  nnoremap <leader>uu <esc>:SUpload<CR>
  nnoremap <leader>ud <esc>:SDownload<CR>
  nnoremap <leader>urd <esc>:SRsyncDown<CR>
  nnoremap <leader>uru <esc>:SRsyncUp<CR>
endfunction

function! s:load_config()
  let l:conf_dict = {}
  let l:config_file = findfile('.sync', '.,,;')

  if strlen(l:config_file) > 0
    let l:conf_options = readfile(l:config_file)
    let l:conf_dict = json_decode(l:conf_options)
  endif
  if has_key(l:conf_dict, "remote")
    let l:rpath = l:conf_dict['remote']
    if strlen(l:rpath) > 0 && strridx(l:rpath, '/') != strlen(l:rpath)
      let l:conf_dict['remote'] = l:rpath . '/'
    endif
  endif
  if !has_key(l:conf_dict, "local")
    let l:conf_dict['local'] = fnamemodify(l:config_file,':p:h') . '/'
  endif
  if !has_key(l:conf_dict, "port")
    let l:conf_dict['port'] = 22
  endif
  let g:sync_config = l:conf_dict
  return !empty(l:conf_dict)
endfunction

function! syncfile#showconf()
  if s:load_config()
    echo l:conf_dict
    echom string(getqflist())
  else
    call s:warning_message('No Config File Found!')
  endif
endfunction

if !exists('g:prompt')
  let g:prompt = 'syncfile => '
endif

if !exists('g:sync_config')
  let g:command = 'scp'
  call s:load_config()
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
endif

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
  call s:popup_message('InfoMsg', 'info', a:msg)
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
    call s:warning_message('Upload error ' . a:data)
  else
    call s:info_message('Upload finished' . a:data)
  endif
endfunction

function! syncfile#diff_remote()
  if s:load_config() && has_key(g:sync_config, 'host')
    let l:remotepath = s:get_remote_path()
    let l:cmd = printf('diffsplit scp://%s@%s:%d/%s|windo wincmd H', g:sync_config['user'], g:sync_config['host'], g:sync_config['port'], l:remotepath)
    silent execute l:cmd
  endif
endfunction

function! syncfile#download_file()
  if s:load_config() && has_key(g:sync_config, 'host')
    let l:remotepath = s:get_remote_path()
    let l:cmd = printf('1,$d|0Nr "sftp://%s@%s:%d/%s"', g:mmsftp#config['user'], g:sync_config['host'], g:sync_config['port'], l:remotepath)
    call s:info_message(printf('Downloading %s from %s...', l:remotepath, g:sync_config['host']))
    silent execute l:cmd
    call s:info_message('Done! Saving...')
    silent execute 'w'
  endif
endfunction

function! syncfile#upload_file()
  let l:local = expand(':%h')
  if s:load_config() && has_key(g:sync_config, 'host')
    let l:localpath = s:get_local_path()
    let l:remotepath = s:get_remote_path()
    call s:info_message('Upload start ' . l:localpath . ' ' . ' to ' . g:sync_config['host'] . ' ' . l:remotepath)
    let l:cmd = printf(g:command . ' -P %d %s %s@%s:%s', g:sync_config['port'], l:localpath, g:sync_config['user'], g:sync_config['host'], l:remotepath)
    call jobstart(l:cmd, {'on_exit': function('s:on_upload_cb')})
  endif
endfunction

function! syncfile#connect_to_remote()
  if s:load_config() && has_key(g:sync_config, 'host')
    let l:cmd = 'vsplit term://sshpass -p ' . g:sync_config['pass'] . ' ssh -p ' . g:sync_config['port'] . '-t ' . g:sync_config['user'] . '@' . g:sync_config['host']
    if has_key(g:sync_config, 'remote')
      let l:cmd = l:cmd . ' \"cd ' . g:sync_config['remote'] . ' && bash\"'
    endif
    silent execute l:cmd
  endif
endfunction

function! syncfile#copy_remote()
  if s:load_config() && has_key(g:sync_config, 'remote')
    let @+=g:sync_config['remote']
  else
    call s:info_message('No remote set in .sync')
  endif
endfunction

function! syncfile#sync(direction)
  call s:load_config()
  if has_key(g:sync_config, 'host')
    let l:user_passwd = ''
    if has_key(g:sync_config, 'user')
      if has_key(g:sync_config, 'passwd')
        let l:user_passwd = g:sync_config['user'] . ':' . g:sync_config['passwd'] . '@'
      else
        let l:user_passwd = g:sync_config['user'] . '@'
      endif
    endif

    if a:direction == 'down'
      let l:cmd = [ 'rsync', '-avzhe', 'ssh -p' . g:sync_config['port'], l:user_passwd . g:sync_config['host'] . ':' . g:sync_config['remote'], g:sync_config['local']]
    elseif  a:direction == 'up'
      let l:cmd = [ 'rsync', '-avzhe', 'ssh -p' . g:sync_config['port'], g:sync_config['local'], l:user_passwd . g:sync_config['host'] . ':' . g:sync_config['remote']]
    else
      let l:cmd = [ 'rsync', '-avzhe', 'ssh -p' . g:sync_config['port'], g:sync_config['local'], l:user_passwd . g:sync_config['host'] . ':' . g:sync_config['remote'], '--delete']
    endif
    if has_key(g:sync_config, 'ignore_path')
      for ifile in g:sync_config['ignore_path']
        let l:cmd = l:cmd + ['--exclude', ifile]
      endfor
    endif
    if has_key(g:sync_config, 'ignore_dotfiles')
      if g:sync_config['ignore_dotfiles'] == 1
        let l:cmd = l:cmd + ['--exclude', '.*']
      endif
    endif
    echo l:cmd
    call jobstart(l:cmd, {'on_exit': function('s:on_upload_cb')})
  else
    echo 'Could not locate a .vim-arsync configuration file. Aborting...'
  endif
endfunction

function! s:upload_on_save()
  if s:load_config() && has_key(g:sync_config, 'upload_on_save')
    if g:sync_config['upload_on_save'] == 'local'
      let localpath = s:get_local_path()
      let remotepath = s:get_remote_path()
      let cmd = printf(g:command . ' -P %d %s %s@%s:%s', g:sync_config['port'], localpath, g:sync_config['user'], g:sync_config['host'], remotepath)
      call jobstart(cmd, {'on_exit': function('s:on_upload_cb')})
    elseif g:sync_config['upload_on_save'] == 'all'
    endif
  endif
endfunction

function! s:configure()
  call s:info_message('Reloading SFTP configuration')
  call s:load_config()

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
