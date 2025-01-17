vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Old but can still be useful {{{1
#     def HasSurroundingFencemarks(lnum: number): bool {{{2
#         var pos: list<number> = [line('.'), col('.')]
#         cursor(lnum, 1)
#
#         var start_fence: string = '\%^```\|^\n\zs```'
#         var end_fence: string = '```\n^$'
#         var fence_position: list<number> = searchpairpos(start_fence, '', end_fence, 'W')
#
#         cursor(pos)
#         return fence_position != [0, 0]
#     enddef
#
#     def HasSyntaxGroup(lnum: number): bool {{{2
#         var syntax_groups: list<string> = synstack(lnum, 1)
#             ->mapnew((_, v: number): string => synIDattr(v, 'name'))
#         for value in syntax_groups
#             if value =~? 'markdown\%(Code\|Highlight\)'
#                 return true
#             endif
#         endfor
#         return false
#     enddef
#
#     def LineIsFenced(lnum: number): bool {{{2
#         if get(b:, 'current_syntax', '') == 'markdown'
#             # It's cheap to check if the current line has 'markdownCode' syntax group
#             return HasSyntaxGroup(lnum)
#         else
#             # Using `searchpairpos()` is expensive, so only do it if syntax highlighting is not enabled
#             return HasSurroundingFencemarks(lnum)
#         endif
#     enddef
# }}}1

def markdown#fold#foldexpr#toggle() #{{{1
    &l:fde = &l:fde == 'markdown#fold#foldexpr#stacked()'
        ? 'markdown#fold#foldexpr#nested()'
        : 'markdown#fold#foldexpr#stacked()'
    # Why?{{{
    #
    # We set `'fdm'` to `manual` by default, because `expr` can be much more expensive.
    # As a consequence, if we change  the value of `'fde'`, Vim won't re-compute
    # the folds; we want it to; that's why we need to execute `#compute()`.
    #}}}
    sil! fold#lazy#compute(false)
enddef
#}}}1
def markdown#fold#foldexpr#headingDepth(lnum: number): number #{{{1
    var thisline: string = getline(lnum)
    var level: number = matchend(thisline, '^#\{1,6}')
    if level > 0 && thisline != '' && thisline != '```'
        var nextline: string = getline(lnum + 1)
        if nextline =~ '^=\+\s*$'
            return 1
        # Why `\{2,}` and not just `\+`?{{{
        #
        # Indeed, according to the markdown spec would parse, a single hyphen at
        # the  start of  a line  is enough  to start  a heading.   However, it's
        # *very* annoying for Vim to parse a  single hyphen as a heading when we
        # put a diff in a markdown file.
        #}}}
        elseif nextline =~ '^-\{2,}\s*$'
            return 2
        endif
    endif
    # Temporarily commented because it makes us gain 0.5 seconds when loading Vim notes:{{{
    #
    #     if level > 0 && LineIsFenced(lnum)
    #         # Ignore # or === if they appear within fenced code blocks
    #         return 0
    #     endif
    #
    # If  you uncomment it, in  the previous block, replace  `return {1|2}` with
    # `var level: number = {1|2}`.
    #}}}
    return level
enddef

def markdown#fold#foldexpr#nested(): string #{{{1
    var depth: number = markdown#fold#foldexpr#headingDepth(v:lnum)
    return depth > 0 ? '>' .. depth : '='
enddef

def markdown#fold#foldexpr#stacked(): string #{{{1
    # Why would it be useful to return `1` instead of `'='`?{{{
    #
    # Run this shell command:
    #
    #     $ vim -Nu <(cat <<'EOF'
    #         setl fdm=expr fde=HeadingDepth(v:lnum)>0?'>1':'1' debug=throw
    #         def HeadingDepth(lnum: number): number
    #             var level: number = getline(lnum)->matchend('^#\{1,6}')
    #             if level == -1
    #                 if getline(lnum + 1) =~ '^=\+\s*$'
    #                     level = 1
    #                 endif
    #             endif
    #             return level
    #         enddef
    #         ino <expr> <c-k> repeat('<del>', 300)
    #     EOF
    #     ) +"%d | put='text' | norm! yy300pG300Ax" /tmp/md.md
    #
    # Vim starts up after about 2 seconds.
    # Next, press `I C-k`; Vim removes 300 characters after about 2 seconds.
    #
    # Now, replace  `'='` with `1` and  re-run the same command:  this time, Vim
    # starts up immediately; similarly, it removes 300 characters immediately.
    #}}}
    #   Why is it possible here, but not in `#nested()`?{{{
    #
    # Because this function is meant for files with only level-1 folds.
    # OTOH, we can't in `#nested()`, because  the latter is meant for files with
    # up to level-6 folds.
    #}}}
    #   Why don't you return `1` then?{{{
    #
    # If you write some lines before the first heading line, they will be folded.
    # I don't want such lines to be folded.
    # A line should be folded only if it's somewhere below a heading line.
    #
    # See also our comments in:
    #
    #     ~/.vim/plugged/vim-git/after/ftplugin/git.vim
    #
    # One of them illustrates how `'='` is preferable to `1`.
    # Folding too much can have unexpected results.
    #}}}
    #     But doesn't it make the performance worse?{{{
    #
    # No, because – in  big enough files – as soon as Vim  creates the folds, we
    # reset `'fdm'` to `manual` which is less costly.
    #}}}
    return markdown#fold#foldexpr#headingDepth(v:lnum) > 0 ? '>1' : '='
enddef

