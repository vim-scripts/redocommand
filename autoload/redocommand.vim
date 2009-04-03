" redocommand.vim : Execute commands from the command history. 
"
" DEPENDENCIES:
"
" Copyright: (C) 2005-2009 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
" REVISION	DATE		REMARKS 
"   1.20.001	03-Apr-2009	Moved functions from plugin to separate autoload
"				script. 
"				...

" To make the arg count as {pattern}, not a substitution, either use '.' instead
" of '=', or have the pattern start with '='. 
let s:patternPattern = '\(^.\+\)=\(.*$\)'
function! s:IsSubstitution( arg )
    return a:arg =~ s:patternPattern
endfunction
function! s:Substitute( expr, patterns )
    let l:replacement = a:expr

    for l:pattern in a:patterns
	let [l:match, l:from, l:to; l:rest] = matchlist( l:pattern, s:patternPattern )
	" Assumption: Applicability of a:pattern has been checked before via
	" s:IsSubstitution(). 
	if empty(l:match) || empty(l:from) | throw 'ASSERT: Pattern can be applied. ' | endif
	let l:replacement = substitute( l:replacement, '\V' . escape(l:from, '\'), escape(l:to, '\&~'), 'g' )
    endfor

    return l:replacement
endfunction

function! s:WarnAboutNoMatch( commandexpr, count, matchCnt )
    if a:count == 0
	let v:warningmsg = printf('The last command does not match "%s".', a:commandexpr)
    elseif a:count > 1 && a:matchCnt > 0
	let v:warningmsg = printf('Only %d command%s matching "%s" found in history.', a:matchCnt, (a:matchCnt == 1 ? '' : 's'), a:commandexpr)
    else
	let v:warningmsg = printf('No command matching "%s" found in history.', a:commandexpr)
    endif
    echohl WarningMsg
    echomsg v:warningmsg
    echohl None
endfunction

function! redocommand#Redocommand( count, ... )
    " An empty expression always matches, so this is used for the corner case of
    " no expression passed in, in which the last history command is executed. 
    let l:commandexpr = ''
    let l:substitutions = []

    let l:argIdx = 0
    while l:argIdx < a:0
	if s:IsSubstitution(a:000[l:argIdx])
	    call add(l:substitutions, a:000[l:argIdx])
	else
	    " Strictly, only the last argument should be the optional expr. If
	    " there are multiple expr, join them together with a <Space> in
	    " between. This way, spaces in the expr need not necessarily be
	    " escaped. 
	    let l:commandexpr = join(a:000[l:argIdx : ] , ' ')
	    break
	endif
	let l:argIdx += 1
    endwhile

    " The history must not be cluttered with :Redocommands. 
    " Remove the ':Redocommand' that is currently executed from the history. 
    " If someone foolishly uses :Redocommand in a mapping or script (where
    " commands are not added to the history), an innocent last history entry
    " will be removed - bad luck. 
    call histdel('cmd', -1)

    let l:matchCnt = 0
    let l:histnr = histnr('cmd') 
    while l:histnr > 0
	let l:historyCommand = histget('cmd', l:histnr)
	if l:historyCommand =~ l:commandexpr
	    let l:matchCnt += 1
	    if a:count == 0 || a:count == l:matchCnt
		let l:newCommand = s:Substitute( l:historyCommand, l:substitutions )
		echo ':' . l:newCommand
		try
		    execute l:newCommand
		    call histadd('cmd', l:newCommand)
		catch /^Vim\%((\a\+)\)\=:E/
		    echohl ErrorMsg
		    " v:exception contains what is normally in v:errmsg, but with extra
		    " exception source info prepended, which we cut away. 
		    let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
		    echomsg v:errmsg
		    echohl None
		endtry
		return
	    endif
	endif
	let l:histnr -= 1
	if a:count == 0 | break | endif
    endwhile

    call s:WarnAboutNoMatch(l:commandexpr, a:count, l:matchCnt)
endfunction

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
