function! maildir#folder_complete(ArgLead, CmdLine, CursorPos)
    let expanded = expand(g:mail_folder) . '/'
    return join(map(glob(expanded.'*', 1, 1), 'substitute(v:val, expanded, "", "")'), "\n")
endfunction

function! maildir#goto_buffer(name)
    let l:return = bufexists(a:name)
    if l:return
        execute 'buffer '.a:name
    else
        enew
        execute 'file '.a:name
    endif
    return l:return
endfunction

function! maildir#add_field(dict, key, field, s)
    if !has_key(a:dict, a:key)
        let a:dict[a:key] = {}
    endif
    let a:dict[a:key][a:field] = a:s
endfunction

function! maildir#sort(a, b)
    return str2nr(a:a) < str2nr(a:b) ? 1 : -1
endfunction

function! maildir#get_local_folder(folder)
    return glob(g:mail_folder.'/'.a:folder)
endfunction

" maildir#open_folder({folder}, [{force_refresh}])
function! maildir#open_folder(folder, ...)

    let force_refresh = 0
    if a:0 > 0 | let force_refresh = a:1 | endif

    if a:folder =~ "^$"
        let folder = 'INBOX'
    else
        let folder = a:folder
    endif

    if maildir#goto_buffer('/tmp/vim-maildir-'.folder) && !force_refresh
        return
    endif

    let b:maildir_folder = folder

    let local_folder = maildir#get_local_folder(folder)
    let greplines = systemlist('grep -R "^Subject\|^From:" '.local_folder.'*')
    let dict = {}

    for line in greplines
        let U = substitute(line, '\C^.*U=\(\d\+\).*', '\1', "")
        if match(line, 'From:') > 0
            call maildir#add_field(dict, U, 'from', maildir#decode(matchstr(line, 'From: \zs.*')))
        elseif match(line, 'Subject:') > 0
            call maildir#add_field(dict, U, 'subject', maildir#decode(matchstr(line, 'Subject: \zs.*')))
        endif
        call maildir#add_field(dict, U, 'new', match(line, '\/new\/') > 0)
    endfor

    let sorted_keys = sort(keys(dict), 'maildir#sort')
    let lines = []
    for k in sorted_keys
        let flags = ''
        if get(dict[k], 'new', 0)
            let flags .= '>>>'
        endif
        call add(lines,
                    \ flags
                    \ .'*'.k.'*'.'	'
                    \ .'$$'.get(dict[k], 'subject', '').'$$'.'	'
                    \ .'<>'.get(dict[k], 'from', '').'<>'.'	'
                    \ )
    endfor

    set modifiable
    normal! ggdG
    call setline(1, lines)
    setlocal filetype=mailheaders
    setlocal nomodified
    setlocal nomodifiable
    noremap <buffer> <cr> :call maildir#open_mail()<cr>
    noremap <buffer> R :call maildir#open_folder(b:maildir_folder, 1)<cr>
    noremap <buffer> d :call maildir#delete_mail()<cr>:call maildir#open_folder(b:maildir_folder, 1)<cr>
    execute 'setlocal statusline=%#StatusLineNC#<cr>%#StatusLine#:\ Open\ Mail\ %#StatusLineNC#R%#StatusLine#:\ Refresh\ %#StatusLineNC#d%#StatusLine#:\ Delete\ Mail\ '
endfunction

function! maildir#decode(line)
    if a:line =~ 'utf-8' || a:line =~ 'iso-8859-1'
        let l:encoding = tolower(matchstr(a:line, '\m=?\zs\(utf-8\|iso-8859-1\)', '\1', ''))
        let l:type = tolower(matchstr(a:line, '\m=?'.l:encoding.'?\zs\(\w\)', '\1', ''))
        let l:line = matchstr(a:line, '\m=?'.l:encoding.'?\w?\zs[0-9A-Za-z_=]\+')
        if l:type == 'b'
            let l:line = system('echo "'.l:line.'" | recode /b64')
        elseif l:type == 'q'
            let l:line = system('echo "'.l:line.'" | recode /qp')
        endif
        return l:line
    else
        return a:line
    endif
endfunction

function! maildir#open_mail()
    let U = matchstr(getline(line('.')), '\*\zs\d\+\ze\*')
    let findlines = systemlist('find '.maildir#get_local_folder(b:maildir_folder).' -name "*U='.U.'*"')
    if len(findlines) == 0
        echoerr 'No such message'
    elseif len(findlines) == 1
        let file = findlines[0]
        execute 'new '.file
        if match(file, '\/new\/') > 0
            let newfile = substitute(file, '\/new\/', '/cur/', '')
            let newfile = substitute(newfile, ',\zs$', 'S', '')
            call rename(file, newfile)
        endif
        setlocal filetype=mail
        setlocal foldlevel=0
    else
    endif
endfunction

function! maildir#delete_mail()
    let U = matchstr(getline(line('.')), '\*\zs\d\+\ze\*')
    let findlines = systemlist('find '.maildir#get_local_folder(b:maildir_folder).' -name "*U='.U.'*"')
    if len(findlines) == 0
        echoerr 'No such message'
    elseif len(findlines) == 1
        let file = findlines[0]
        call delete(file)
    else
    endif
endfunction
