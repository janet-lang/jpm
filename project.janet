(declare-project
  :name "jpm")

(declare-source
  :source ["cc.janet"
           "cli.janet"
           "commands.janet"
           "config.janet"
           "dagbuild.janet"
           "declare.janet"
           "pm.janet"
           "rules.janet"
           "shutil.janet"
           "cgen.janet"]
  :prefix "jpm")

# Install the default configuration for bootstrapping
(when-let [bc (dyn :bootstrap-config "default-config.janet")]
  (install-file-rule bc (string (dyn :modpath) "/jpm/default-config.janet")))

(declare-manpage "jpm.1")

(declare-binscript
  :main "jpm"
  :hardcode-syspath true
  :auto-shebang true
  :is-janet true)
