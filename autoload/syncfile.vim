
function! syncfile#keymapping()
  nnoremap <leader>uc <esc>:SyncConfig<CR>
  nnoremap <leader>ua <esc>:SRsyncAll<CR>
  nnoremap <leader>uu <esc>:SUpload<CR>
  nnoremap <leader>ud <esc>:SDownload<CR>
  nnoremap <leader>urd <esc>:SRsyncDown<CR>
  nnoremap <leader>uru <esc>:SRsyncUp<CR>
endfunction

if has('g:syncfile_mapping') && g:syncfile_mapping
  call syncfile#keymapping()
endif

