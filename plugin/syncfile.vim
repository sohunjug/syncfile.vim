" Title: syncfile
" Description: Upload and download files through sftp || rsync
" Usage: :Supload :Sdownload : Ssync
"        See README for more
" Github: https://github.com/sohunjug/syncfile.vim
" Author: sohunjug
" License: MIT

function! s:sync#find_config_file()
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

function! s:sync#is_enabled()
  if strlen(sync#find_config_file()) > 0
    return 1
  else
    return 0
  endif
endfunction

function! s:sync#load_config()
	let conf = {}
	let l:cpath = s:sync#find_config_file()

	if strlen(l:cpath) > 0
		let options = readfile(l:cpath)

    let conf = js_decode(options)
		let conf['local'] = fnamemodify(l:cpath, ':h:p') . '/'
	endif

	return conf
endfunction

if !exists('g:sync#config')
	let g:sync#prompt = 'syncfile => '
	let g:sync#command = 'scp'
	let g:sync#config = s:sync#load_config()
	if has_key(g:sync#config, 'upload_on_save')
		if g:sync#config['upload_on_save'] == 1
			augroup sync#upload_on_save
				au!
				au BufWritePost * call g:sync#upload_on_save()
			augroup END
		else
			augroup sync#upload_on_save
				au!
			augroup END
			augroup! sync#upload_on_save
		endif
	endif
endif

function! s:sync#warning_message(msg)
	echohl WarningMsg | !echo g:sync#prompt . a:msg | !echohl None
endfunction

function! s:sync#info_message(msg)
	echo g:sync#prompt . a:msg
endfunction

function! s:sync#get_local_path()
	return expand('%:p')
endfunction

function! s:sync#get_remote_path()
	let l:localpath = s:sync#get_local_path()
	return g:sync#config['remote'] . l:localpath[strlen(g:sync#config['local']):]
endfunction

function! s:sync#finished_cb(channel)
	s:sync#info_message('Done!')
endfunction

function! s:sync#on_upload_cb(job_id, data, event) dict
	if a:event == 'stderr'
		call s:sync#warning_message('Upload error ')
	else
		call s:sync#info_message('Upload finished')
	endif
endfunction

function! s:sync#diff_remote()
	if s:sync#is_enabled() && has_key(g:sync#config, 'host')
		let remotepath = s:sync#get_remote_path()
		let cmd = printf('diffsplit scp://%s@%s/%s|windo wincmd H', g:mmsftp#config['user'], g:mmsftp#config['host'], remotepath)
		silent execute cmd
	endif
endfunction

function! s:sync#download_file()
	if s:sync#is_enabled() && has_key(g:sync#config, 'host')
		let remotepath = s:sync#get_remote_path()
		let cmd = printf('1,$d|0Nr "sftp://%s@%s/%s"', g:mmsftp#config['user'], g:sync#config['host'], remotepath)
		call s:sync#info_message(printf('Downloading %s from %s...', remotepath, g:sync#config['host']))
		silent execute cmd
		call s:sync#info_message('Done! Saving...')
		silent execute 'w'
	endif
endfunction

function! s:sync#upload_file()
	if s:sync#is_enabled() && has_key(g:sync#config, 'host')
		let localpath = s:sync#get_local_path()
		let remotepath = s:sync#get_remote_path()
		call s:sync#info_message('Uploading')
		let cmd = printf(g:sync#command . ' %s %s@%s:%s', localpath, g:sync#config['user'], g:sync#config['host'], remotepath)
		" silent execute cmd
		call jobstart(cmd, {'on_exit': function('s:sync#on_upload_cb')})
	endif
endfunction

function! s:sync#connect_to_remote()
	if s:sync#is_enabled() && has_key(g:sync#config, 'host')
		let cmd = 'vsplit term://sshpass -p ' . g:sync#config['pass'] . ' ssh -t ' . g:sync#config['user'] . '@' . g:sync#config['host']
		if has_key(g:sync#config, 'remote')
			let cmd = cmd . ' \"cd ' . g:sync#config['remote'] . ' && bash\"'
		endif
		silent execute cmd
	endif
endfunction

function! s:sync#copy_remote()
	if s:sync#is_enabled() && has_key(g:sync#config, 'remote')
		let @+=g:sync#config['remote']
	else
		call s:sync#info_message('No remote set in .hsftp')
	endif
endfunction

function! s:sync#upload_on_save()
	if s:sync#is_enabled() && has_key(g:sync#config, 'upload_on_save')
		if g:sync#config['upload_on_save'] == 1
			let localpath = s:sync#get_local_path()
			let remotepath = s:sync#get_remote_path()
			let cmd = printf(g:sync#command . ' %s %s@%s:%s', localpath, g:sync#config['user'], g:sync#config['host'], remotepath)
			call jobstart(cmd, {'on_exit': function('s:sync#on_upload_cb')})
		endif
	endif
endfunction

function! s:sync#configure()
	call s:sync#info_message('Reloading SFTP configuration')
	let g:sync#config = s:sync#load_config()

	if has_key(g:sync#config, 'upload_on_save')
		if g:sync#config['upload_on_save'] == 1
			augroup sync#upload_on_save
				au!
				au BufWritePost * call s:sync#upload_on_save()
			augroup END
		else
			augroup sync#upload_on_save
				au!
			augroup END
			augroup! sync#upload_on_save
		endif
	endif
endfunction

augroup mmsftp
	au! BufWritePost .sync.cfg call s:sync#configure()
augroup END

command! Hdiff call s:sync#diff_remote()
command! Hdownload call s:sync#download_file()
command! Hupload call s:sync#upload_file()
command! DiffRemote call s:sync#diff_remote()
command! DownloadFileFromRemote call s:sync#download_file()
command! UploadFileToRemote call s:sync#upload_file()
command! ConnectToRemote call s:sync#connect_to_remote()
command! CopyRemoteToBuffer call s:sync#copy_remote()
