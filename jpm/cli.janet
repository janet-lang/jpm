###
### Command Line interface for jpm.
###

(use ./config)
(import ./commands)
(import ./default-config)

(def- argpeg
  (peg/compile
    '(+
      (* "--" '(some (if-not "=" 1)) (+ (* "=" '(any 1)) -1))
      (* '"-" (some '(range "az" "AZ"))))))

(defn setup
  ``Load configuration from the command line, environment variables, and
  configuration files. Returns array of non-configuration arguments as well.
  Config settings are prioritized as follows:
     1. Commmand line settings
     2. The value of `(dyn :jpm-config)`
     3. Environment variables
     4. Config file settings (default-config if non specified)
  ``
  [args]
  (read-env-variables)
  (load-options)
  (def cmdbuf @[])
  (var flags-done false)
  (each a args
    (cond
      (= a "--")
      (set flags-done true)

      flags-done
      (array/push cmdbuf a)

      (if-let [m (peg/match argpeg a)]
        (do
          (def key (keyword (get m 0)))
          (if (= key :-) # short args
            (for i 1 (length m)
              (setdyn (get shorthand-mapping (get m i)) true))
            (do
              # logn args
              (def value-parser (get config-parsers key))
              (unless value-parser
                (error (string "unknown cli option " key)))
              (if (= 2 (length m))
                (do
                  (def v (value-parser key (get m 1)))
                  (setdyn key v))
                (setdyn key true)))))
        (do
          (if (index-of a ["janet" "exec"]) (set flags-done true))
          (array/push cmdbuf a)))))

  # Load the configuration file, or use default config.
  (if-let [cd (dyn :jpm-config)]
    (load-config cd true)
    (if-let [cf (dyn :config-file (os/getenv "JANET_JPM_CONFIG"))]
      (load-config-file cf false)
      (load-config default-config/config false)))

  # Local development - if --local flag is used, do a local installation to a tree.
  # Same for --tree=
  (cond
    (dyn :local) (commands/enable-local-mode)
    (dyn :tree) (commands/set-tree (dyn :tree)))

  # Make sure loaded project files and rules execute correctly.
  (unless (dyn :janet)
    (setdyn :janet (dyn :executable)))
  (put root-env :syspath (dyn:modpath))

  # Update packages if -u flag given
  (if (dyn :update-pkgs)
    (commands/update-pkgs))

  cmdbuf)

(defn run
  "Run CLI commands."
  [& args]
  (def cmdbuf (setup args))
  (if (empty? cmdbuf)
    (commands/help)
    (if-let [com (get commands/subcommands (first cmdbuf))]
        (com ;(slice cmdbuf 1))
        (do
          (print "invalid command " (first cmdbuf))
          (commands/help)))))

(defn main
  "Script entry."
  [& argv]
  (run ;(tuple/slice argv 1)))
