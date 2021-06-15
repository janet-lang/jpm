###
### Various defaults that can be set at compile time
### and configure the behavior of the module.
###

(defn opt
  "Get an option, allowing overrides via dynamic bindings AND some
  default value dflt if no dynamic binding is set."
  [opts key &opt dflt]
  (def ret (or (get opts key) (dyn key dflt)))
  (if (= nil ret)
    (error (string "option :" key " not set")))
  ret)

(def config-parsers 
  "A table of all of the dynamic config bindings."
  @{})

(def config-docs
  "Table of all of the help text for each config option."
  @{})

(defn- parse-boolean
  [kw x]
  (case (string/ascii-lower x)
    "f" false
    "0" false
    "false" false
    "off" false
    "no" false
    "t" true
    "1" true
    "on" true
    "yes" true
    "true" true
    (errorf "option :%s, unknown boolean option %s" kw x)))

(defn- parse-integer
  [kw x]
  (if-let [n (scan-number x)]
    (if (not= n (math/floor n))
      (errorf "option :%s, expected integer, got %v" kw x)
      n)
    (errorf "option :%s, expected integer, got %v" kw x)))

(defn- parse-string
  [kw x]
  x)

(def- config-parser-types
  "A table of all of the option parsers."
  @{:int parse-integer
    :string parse-string
    :boolean parse-boolean})

(defmacro defdyn
  "Define a function that wraps (dyn :keyword). This will
  allow use of dynamic bindings with static runtime checks."
  [kw &opt parser docs & meta]
  (put config-parsers kw (get config-parser-types parser))
  (put config-docs kw docs)
  (let [s (symbol "dyn:" kw)]
    ~(defn ,s ,;meta [&opt dflt]
       (def x (,dyn ,kw dflt))
       (if (= x nil)
         (,errorf "no value found for dynamic binding %v" ,kw)
         x))))

# All jpm settings.
(defdyn :binpath :string "The directory to install executable binaries and scripts to")
(defdyn :config-file :string "A config file to load to load settings from")
(defdyn :gitpath :string "The path or command name of git used by jpm")
(defdyn :headerpath :string "Directory containing Janet headers")
(defdyn :janet :string "The path or command name of the Janet binary used when spawning janet subprocesses")
(defdyn :libpath :string
  "The directory that contains janet libraries for standalone binaries and other native artifacts")
(defdyn :modpath :string "The directory tree to install packages to")
(defdyn :optimize :int "The default optimization level to use for C/C++ compilation if otherwise unspecified")
(defdyn :pkglist :string "The package listing bundle to use for mapping short package names to full URLs.")
(defdyn :offline :boolean "Do not download remote repositories when installing packages")

# Settings that probably shouldn't be set from the command line.
(defdyn :ar :string)
(defdyn :c++ :string)
(defdyn :c++-link :string)
(defdyn :cc :string)
(defdyn :cc-link :string)
(defdyn :cflags nil)
(defdyn :cppflags nil)
(defdyn :dynamic-cflags nil)
(defdyn :dynamic-lflags nil)
(defdyn :is-msvc :boolean)
(defdyn :ldflags nil)
(defdyn :lflags nil)
(defdyn :modext nil)
(defdyn :statext nil)
(defdyn :syspath nil)
(defdyn :use-batch-shell :boolean)
(defdyn :libjanet :string)

# Settings that should probably only be set from the command line
(defdyn :auto-shebang :boolean)
(defdyn :silent :boolean "Show less output than usually and silence output from subprocesses")
(defdyn :verbose :boolean "Show more ouput than usual and turn on warn flags in compilers")
(defdyn :workers :int "The number of parallel workers to build with")
(defdyn :nocolor :boolean "Disables color in the debug repl")
