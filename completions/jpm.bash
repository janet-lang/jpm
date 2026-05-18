# bash completion for jpm (https://github.com/janet-lang/jpm)
# Install: place this file in ~/.local/share/bash-completion/completions/jpm
#          or source it from your ~/.bashrc

_jpm_subcommands=(
    build
    clean
    configure
    clear-cache
    clear-manifest
    debug-repl
    deps
    exec
    help
    install
    janet
    list-installed
    list-pkgs
    load-lockfile
    make-lockfile
    new-c-project
    new-exe-project
    new-project
    quickbin
    repl
    rule-tree
    rules
    run
    save-config
    show-config
    show-paths
    tasks
    test
    uninstall
    update-installed
    update-pkgs
)

_jpm_global_flags=(
    --local
    --tree=
    --verbose
    --offline
    --silent
    --nocolor
    --test
    --update-pkgs
    --config-file=
    --modpath=
    --binpath=
    --headerpath=
    --libpath=
    --optimize=
    --workers=
    --build-type=
)

_jpm() {
    local cur prev words cword
    _init_completion || return

    # Complete global flags
    if [[ "$cur" == --* ]]; then
        COMPREPLY=( $(compgen -W "${_jpm_global_flags[*]}" -- "$cur") )
        return
    fi

    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "-l -v" -- "$cur") )
        return
    fi

    # Find if a subcommand has already been given
    local subcommand=""
    for word in "${words[@]:1}"; do
        if [[ "$word" != -* ]]; then
            subcommand="$word"
            break
        fi
    done

    if [[ -z "$subcommand" || "$cur" == "$subcommand" ]]; then
        COMPREPLY=( $(compgen -W "${_jpm_subcommands[*]}" -- "$cur") )
        return
    fi

    # Subcommand-specific completions
    case "$subcommand" in
        install)
            # Repo URLs or package names; fall back to file completion
            _filedir
            ;;
        run|rule-tree)
            # Complete with rules from project if available
            if command -v jpm &>/dev/null; then
                local rules
                rules=$(jpm rules 2>/dev/null | awk '{print $1}')
                COMPREPLY=( $(compgen -W "$rules" -- "$cur") )
            fi
            ;;
        load-lockfile|make-lockfile|config-file)
            _filedir '*.jdn'
            ;;
        new-project|new-c-project|new-exe-project|quickbin)
            # Expects a name/path argument
            _filedir -d
            ;;
        *)
            ;;
    esac
}

complete -F _jpm jpm
