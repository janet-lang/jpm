#compdef janet
# zsh completion for janet (https://github.com/janet-lang/janet)
# Install: place this file in a directory on your $fpath, e.g. ~/.zsh/completions/_janet
#          then run: autoload -Uz compinit && compinit

_janet() {
    _arguments \
        '(-h --help)'{-h,--help}'[Show help]' \
        '(-v --version)'{-v,--version}'[Print version]' \
        '(-s --stdin)'{-s,--stdin}'[Use raw stdin]' \
        '(-e --eval)'{-e,--eval}'[Execute a string of Janet code]:code: ' \
        '(-E --expression)'{-E,--expression}'[Evaluate as short-fn with arguments]:code: ' \
        '(-d --debug)'{-d,--debug}'[Set debug flag in the REPL]' \
        '(-r --repl)'{-r,--repl}'[Enter REPL after running scripts]' \
        '(-R --noprofile)'{-R,--noprofile}'[Disable loading profile.janet]' \
        '(-p --persistent)'{-p,--persistent}'[Keep executing on top-level errors]' \
        '(-q --quiet)'{-q,--quiet}'[Hide logo]' \
        '(-k --flycheck)'{-k,--flycheck}'[Compile but do not execute]' \
        '(-m --syspath)'{-m,--syspath}'[Set system path for modules]:syspath:_files -/' \
        '(-c --compile)'{-c,--compile}'[Compile source to image]:source:_files -g "*.janet"' \
        '(-i --image)'{-i,--image}'[Load script as image file]' \
        '(-n --nocolor)'{-n,--nocolor}'[Disable ANSI color in REPL]' \
        '(-N --color)'{-N,--color}'[Enable ANSI color in REPL]' \
        '(-l --library)'{-l,--library}'[Use a module before other args]:module:_files' \
        '(-w --lint-warn)'{-w,--lint-warn}'[Lint warning level]:level:(none normal strict)' \
        '(-x --lint-error)'{-x,--lint-error}'[Lint error level]:level:(none normal strict)' \
        '(-b --install)'{-b,--install}'[Install a bundle from directory]:directory:_files -/' \
        '(-B --reinstall)'{-B,--reinstall}'[Reinstall a bundle by name]:name: ' \
        '(-u --uninstall)'{-u,--uninstall}'[Uninstall a bundle by name]:name: ' \
        '(-U --update-all)'{-U,--update-all}'[Reinstall all installed bundles]' \
        '(-P --prune)'{-P,--prune}'[Uninstall orphaned bundles]' \
        '(-L --list)'{-L,--list}'[List all installed bundles]' \
        '--[Stop handling options]' \
        '*:script:_files -g "*.janet *.jimage"'
}

_janet "$@"
