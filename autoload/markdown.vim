fu! markdown#define_fenced_clusters() abort "{{{1
    " What's the purpose of this `for` loop?{{{
    "
    " Iterate over the languages mentioned in `b:markdown_fenced_languages`, and
    " for each of them, include the corresponding syntax plugin.
    "}}}
    " If `b:markdown_fenced_languages` contains `javascript=js`, what does it mean?{{{
    "
    " It means we want any fenced block beginning with the line:
    "
    "     ```javascript
    "
    " ... to be highlighted with the `js` syntax plugin.
    "
    " https://github.com/ixandidu/vim-markdown/commit/16157135e794598c46f38b2167f41c124c7dcccb#commitcomment-20485418
    "}}}
    " Why `map(..., ... matchstr() ...)`?{{{
    "
    " If the text contains an equal sign:
    "
    "       js=javascript
    "
    " ... we're only interested in what's after (here `javascript`).
    " Because that's the name of the syntax plugin we need to source.
    "}}}
    let done_include = {}
    let filetypes = map(copy(get(b:, 'markdown_fenced_languages', [])), {i,v -> matchstr(v, '[^=]*$')})
    for ft in filetypes
        " If by  accident, we wrote the  same fenced language several  times, we
        " want to include the corresponding syntax plugin only once.
        if has_key(done_include, ft)
            continue
        endif
        exe 'syn include @markdownFenced'.ft.' syntax/'.ft.'.vim'
        " We need to remove `b:current_syntax` to be sure the next syntax plugin
        " can be sourced, even if it has a guard.
        unlet! b:current_syntax
        let done_include[ft] = 1
    endfor
endfu

fu! markdown#highlight_fenced_languages() abort "{{{1
    let done_include = {}
    for item in get(b:, 'markdown_fenced_languages', [])
        if has_key(done_include, item)
            continue
        endif
        let ft = matchstr(item,'[^=]*$')
        let delim = matchstr(item,'[^=]*')
        " Note that the name of the region is identical to the name of the cluster:{{{
        "
        "     'markdownFenced'.ft
        "
        " But there's no conflict.
        " Probably because a cluster name is always prefixed by `@`.
        "}}}
        exe 'syn region markdownFenced'.ft
        \ . ' matchgroup=markdownCodeDelimiter'
        \ . ' start="^\s*````*\s*'.delim.'\S\@!.*$"'
        \ . ' end="^\s*````*\ze\s*$"'
        \ . ' keepend'
        \ . ' concealends'
        \ . ' contains=@markdownFenced'.ft
        let done_include[item] = 1
    endfor
endfu

