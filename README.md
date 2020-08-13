# syncfile.vim

Thanks

- [vim-async](https://github.com/KenN7/vim-arsync)

Example Config

```json
{
  "host": "10.0.0.0",
  "port": 222,
  "user": "root",
  "pass": "root"
  "remote": "/data/client",
  "ignore_path": ["depend", "*.o"],
  "ignore_dotfiles": true
}

```


Commands

- ```:SyncConfig``` shows detected configuration
- ```:SUpdate``` Syncs current file up to the remote (upload local to remote)
- ```:SDownload``` Syncs current file down from the remote (download remote to local)
- ```:SRsyncAll``` Syncs files up to the remote (upload local to remote)
  and delete remote files not existing on local (be careful with that)
- ```:SRsyncUp``` Syncs project files up to the remote (upload local to remote)
- ```:SRsyncDown``` Syncs files down from the remote (download remote to local)
- ```:SDiff``` Compare remote file with local current file

