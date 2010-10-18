" redocommand.vim : Execute commands from the command history. 
"
" DEPENDENCIES:
"   - Requires VIM 7.0 or higher.  
"
" Copyright: (C) 2005-2009 by Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'. 
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
" REVISION	DATE		REMARKS 
"   1.20.006	03-Apr-2009	Added optional [count] to repeat the Nth, not
"				the last found match. 
"				Moved functions from plugin to separate autoload
"				script. 
"   1.10.005	16-Jan-2009	Now setting v:errmsg on errors. 
"   1.10.004	04-Aug-2008	Implemented ':Redocommand old=new {pattern}'. 
"				Now requiring VIM 7. 
"   1.00.003	04-Aug-2008	Better handling of errors during execution of
"				the command. 
"				The redone command is added to the history. 
"	0.02	30-Mar-2006	Added requirements check.
"				Added (configurable) short command :R. 
"				Replaced quirky 'RemoveRedocommandFromHistory()'
"				with unconditional remove from history. 
"	0.01	23-May-2005	file creation

" Avoid installing twice or when in unsupported VIM version.  
if exists('g:loaded_redocommand') || (v:version < 700)
    finish
endif
let g:loaded_redocommand = 1

" Requirement: command-line history compiled-in and activated
if ! has('cmdline_hist') || (&history < 2)
    finish
endif

if ! exists('g:redocommand_no_short_command') || ! g:redocommand_no_short_command
    command! -count=1 -nargs=* -complete=command R call redocommand#Redocommand(<count>, <f-args>)
endif
command! -count=1 -nargs=* -complete=command Redocommand call redocommand#Redocommand(<count>, <f-args>)

" vim: set sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
