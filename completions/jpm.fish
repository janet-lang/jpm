# fish completion for jpm (https://github.com/janet-lang/jpm)
# Install: place this file in ~/.config/fish/completions/jpm.fish

# Subcommands
set -l subcommands \
    "build\tBuild the current project" \
    "clean\tRemove build artifacts" \
    "configure\tConfigure build settings" \
    "clear-cache\tClear the git package cache" \
    "clear-manifest\tClear the install manifest" \
    "debug-repl\tStart a debug REPL" \
    "deps\tInstall project dependencies" \
    "exec\tRun a command with JANET_PATH set" \
    "help\tShow help text" \
    "install\tInstall the current project or a package" \
    "janet\tRun janet with JANET_PATH set" \
    "list-installed\tList installed packages" \
    "list-pkgs\tList available packages" \
    "load-lockfile\tInstall from a lockfile" \
    "make-lockfile\tCreate a lockfile" \
    "new-c-project\tScaffold a new C+Janet project" \
    "new-exe-project\tScaffold a new executable project" \
    "new-project\tScaffold a new Janet project" \
    "quickbin\tCreate a standalone executable from a script" \
    "repl\tStart a REPL with project env" \
    "rule-tree\tShow the build rule dependency tree" \
    "rules\tList all build rules" \
    "run\tRun a specific build rule" \
    "save-config\tSave current config to a file" \
    "show-config\tPrint current configuration" \
    "show-paths\tPrint install paths" \
    "tasks\tList defined project tasks" \
    "test\tRun project tests" \
    "uninstall\tUninstall the current project or a package" \
    "update-installed\tReinstall all installed packages" \
    "update-pkgs\tUpdate the package listing"

# Only offer subcommands when none has been given yet
function __jpm_no_subcommand
    for word in (commandline -opc)
        if contains -- $word build clean configure clear-cache clear-manifest \
                debug-repl deps exec help install janet list-installed list-pkgs \
                load-lockfile make-lockfile new-c-project new-exe-project new-project \
                quickbin repl rule-tree rules run save-config show-config show-paths \
                tasks test uninstall update-installed update-pkgs
            return 1
        end
    end
    return 0
end

complete -c jpm -f -n __jpm_no_subcommand -a $subcommands

# Global flags
complete -c jpm -l local       -s l -d "Use local tree ./jpm_tree"
complete -c jpm -l verbose     -s v -d "Show verbose output"
complete -c jpm -l offline          -d "Do not download remote repositories"
complete -c jpm -l silent           -d "Suppress subprocess output"
complete -c jpm -l nocolor          -d "Disable color in debug REPL"
complete -c jpm -l test             -d "Enable testing when installing"
complete -c jpm -l update-pkgs      -d "Update package listing before running"
complete -c jpm -l tree        -r   -d "Use a custom tree directory"
complete -c jpm -l config-file -r   -d "Load settings from this config file"
complete -c jpm -l modpath     -r   -d "Module installation directory"
complete -c jpm -l binpath     -r   -d "Binary installation directory"
complete -c jpm -l headerpath  -r   -d "Janet headers directory"
complete -c jpm -l optimize    -r   -d "C/C++ optimization level (0-3)"
complete -c jpm -l workers     -r   -d "Number of parallel build workers"
complete -c jpm -l build-type  -r   -d "Build preset: release, debug, or develop"

# Lockfile completions for relevant subcommands
complete -c jpm -n "__fish_seen_subcommand_from load-lockfile make-lockfile" -a "*.jdn" -d "Lockfile"
