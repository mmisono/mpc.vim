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

if !exists('g:mpc_host')
    let g:mpc_host= "localhost"
endif

if !exists('g:mpc_port')
    let g:mpc_port= "6600"
endif

if !exists('g:mpc_format')
    let g:mpc_format = '"[[%artist% : %album% - ]%title%]|[%file%]"'
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
function! Fetch_lyrics(artist,title)
    let artist =  substitute(a:artist," ","+","g")
    let title  =  substitute(a:title," ","+","g")
    let url = "http://lyrics.wikia.com/api.php?action=lyrics&fmt=xml&".
                \"func=getSong&artist=".artist."&song=".title
    let r = system('curl "'.url.'"')
    if r =~ "<lyrics>Not found</lyrics>"
        echo "lyrics not found"
        return 
    endif
    let start = stridx(r,"<url>")
    let end   = stridx(r,"</url>")
    let url = r[start+5 : end-1]

    let r = system('curl "'.url.'"')
    let start =  stridx(r,"'17'/></a></div>")
    let end = stridx(r,"<!--",start)
    let lyrics =  split(html#decodeEntityReference(
                \r[start+16 : end-1]),'<br />')


    let artist =  substitute(a:artist," ","_","g")
    let title  =  substitute(a:title," ","_","g")
    exe "silent top split Lyrics:".artist."-".title
    call append(0,lyrics)
    call append(0,[a:artist." - ".a:title,""])
    setl nomodified
    setl bufhidden=delete
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
        nnoremap <Leader>ml  :Unite mpc<CR>
        nnoremap <Leader>mp  :Unite mpc:playlist<CR>
        nnoremap <Leader>mu  :Unite mpc
    endif
    if exists("*submode#map")
        call submode#enter_with('mpc/seek', 'n', '', '<leader>ms', '<Nop>')
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
