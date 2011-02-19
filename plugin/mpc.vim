if exists('g:loaded_mpc')
  finish
endif
let g:loaded_mpc = 1

let s:save_cpo = &cpo
set cpo&vim
"------------------------------

if !exists('g:mpc_command')
    let g:mpc_command = "mpc"
endif

if !exists('g:mpd_host')
    let g:mpc_host= "localhost"
endif

if !exists('g:mpd_port')
    let g:mpc_port= "6600"
endif

if !exists('g:mpc_format')
    let g:mpc_format = '"[[%artist% : %album% - ]%title%]|[%file%]"'
endif

if !exists('g:mpc_lyrics_use_cache')
    let g:mpc_lyrics_use_cache = 1
endif

function! Mpc(arg)
    return system(g:mpc_command." -f ".g:mpc_format." -p ".g:mpc_port.
                \" -h ".g:mpc_host." ".a:arg)
endfunction

function! s:mpc_save(name)
    let r =  Mpc("save ".a:name)
    if r =~ "exists"
        if input("error: Playlist already exists, overwrite? ") =~ "^[yY]"
            call Mpc("rm ".a:name)
            call Mpc("save ".a:name)
        else
            return
        endif
    endif
    echo "Save playlist as ".a:name
endfunction

function! s:mpc_toggle(arg)
    let r = Mpc(a:arg)
    if r =~ a:arg.": on"
        echo a:arg.": on"
    else
        echo a:arg.": off"
    endif
endfunction

function! s:mpc_cunnret()
    let r = split(Mpc("status"),"\n")[:-2]
    if len(r)
        let r[1] = split(r[1],'\s\+')
        let r[1] = printf("    %s%s  %s", r[1][2],r[1][3],r[1][1])
        echo join(r,' ')
    endif
endfunction

"fetch lyrics from lyrics.wikia.com
function! s:fetch_lyrics_from_lyricswiki(artist,title)
    let artist =  http#encodeURI(a:artist)
    let title  =  http#encodeURI(a:title)
    let url = "http://lyrics.wikia.com/api.php?action=lyrics&fmt=xml&".
                \"func=getSong&artist=".artist."&song=".title
    let r = system('curl "'.url.'"')
    if r =~ "<lyrics>Not found</lyrics>"
        return []
    endif
    let start = stridx(r,"<url>")
    let end   = stridx(r,"</url>")
    let url = r[start+5 : end-1]

    let r = system('curl "'.url.'"')
    let start =  stridx(r,"'17'/></a></div>")
    let end = stridx(r,"<!--",start)
    let lyrics =  split(html#decodeEntityReference(
                \r[start+16 : end-1]),'<br />')

    return lyrics
endfunction

" fetch lyrics from utamap
function! s:fetch_lyrics_from_utamap(artist,title)
    let id = s:get_lyrics_id(a:artist,a:title)
    if id == -1
        return []
    endif

    let url = "http://www.utamap.com/phpflash/flashfalsephp.php?unum=".id
    let lyrics = split(system('curl "'.url.'"'),"\n")[3:]
    let lyrics[0] = substitute(lyrics[0],"test1=\\d\\+&test2=","","g")
    return lyrics
endfunction

function! s:get_lyrics_id(artist,title)
    let cnt=0
    let artist = http#encodeURI(iconv(a:artist,&encoding,"utf-8"))
    let title = iconv(a:title,&encoding,"utf-8")
    while 1
        let url = "http://www.utamap.com/searchkasi.php?searchname=artist"
                \."&act=search&sortname=1&pattern=3"
                \."&word=".artist
                \."&page=".cnt
        let html = split(system('curl "'.url.'"'),"\n")
        let match = 0
        for line in html
            let id = matchstr(line,"showkasi.php?surl=\\zs.\\+\\ze\">")
            let title_ = matchstr(line,"showkasi.php?surl=.\\+\">\\zs.\\+\\ze</A>") 
            let title_ = iconv(title_,"sjis","utf-8")
            if id != ''
                let match = 1
                if title == title_
                    return id
                endif
            endif
        endfor
        if !match | break| endif
        let cnt += 1
    endwhile
    return -1
endfunction


