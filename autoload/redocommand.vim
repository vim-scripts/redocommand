" redocommand.vim: Execute commands from the command history.
"
" DEPENDENCIES:
"
" Copyright: (C) 2005-2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
" REVISION	DATE		REMARKS
"   1.40.005	20-Jul-2012	ENH: Add :RedoBufferRepeat and
"				:RedoWindowRepeat commands.
"   1.30.004	22-Nov-2011	ENH: Allow repeat of any :Redocommand via
"				[count].
"   1.30.003	21-Nov-2011	Factor out s:SubstituteAndRedo().
"				ENH: Add :RedoRepeat command to repeat the last
"				:Redocommand when other Ex commands (e.g.
"				:wnext) were issued in between.
"   1.21.002	15-Oct-2009	ENH: If the {pattern} starts with : (and there
"				is no history command matching the literal
"				":cmd"), the history is searched for "cmd",
"				anchored at the beginning. This is convenient
"				because ":R :echo" is more intuitive to type
"				than ":R ^echo".
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
let s:redoCommands = []
function! s:SubstituteAndRedo( historyCommand, substitutions )
    let l:redoCommand = s:Substitute(a:historyCommand, a:substitutions)
    echo ':' . l:redoCommand
    try
	execute l:redoCommand
	call histadd('cmd', l:redoCommand)
    catch /^Vim\%((\a\+)\)\=:E/
	echohl ErrorMsg
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away.
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echomsg v:errmsg
	echohl None
    endtry

    return l:redoCommand
endfunction
function! s:Redocommand( count, substitutions, commandexpr )
    let l:matchCnt = 0
    let l:histnr = histnr('cmd')
    while l:histnr > 0
	let l:historyCommand = histget('cmd', l:histnr)
	if l:historyCommand =~ a:commandexpr
	    let l:matchCnt += 1
	    if a:count == 0 || a:count == l:matchCnt
		let l:redoCommand = s:SubstituteAndRedo(l:historyCommand, a:substitutions)

		call add(s:redoCommands, l:redoCommand)
		if ! exists('b:redoCommands') | let b:redoCommands = [] | endif
		call add(b:redoCommands, l:redoCommand)
		if ! exists('w:redoCommands') | let w:redoCommands = [] | endif
		call add(w:redoCommands, l:redoCommand)

		return
	    endif
	endif
	let l:histnr -= 1
	if a:count == 0 | break | endif
    endwhile

    if a:commandexpr =~# ':'
	call s:Redocommand(a:count, a:substitutions, substitute(a:commandexpr, '^:\+', '', ''))
	return
    endif

    call s:WarnAboutNoMatch(a:commandexpr, a:count, l:matchCnt)
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

    " The history must not be cluttered with :Redocommand.
    " Remove the ':Redocommand' that is currently executed from the history.
    " If someone foolishly uses :Redocommand in a mapping or script (where
    " commands are not added to the history), an innocent last history entry
    " will be removed - bad luck.
    call histdel('cmd', -1)

    call s:Redocommand(a:count, l:substitutions, l:commandexpr)
endfunction

function! s:RedoRepeat( commands, count, ... )
    " The history must not be cluttered with :RedoRepeat.
    " Remove the ':RedoRepeat' that is currently executed from the history.
    call histdel('cmd', -1)

    if empty(a:commands)
	let v:errmsg = 'No :Redocommand to repeat'
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None

	return
    elseif len(a:commands) < a:count
	let v:errmsg = printf('Only %d :Redocommand%s to repeat', len(a:commands), (len(a:commands) == 1 ? '' : 's'))
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None

	return
    endif

    let l:redoCommand = (a:count == 0 ? a:commands[-1] : a:commands[a:count - 1])
    call s:SubstituteAndRedo(l:redoCommand, a:000)
endfunction
function! redocommand#RedoRepeat( count, ... )
    call call('s:RedoRepeat', [s:redoCommands, a:count] + a:000)
endfunction
function! redocommand#RedoBufferRepeat( count, ... )
    if ! exists('b:redoCommands')
	let v:errmsg = 'No :Redocommand to repeat' . (empty(s:redoCommands) ? '' : ' for this buffer')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None

	return
    endif

    call call('s:RedoRepeat', [b:redoCommands, a:count] + a:000)
endfunction
function! redocommand#RedoWindowRepeat( count, ... )
    if ! exists('w:redoCommands')
	let v:errmsg = 'No :Redocommand to repeat' . (empty(s:redoCommands) ? '' : ' for this window')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None

	return
    endif

    call call('s:RedoRepeat', [w:redoCommands, a:count] + a:000)
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
