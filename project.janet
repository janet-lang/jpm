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
           "jpm/make-config.janet"
           "jpm/pm.janet"
           "jpm/rules.janet"
           "jpm/shutil.janet"
           "jpm/cgen.janet"])

(declare-manpage "jpm.1")

(declare-binscript
  :main "jpm/jpm"
  :hardcode-syspath true
  :is-janet true)

# Install the default configuration for bootstrapping
(def confpath (string (dyn :modpath) "/jpm/default-config.janet"))

(if-let [bc (os/getenv "JPM_BOOTSTRAP_CONFIG")]
  (install-file-rule bc confpath)

  # Otherwise, keep the current config or generate a new one
  (do
    (if (os/stat confpath :mode)

      # Generate new config
      (do
        (print "no existing config found, generating a default...")
        (def module (require (string (comptime (dyn :current-file)) "/jpm/make-config")))
        (def make-config/detect (-> module (get 'detect) :value))
        (task "install" []
            (spit confpath (make-config/detect))))

      # Keep old config
      (do
        (def old (slurp confpath))
        (task "install" []
              (print "keeping old config at " confpath)
              (spit confpath old))))))
