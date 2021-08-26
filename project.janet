(declare-project
  :name "jpm")

(declare-source
  :prefix "jpm"
  :source ["jpm/cc.janet"
           "jpm/cli.janet"
           "jpm/commands.janet"
           "jpm/config.janet"
           "jpm/dagbuild.janet"
           "jpm/declare.janet"
           "jpm/pm.janet"
           "jpm/rules.janet"
           "jpm/shutil.janet"
           "jpm/cgen.janet"])

# Install the default configuration for bootstrapping
(when-let [bc (dyn :bootstrap-config "jpm/default-config.janet")]
  (install-file-rule bc (string (dyn :modpath) "/jpm/default-config.janet")))

(declare-manpage "jpm.1")

(declare-binscript
  :main "jpm/jpm"
  :hardcode-syspath true
  :auto-shebang true
  :is-janet true)
