if !exists('g:mail_folder')
    let g:mail_folder = '~/Mail'
endif

command! -nargs=* Mail call maildir#open_folder(<q-args>)
