#compdef jpm
# zsh completion for jpm (https://github.com/janet-lang/jpm)
# Install: place this file in a directory on your $fpath, e.g. ~/.zsh/completions/_jpm
#          then run: autoload -Uz compinit && compinit

local -a subcommands
subcommands=(
    'build:Build the current project'
    'clean:Remove build artifacts'
    'configure:Configure build settings'
    'clear-cache:Clear the git package cache'
    'clear-manifest:Clear the install manifest'
    'debug-repl:Start a debug REPL'
    'deps:Install project dependencies'
    'exec:Run a command with JANET_PATH set'
    'help:Show help text'
    'install:Install the current project or a package'
    'janet:Run janet with JANET_PATH set'
    'list-installed:List installed packages'
    'list-pkgs:List available packages'
    'load-lockfile:Install packages from a lockfile'
    'make-lockfile:Create a reproducible lockfile'
    'new-c-project:Scaffold a new C+Janet project'
    'new-exe-project:Scaffold a new executable project'
    'new-project:Scaffold a new Janet project'
    'quickbin:Create a standalone executable from a script'
    'repl:Start a REPL with project env'
    'rule-tree:Show the build rule dependency tree'
    'rules:List all build rules'
    'run:Run a specific build rule'
    'save-config:Save current config to a file'
    'show-config:Print current configuration'
    'show-paths:Print install paths'
    'tasks:List defined project tasks'
    'test:Run project tests'
    'uninstall:Uninstall the current project or a package'
    'update-installed:Reinstall all installed packages'
    'update-pkgs:Update the package listing'
)

local -a global_opts
global_opts=(
    '(-l --local)'{-l,--local}'[Use local tree ./jpm_tree]'
    '(-v --verbose)'{-v,--verbose}'[Show verbose output]'
    '--offline[Do not download remote repositories]'
    '--silent[Suppress subprocess output]'
    '--nocolor[Disable color in debug REPL]'
    '--test[Enable testing when installing]'
    '--update-pkgs[Update package listing before running]'
    '--tree=[Use a custom tree directory]:directory:_files -/'
    '--config-file=[Load settings from config file]:file:_files'
    '--modpath=[Module installation directory]:directory:_files -/'
    '--binpath=[Binary installation directory]:directory:_files -/'
    '--headerpath=[Janet headers directory]:directory:_files -/'
    '--optimize=[C/C++ optimization level]:level:(0 1 2 3)'
    '--workers=[Number of parallel build workers]:count: '
    '--build-type=[Build preset]:type:(release debug develop)'
)

_jpm() {
    local state

    _arguments -C \
        $global_opts \
        '1: :->subcommand' \
        '*: :->args' \
        && return 0

    case $state in
        subcommand)
            _describe 'jpm subcommand' subcommands
            ;;
        args)
            case $words[2] in
                install)
                    _files
                    ;;
                load-lockfile|make-lockfile)
                    _files -g '*.jdn'
                    ;;
                new-project|new-c-project|new-exe-project)
                    _message 'project name'
                    ;;
                run|rule-tree)
                    local rules
                    if rules=$(jpm rules 2>/dev/null); then
                        _values 'rule' ${(f)rules}
                    fi
                    ;;
            esac
            ;;
    esac
}

_jpm "$@"
