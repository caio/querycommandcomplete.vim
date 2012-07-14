" Query Command Complete
" ======================
"
" Vim plugin to suggest completions with the results or an external
" query command.
"
" The original intention is to use it as a mutt query_command wrapper
" to complete addresses in the mail headers, but it can be adapted
" to any other kind of functionality by modifying the exposed setting
" parameters.
"
" Last Change: 2012 Jul 15
" Maintainer: Caio Romão <caioromao@gmail.com>
" License: This file is placed in the public domain
"
" Setup:
"   This plugin exports the completion function QueryCommandComplete,
"   which needs to be set as the complete function (or omni function)
"   in order to work.
"
"   Example:
"       let g:gcc_query_command='abook'
"       au BufRead /tmp/mutt* setlocal omnifunc=QueryCommandComplete
"
" Settings:
"   g:qcc_query_command
"       External command that queries for contacts
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

if exists("g:loaded_QueryCommandComplete") || &cp
  finish
endif

if !exists("g:qcc_query_command")
    echoerr "QueryCommandComplete: g:qcc_query_command not set!"
    finish
endif

let g:loaded_QueryCommandComplete = 1
let s:save_cpo = &cpo
set cpo&vim

function! DefaultIfUnset(name, default)
    if !exists(a:name)
        let {a:name} = a:default
    endif
endfunction

call DefaultIfUnset('g:qcc_line_separator', '\n')
call DefaultIfUnset('g:qcc_field_separator', '\t')
call DefaultIfUnset('g:qcc_pattern', '^\(To\|Cc\|Bcc\|From\|Reply-To\):')

function! s:MakeCompletionEntry(name, email, other)
    let entry = {}
    let entry.word = a:name . ' <' . a:email . '>'
    let entry.abbr = a:name
    let entry.menu = a:other
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

    if a:base =~ '^ *$'
        return []
    endif

    let results = []
    let cmd = g:qcc_query_command . ' ' . shellescape(a:base)
    let lines = split(system(cmd), g:qcc_line_separator)

    for my_line in lines
        let fields = split(my_line, g:qcc_field_separator)

        if (len(fields) < 2)
            continue
        endif

        let email = fields[0]
        let name = fields[1]
        let other = ''

        if (len(fields) > 2)
            let other = fields[2]
        endif

        let contact = s:MakeCompletionEntry(name, email, other)

        call add(results, contact)
    endfor

    return results
endfunction

function! QueryCommandComplete(findstart, base)
    let cur_line = getline(line('.'))

    " TODO: Figure out a way to handle multiline
    if cur_line =~ g:qcc_pattern
        return s:GenerateCompletions(a:findstart, a:base)
    endif
endfunction

let &cpo = s:save_cpo
