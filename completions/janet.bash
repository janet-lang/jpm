# bash completion for janet (https://github.com/janet-lang/janet)
# Install: place this file in ~/.local/share/bash-completion/completions/janet
#          or source it from your ~/.bashrc

_janet_flags=(
    -h --help
    -v --version
    -s --stdin
    -e --eval
    -E --expression
    -d --debug
    -r --repl
    -R --noprofile
    -p --persistent
    -q --quiet
    -k --flycheck
    -m --syspath
    -c --compile
    -i --image
    -n --nocolor
    -N --color
    -l --library
    -w --lint-warn
    -x --lint-error
    -b --install
    -B --reinstall
    -u --uninstall
    -U --update-all
    -P --prune
    -L --list
    --
)

_janet() {
    local cur prev
    _init_completion || return

    case "$prev" in
        -e|--eval|-E|--expression)
            # Expects a code string — no file completion
            return
            ;;
        -m|--syspath)
            _filedir -d
            return
            ;;
        -c|--compile|-l|--library|-b|--install)
            _filedir
            return
            ;;
        -w|--lint-warn|-x|--lint-error)
            COMPREPLY=( $(compgen -W "none normal strict" -- "$cur") )
            return
            ;;
        -B|--reinstall|-u|--uninstall)
            # Bundle names — no obvious completion source
            return
            ;;
    esac

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "${_janet_flags[*]}" -- "$cur") )
        return
    fi

    # Default: complete with janet source files and images
    _filedir '@(janet|jimage)'
}

complete -F _janet janet
