(declare-project
  :name "jpm"
  :description "JPM is the Janet Project Manager tool."
  :url "https://github.com/janet-lang/jpm"
  :version "1.2.1")

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
           "jpm/scaffold.janet"
           "jpm/cgen.janet"])

(declare-manpage "jpm.1")

(declare-binscript
  :main "jpm/jpm"
  :hardcode-syspath true
  :is-janet true)

# Install the default configuration for bootstrapping
(def confpath/old (string (dyn :modpath) "/jpm/default-config.janet"))
(def confpath/new (string (dyn :dest-dir) confpath/old))

(if-let [bc (os/getenv "JPM_BOOTSTRAP_CONFIG")]
  (install-file-rule bc confpath/old)

  # Otherwise, keep the current config or generate a new one
  (do
    (if (os/stat confpath/old :mode)

      # Keep old config
      (do
        (def old (slurp confpath/old))
        (task "install" []
              (print "keeping old config from " confpath/old)
              (spit confpath/new old)))

      # Generate new config
      (do
        (task "install" []
            (print "no existing config found, generating a default...")
            (spit confpath/new (generate-config))
            (print "created config file at " confpath/new))))))