function! Fetch_lyrics(artist,title)
    let artist =  substitute(a:artist," ","_","g")
    let title  =  substitute(a:title," ","_","g")
    let name = "Lyrics:".artist."-".title

    if g:mpc_lyrics_use_cache
        let bufnr = bufnr(name)
        if bufnr != -1
            let winnr = bufwinnr(bufnr)
            if winnr != -1
                exe "normal \<c-w>".winnr."w"
            else
               silent top split
               exe "buffer ".bufnr
            endif
            return
        endif
    endif

    let lyrics_func = [
                        \"fetch_lyrics_from_lyricswiki",
                        \"fetch_lyrics_from_utamap",
                      \]

    for func in lyrics_func
        let lyrics = s:{func}(a:artist,a:title)
        if lyrics != [] | break | endif
    endfor


    if lyrics == []
        echo "not found"
        return
    endif

    exe "silent top split ".name
    call append(0,lyrics)
    call append(0,[a:artist." - ".a:title,""])
    setl nomodified
    if g:mpc_lyrics_use_cache == 0
        setl bufhidden=delete
    endif
    normal gg
endfunction

function! s:mpc_fetch_current_music_lyrics()
    let save_mpc_format = g:mpc_format
    let g:mpc_format = "%artist%"
    let artist = Mpc("current")[:-2]
    let g:mpc_format = "%title%"
    let title = Mpc("current")[:-2]
    let g:mpc_format = save_mpc_format
    call Fetch_lyrics(artist,title)
endfunction

if !exists('g:mpc_no_map_default') || !g:mpc_no_map_default
    nnoremap <Leader>mt  :MpcToggle<CR>
    nnoremap <Leader>m>  :MpcNext<CR>
    nnoremap <Leader>m<  :MpcPrev<CR>
    nnoremap <Leader>mc  :MpcCurrent<CR>
    nnoremap <Leader>mm  :MpcStatus<CR>
    nnoremap <Leader>mL  :MpcCurrentMusicLyrics<CR>
    if exists("*unite#start")
        nnoremap <Leader>ml  :Unite mpc -buffer-name=music<CR>
        nnoremap <Leader>mp  :Unite mpc:playlist -buffer-name=playlist<CR>
        nnoremap <Leader>mu  :Unite mpc
    endif
    if exists("*submode#map")
        call submode#enter_with('mpc/seek', 'n', '', '<leader>ms', ':MpcCurrent<CR>')
        call submode#leave_with('mpc/seek', 'n', '', '<Esc>')
        call submode#map ('mpc/seek', 'n', '', '-', ':Mpc seek -1<CR> :MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', 'h', ':Mpc seek -1<CR> :MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '+', ':Mpc seek +1<CR> :MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', 'l', ':Mpc seek +1<CR> :MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '>', ':Mpc seek +30<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '<', ':Mpc seek -30<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '0', ':Mpc seek 0%<CR> :MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '1', ':Mpc seek 10%<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '2', ':Mpc seek 20%<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '3', ':Mpc seek 30%<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '4', ':Mpc seek 40%<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '5', ':Mpc seek 50%<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '6', ':Mpc seek 60%<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '7', ':Mpc seek 70%<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '8', ':Mpc seek 80%<CR>:MpcCurrent<CR>')
        call submode#map ('mpc/seek', 'n', '', '9', ':Mpc seek 90%<CR>:MpcCurrent<CR>')
    endif
endif

command! -nargs=? Mpc           call Mpc(<q-args>)
command! -nargs=0 MpcClear      call Mpc("clear")
command! -nargs=0 MpcCurrent    call s:mpc_cunnret()
command! -nargs=0 MpcConsume    call s:mpc_toggle("consume")
command! -nargs=0 MpcCurrentMusicLyrics     call s:mpc_fetch_current_music_lyrics()
command! -nargs=0 MpcNext       call Mpc("next") | 
                                \ echo "Playing: ".Mpc("current")[:-2]
command! -nargs=0 MpcPlay       call Mpc("play") |
command! -nargs=0 MpcPause      call Mpc("pause")
command! -nargs=0 MpcPrev       call Mpc("prev") |
                                \ echo "Playing: ".Mpc("current")[:-2]
command! -nargs=0 MpcRandom     call s:mpc_toggle("random")
command! -nargs=0 MpcRepeat     call s:mpc_toggle("repeat")
command! -nargs=0 MpcSingle     call s:mpc_toggle("single")
command! -nargs=0 MpcStatus     echo Mpc("status")
command! -nargs=1 MpcSave       call s:mpc_save(<q-args>)
command! -nargs=0 MpcShuffle    call Mpc("shuffle")
command! -nargs=0 MpcStop       call Mpc("stop")
command! -nargs=0 MpcToggle     call Mpc("toggle")

"------------------------------
let &cpo = s:save_cpo
unlet s:save_cpo
