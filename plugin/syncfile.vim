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

function! s:syncfile#find_config_file()
  let l:cpath = expand('%:p:h')
  let l:cfile = l:cpath . '/.sync.cfg'
  let l:config = ''
  if filereadable(l:cfile)
    let l:config = l:cfile
  else
    while !filereadable(l:cfile)
      let sindex = strridx(l:cpath, '/')
      if sindex >= 0
        let l:cpath = l:cath[0:sindex]
        let l:cfile = l:cpath . '.sync.cfg'
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

function! s:syncfile#is_enabled()
  if strlen(syncfile#find_config_file()) > 0
    return 1
  else
    return 0
  endif
endfunction

function! s:syncfile#load_config()
	let conf = {}
	let l:cpath = s:syncfile#find_config_file()

	if strlen(l:cpath) > 0
		let options = readfile(l:cpath)

    let conf = js_decode(options)
		let conf['local'] = fnamemodify(l:cpath, ':h:p') . '/'
	endif

	return conf
endfunction

if !exists('g:syncfile#config')
	let g:syncfile#prompt = 'syncfile => '
	let g:syncfile#command = 'scp'
	let g:syncfile#config = s:syncfile#load_config()
	if has_key(g:syncfile#config, 'upload_on_save')
		if g:syncfile#config['upload_on_save'] == 1
			augroup syncfile#upload_on_save
				au!
				au BufWritePost * call g:syncfile#upload_on_save()
			augroup END
		else
			augroup syncfile#upload_on_save
				au!
			augroup END
			augroup! syncfile#upload_on_save
		endif
	endif
endif

function! s:syncfile#warning_message(msg)
	echohl WarningMsg | !echo g:syncfile#prompt . a:msg | !echohl None
endfunction

function! s:syncfile#info_message(msg)
	echo g:syncfile#prompt . a:msg
endfunction

function! s:syncfile#get_local_path()
	return expand('%:p')
endfunction

function! s:syncfile#get_remote_path()
	let l:localpath = s:syncfile#get_local_path()
	return g:syncfile#config['remote'] . l:localpath[strlen(g:syncfile#config['local']):]
endfunction

function! s:syncfile#finished_cb(channel)
	s:syncfile#info_message('Done!')
endfunction

function! s:syncfile#on_upload_cb(job_id, data, event) dict
	if a:event == 'stderr'
		call s:syncfile#warning_message('Upload error ')
	else
		call s:syncfile#info_message('Upload finished')
	endif
endfunction

function! syncfile#diff_remote()
	if s:syncfile#is_enabled() && has_key(g:syncfile#config, 'host')
		let remotepath = s:syncfile#get_remote_path()
		let cmd = printf('diffsplit scp://%s@%s/%s|windo wincmd H', g:mmsftp#config['user'], g:mmsftp#config['host'], remotepath)
		silent execute cmd
	endif
endfunction

function! syncfile#download_file()
	if s:syncfile#is_enabled() && has_key(g:syncfile#config, 'host')
		let remotepath = s:syncfile#get_remote_path()
		let cmd = printf('1,$d|0Nr "sftp://%s@%s/%s"', g:mmsftp#config['user'], g:syncfile#config['host'], remotepath)
		call s:syncfile#info_message(printf('Downloading %s from %s...', remotepath, g:syncfile#config['host']))
		silent execute cmd
		call s:syncfile#info_message('Done! Saving...')
		silent execute 'w'
	endif
endfunction

function! syncfile#upload_file()
	if s:syncfile#is_enabled() && has_key(g:syncfile#config, 'host')
		let localpath = s:syncfile#get_local_path()
		let remotepath = s:syncfile#get_remote_path()
		call s:syncfile#info_message('Uploading')
		let cmd = printf(g:syncfile#command . ' %s %s@%s:%s', localpath, g:syncfile#config['user'], g:syncfile#config['host'], remotepath)
		" silent execute cmd
		call jobstart(cmd, {'on_exit': function('s:syncfile#on_upload_cb')})
	endif
endfunction

function! syncfile#connect_to_remote()
	if s:syncfile#is_enabled() && has_key(g:syncfile#config, 'host')
		let cmd = 'vsplit term://sshpass -p ' . g:syncfile#config['pass'] . ' ssh -t ' . g:syncfile#config['user'] . '@' . g:syncfile#config['host']
		if has_key(g:syncfile#config, 'remote')
			let cmd = cmd . ' \"cd ' . g:syncfile#config['remote'] . ' && bash\"'
		endif
		silent execute cmd
	endif
endfunction

function! syncfile#copy_remote()
	if s:syncfile#is_enabled() && has_key(g:syncfile#config, 'remote')
		let @+=g:syncfile#config['remote']
	else
		call s:syncfile#info_message('No remote set in .hsftp')
	endif
endfunction

function! s:syncfile#upload_on_save()
	if s:syncfile#is_enabled() && has_key(g:syncfile#config, 'upload_on_save')
		if g:syncfile#config['upload_on_save'] == 1
			let localpath = s:syncfile#get_local_path()
			let remotepath = s:syncfile#get_remote_path()
			let cmd = printf(g:syncfile#command . ' %s %s@%s:%s', localpath, g:syncfile#config['user'], g:syncfile#config['host'], remotepath)
			call jobstart(cmd, {'on_exit': function('s:syncfile#on_upload_cb')})
		endif
	endif
endfunction

function! s:syncfile#configure()
	call s:syncfile#info_message('Reloading SFTP configuration')
	let g:syncfile#config = s:syncfile#load_config()

	if has_key(g:syncfile#config, 'upload_on_save')
		if g:syncfile#config['upload_on_save'] == 1
			augroup syncfile#upload_on_save
				au!
				au BufWritePost * call s:syncfile#upload_on_save()
			augroup END
		else
			augroup syncfile#upload_on_save
				au!
			augroup END
			augroup! syncfile#upload_on_save
		endif
	endif
endfunction

augroup mmsftp
	au! BufWritePost .sync.cfg call s:syncfile#configure()
augroup END

