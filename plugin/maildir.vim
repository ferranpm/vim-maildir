if !exists('g:mail_folder')
    let g:mail_folder = '~/Mail'
endif

command! -nargs=* -complete=custom,maildir#folder_complete Mail call maildir#open_folder(<q-args>)
