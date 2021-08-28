(declare-project
  :version "0.0.1"
  :name "jpm")

(declare-source
  :prefix "jpm"
  :source ["jpm/cc.janet"
           "jpm/cli.janet"
           "jpm/commands.janet"
           "jpm/config.janet"
           "jpm/dagbuild.janet"
           "jpm/declare.janet"
           "jpm/init.janet"
           "jpm/pm.janet"
           "jpm/rules.janet"
           "jpm/shutil.janet"
           "jpm/cgen.janet"])

# Install the default configuration for bootstrapping
(def confpath (string (dyn :modpath) "/jpm/default-config.janet"))
(if-let [bc (os/getenv "JPM_BOOTSTRAP_CONFIG")]
  (install-file-rule bc confpath)
  # Otherwise, keep the current config
  (do
    (assert (os/stat confpath :mode)
            "No existing config found, use the jpm bootstrap script to generate a config and install")
    (def old (slurp confpath))
    (task "install" []
      (print "keeping old config at " confpath)
      (spit confpath old))))

(declare-manpage "jpm.1")

(declare-binscript
  :main "jpm/jpm"
  :hardcode-syspath true
  :is-janet true)
