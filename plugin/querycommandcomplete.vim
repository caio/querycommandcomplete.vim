" Query Command Complete
" ======================
"
" Vim plugin to suggest completions with the results of an external
" query command.
"
" The original intention is to use it as a mutt query_command wrapper
" to complete addresses in the mail headers, but it can be adapted
" to any other kind of functionality by modifying the exposed setting
" parameters.
"
" Last Change: 2013 Jun 16
" Author: Caio Romão (http://caioromao.com)
" License: This file is placed in the public domain
" Contributors:
"   Brian Henderson https://github.com/bhenderson
"   Mark Stillwell  https://github.com/marklee77
"   Rui Abreu Ferreira http://ruiabreu.org
"
" Setup:
"   This plugin exports the completion function QueryCommandComplete,
"   which can be set as the complete function (or omni function) for
"   any filetype. If you have a working mutt setup with query_command
"   configured, the plugin works out of the box.
"
"   Example:
"       let g:qcc_query_command='abook'
"       au BufRead /tmp/mutt* setlocal omnifunc=QueryCommandComplete
"
" Settings:
"   Note: Overriding settings on a buffer-basis is supported. So
"         b:qcc_query_command takes precedence over g:qcc_query_command
"
"   g:qcc_query_command
"       External command that queries for contacts
"       If empty, QueryCommandComplete tries to guess what command to
"       run by executing `mutt -Q query_command`.
"
"   g:qcc_line_separator
"       Separator for each entry in the result from the query
"       default: '\n'
"
"   g:qcc_field_separator
"       Separator for the fields of an entry from the result
"       default: '\t'
"
"   g:qcc_pattern
"       Pattern used to match against the current line to decide
"       whether to call the query command
"       default: '^\(To\|Cc\|Bcc\|From\|Reply-To\):'
"
"   g:qcc_multiline
"       Whether to try matching g:qcc_pattern against the current
"       and any previous line
"       default: 0
"
"   g:qcc_multiline_pattern
"       Pattern to match against the current line when deciding
"       wether to keep looking for a line that matches g:qcc_pattern
"       This provides finer control over the recursion, which
"       is useful if calling the completion on really big files.
"       default: '.*'
"
"   g:qcc_format_word
"       Format string to be used when building the word field
"       of the completion (i.e.: the final result, what gets fed into
"       the current line when you select an option)
"       default: '${1} <${0}>' (as in: FirstName <email@domain.com>)
"
"   g:qcc_format_abbr
"       Format string to be used when building the abbreviation
"       for the completion menu (i.e.: the first row in the completion
"       menu).
"       default: '${1}'
"
"   g:qcc_format_menu
"       Format string for the optional second column of the completion
"       menu.
"       default: '${2}'
"


if exists("g:loaded_QueryCommandComplete") || &cp
  finish
endif

function! s:GetSetting(name)
    let global_option = 'g:qcc_' . a:name
    let local_option = 'b:qcc_' . a:name

    let result = ''
    if exists(local_option)
        let result = {local_option}
    elseif exists(global_option)
        let result = {global_option}
    endif

    return result
endfunction

let g:loaded_QueryCommandComplete = 1
let s:save_cpo = &cpo
set cpo&vim

function! s:DefaultIfUnset(name, default)
    if !exists(a:name)
        let {a:name} = a:default
    endif
endfunction

call s:DefaultIfUnset('g:qcc_line_separator', '\n')
call s:DefaultIfUnset('g:qcc_field_separator', '\t')
call s:DefaultIfUnset('g:qcc_pattern', '^\(To\|Cc\|Bcc\|From\|Reply-To\):')
call s:DefaultIfUnset('g:qcc_multiline', 0)
call s:DefaultIfUnset('g:qcc_multiline_pattern', '.*')
call s:DefaultIfUnset('g:qcc_format_word', '${1} <${0}>')
call s:DefaultIfUnset('g:qcc_format_abbr', '${1}')
call s:DefaultIfUnset('g:qcc_format_menu', '${2}')

" Given a format string where the placeholders are in the format
" '${index}' and index is a valid index the the given 'fields'
" argument, this function returns a string with all placeholders
" replaced by the corresponding data in the fields list.
" FIXME I can't help but think there's a standard way to do this
"       but I failed finding it. Please call me a dumbass if you
"       know The Easy Way.
function! s:ApplyFieldsToFormatString(fields, format)
    let result = a:format

    while 1
        let placeholder = matchstr(result, '${[0-9]}')

        if (empty(placeholder))
            break
        endif

        let index = matchstr(placeholder, '[0-9]')

        " If ${NUMBER} is not a valid index in a:fields,
        " use '' as a fallback.
        " FIXME Decide whether to warn/err/whatever here
        let content = ''
        if (len(a:fields) > index)
            let content = a:fields[index]
        endif

        let result = substitute(result, placeholder, content, 'g')

    endwhile

    return result
endfunction

function! s:MakeCompletionEntry(fields)
    let entry = {}
    let entry.word = s:ApplyFieldsToFormatString(a:fields, s:GetSetting('format_word'))
    let entry.abbr = s:ApplyFieldsToFormatString(a:fields, s:GetSetting('format_abbr'))
    let entry.menu = s:ApplyFieldsToFormatString(a:fields, s:GetSetting('format_menu'))
    let entry.icase = 1
    return entry
endfunction

function! s:FindStartingIndex()
    let cur_line = getline('.')

    " locate the start of the word
    let start = col('.') - 1
    while start > 0 && cur_line[start - 1] =~ '[^:,]'
        let start -= 1
    endwhile

    " lstrip()
    while cur_line[start] =~ '[ ]'
        let start += 1
    endwhile

    return start
endfunction

function! s:GenerateCompletions(findstart, base)
    if a:findstart
        return s:FindStartingIndex()
    endif

    let results = []
    let cmd = s:GetSetting('query_command')
    if cmd !~ '%s'
        let cmd .= ' %s'
    endif
    let cmd = substitute(cmd, '%s', shellescape(a:base), '')
    let lines = split(system(cmd), g:qcc_line_separator)

    for my_line in lines
        let fields = split(my_line, g:qcc_field_separator)

        let entry = s:MakeCompletionEntry(fields)

        call add(results, entry)
    endfor

    return results
endfunction

function! s:ShouldGenerateCompletions(line_number)
    let current_line = getline(a:line_number)

    if current_line =~ g:qcc_pattern
        return 1
    endif

    if ! g:qcc_multiline || a:line_number <= 1 || current_line !~ g:qcc_multiline_pattern
        return 0
    endif

    return s:ShouldGenerateCompletions(a:line_number - 1)
endfunction

function! s:CheckSettings()
    " Try to use mutt's query_command by default if nothing is set
    if empty(s:GetSetting('query_command'))
        let s:querycmd = system('mutt -Q query_command 2>/dev/null')
        let s:querycmd = substitute(s:querycmd, '^query_command="\(.*\)"\n', '\1','')

        if len(s:querycmd)
            let g:qcc_query_command = s:querycmd
            let g:qcc_multiline = 1
            autocmd FileType mail setlocal omnifunc=QueryCommandComplete
        else
            echoerr "QueryCommandComplete: g:qcc_query_command not set!"
            return 0
        endif
    endif
    return 1
endfunction

function! QueryCommandComplete(findstart, base)
    if s:CheckSettings() && s:ShouldGenerateCompletions(line('.'))
        return s:GenerateCompletions(a:findstart, a:base)
    endif
endfunction

let &cpo = s:save_cpo
