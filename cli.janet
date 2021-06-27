###
### Command Line interface for jpm.
###

(use ./config)
(import ./commands)
(import ./default-config)

# Import some submodules to create a jpm env.
(import ./declare :prefix "" :export true)
(import ./rules :prefix "" :export true)
(import ./shutil :prefix "" :export true)
(import ./cc :prefix "" :export true)
(import ./pm :prefix "" :export true)

(def- _env (curenv))

(def- argpeg
  (peg/compile
    '(* "--" '(some (if-not "=" 1)) (+ (* "=" '(any 1)) -1))))

(defn- setwhen [k envvar]
  (when-let [v (os/getenv envvar)]
    (setdyn k v)))

(defn setup
  ``Load configuration from the command line, environment variables, and
  configuration files. Returns array of non-configuration arguments as well.
  Config settings are prioritized as follows:
     1. Commmand line settings
     2. Environment variables
     3. Config file settings (default-config if non specified)
  ``
  [args]
  (setwhen :gitpath "JANET_GIT")
  (setwhen :pkglist "JANET_PKGLIST")
  (setwhen :modpath "JANET_MODPATH")
  (setwhen :headerpath "JANET_HEADERPATH")
  (setwhen :libpath "JANET_LIBPATH")
  (setwhen :binpath "JANET_BINPATH")
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
          (def value-parser (get config-parsers key))
          (unless value-parser
            (error (string "unknown cli option " key)))
          (if (= 2 (length m))
            (do
              (def v (value-parser key (get m 1)))
              (setdyn key v))
            (setdyn key true)))
        (array/push cmdbuf a))))
  # Load the configuration file, or use default config.
  (if-let [cf (dyn :config-file (os/getenv "JANET_JPM_CONFIG"))]
    (load-config-file cf false)
    (load-config default-config/config false))

  # Make configuration a bit easier - modpath is optional and falls back to syspath
  (if (= nil (dyn :modpath)) (setdyn :modpath (dyn :syspath)))

  (setdyn :jpm-env _env)
  (setdyn :janet (dyn :executable))
  cmdbuf)

(defn main
  "Script entry."
  [& argv]
  (def args (tuple/slice argv 1))
  (def cmdbuf (setup args))
  (if (empty? cmdbuf)
    (commands/help)
    (if-let [com (get commands/subcommands (first cmdbuf))]
        (com ;(slice cmdbuf 1))
        (do
          (print "invalid command " (first cmdbuf))
          (commands/help)))))
