# fish completion for janet (https://github.com/janet-lang/janet)
# Install: place this file in ~/.config/fish/completions/janet.fish

# Flags that take an argument
complete -c janet -s e -l eval       -r -d "Execute a string of Janet code"
complete -c janet -s E -l expression -r -d "Evaluate as short-fn with arguments"
complete -c janet -s m -l syspath    -r -d "Set system path for loading global modules" -a "(__fish_complete_directories)"
complete -c janet -s c -l compile    -r -d "Compile source to image" -a "(__fish_complete_suffix .janet)"
complete -c janet -s l -l library   -r -d "Use a module before processing more arguments"
complete -c janet -s w -l lint-warn  -r -d "Lint warning level" -a "none normal strict"
complete -c janet -s x -l lint-error -r -d "Lint error level"   -a "none normal strict"
complete -c janet -s b -l install    -r -d "Install a bundle from a directory"
complete -c janet -s B -l reinstall  -r -d "Reinstall a bundle by name"
complete -c janet -s u -l uninstall  -r -d "Uninstall a bundle by name"

# Boolean flags
complete -c janet -s h -l help        -d "Show help"
complete -c janet -s v -l version     -d "Print version"
complete -c janet -s s -l stdin       -d "Use raw stdin"
complete -c janet -s d -l debug       -d "Set debug flag in the REPL"
complete -c janet -s r -l repl        -d "Enter REPL after running scripts"
complete -c janet -s R -l noprofile   -d "Disable loading profile.janet"
complete -c janet -s p -l persistent  -d "Keep executing on top-level errors"
complete -c janet -s q -l quiet       -d "Hide logo"
complete -c janet -s k -l flycheck    -d "Compile but do not execute"
complete -c janet -s i -l image       -d "Load script argument as image file"
complete -c janet -s n -l nocolor     -d "Disable ANSI color in REPL"
complete -c janet -s N -l color       -d "Enable ANSI color in REPL"
complete -c janet -s U -l update-all  -d "Reinstall all installed bundles"
complete -c janet -s P -l prune       -d "Uninstall orphaned bundles"
complete -c janet -s L -l list        -d "List all installed bundles"

# Default: complete with .janet files and .jimage files
complete -c janet -a "(__fish_complete_suffix .janet .jimage)" -d "Script"
