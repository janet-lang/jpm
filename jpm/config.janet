###
### Various defaults that can be set at compile time
### and configure the behavior of the module.
###

(import ./default-config)

(defn opt
  "Get an option, allowing overrides via dynamic bindings AND some
  default value dflt if no dynamic binding is set."
  [opts key &opt dflt]
  (def ret (or (get opts key) (dyn key dflt)))
  (if (= nil ret)
    (error (string "option :" key " not set")))
  ret)

(var- builtins-loaded false)

(def config-parsers
  "A table of all of the dynamic config bindings to parsers."
  @{})

(def config-options
  "A table of possible options for enum option types."
  @{})

(def config-checkers
  "A table of all of the dynamic config bindings to checkers (validators)."
  @{})

(def config-docs
  "Table of all of the help text for each config option."
  @{})

(def config-set
  "Listing of all config dyns."
  @{})

(def builtin-configs
  "Table of all built-in options, as opposed to project deifned options."
  @{})

#
# Entry Parsers
#

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

(defn- parse-string-array
  [kw x]
  (string/split "," x))

(def- config-parser-types
  "A table of all of the option parsers."
  @{:int parse-integer
    :int-opt parse-integer
    :int? parse-integer
    :string parse-string
    :string-opt parse-string
    :string? parse-string
    :string-array parse-string-array
    :boolean parse-boolean})

#
# Entry Checkers
#

(defn- string-array?
  [x]
  (and (indexed? x)
       (all string? x)))

(defn- boolean-or-nil?
  [x]
  (or (nil? x) (boolean? x)))

(defn- string-or-nil?
  [x]
  (or (nil? x) (string? x)))

(defn- int-or-nil?
  [x]
  (or (nil? x) (int? x)))

(def- config-checker-types
  "A table of all of the option checkers"
  @{:int int?
    :int-opt int-or-nil?
    :int? int-or-nil?
    :string string?
    :string-opt string-or-nil?
    :string? string-or-nil?
    :string-array string-array?
    :boolean boolean-or-nil?})

(defmacro defconf
  "Define a function that wraps (dyn :keyword). This will
  allow use of dynamic bindings with static runtime checks."
  [kw &opt parser docs options]
  (put config-parsers kw (get config-parser-types parser))
  (put config-checkers kw (get config-checker-types parser))
  (put config-options kw options)
  (put config-docs kw docs)
  (put config-set kw parser)
  (unless builtins-loaded (put builtin-configs kw true))
  (let [s (symbol "dyn:" kw)]
    ~(defn ,s [&opt dflt]
       (def x (,dyn ,kw dflt))
       (if (= x nil)
         (,errorf "no value found for dynamic binding %v" ,kw)
         x))))

(defn save-config
  "Write the current configuration information to a file."
  [path]
  (def data @{})
  (eachk k config-set (put data k (dyn k)))
  (def d (table/to-struct data))
  (def buf @"")
  (buffer/format buf "%j" d) # ensure no funny stuff gets written to config file
  (buffer/clear buf)
  (def output (buffer/format buf "%.99m" d))
  (spit path output))

(defn load-config
  "Load a configuration from a table or struct."
  [settings &opt override]
  (assert (dictionary? settings) "expected config file to be a dictionary")
  (eachp [k v] settings
    (setdyn k (if override v (dyn k v))))
  # now check
  (eachk k config-set
    (def ctype (get config-set k))
    (def checker (get config-checkers k))
    (def options (get config-options k))
    (def value (dyn k))
    (when (and options (not (index-of value options)))
      (when (not= nil value)
        (errorf "invalid configuration option %v, expected one of %j, got %v" k options value)))
    (when (and checker (not (checker value)))
      (errorf "invalid configuration option %v, expected %v, got %v" k ctype value)))
  # Final patches
  (unless (dyn :modpath)
    (setdyn :modpath (dyn :syspath)))
  nil)

(defn load-config-file
  "Load a configuration from a file. If override is set, will override already set values.
  Otherwise will prefer the current value over the settings from the config file."
  [path &opt override]
  (def config-table
    (if (string/has-suffix? ".janet" path)
      (-> path dofile (get-in ['config :value]))
      (-> path slurp parse)))
  (load-config config-table override))

(defn load-default
  "Load the default configuration."
  [&opt override]
  (load-config default-config/config override))

(def- mod-config (curenv))

(defn load-options
  "Load a file that contains config options that can be set. If no such
  file exists, then do nothing."
  [&opt path]
  (default path "./options.janet")
  (unless (os/stat path :mode)
    (break))
  (def env (make-env))
  (loop [k :keys mod-config :when (symbol? k)
         :let [x (get mod-config k)]]
    (unless (get x :private)
      (put env k x)))
  (dofile path :env env)
  # inherit dyns
  (loop [k :keys env :when (keyword? k)]
    (setdyn k (get env k)))
  nil)

(defn- setwhen [k envvar]
  (when-let [v (os/getenv envvar)]
    (setdyn k v)))

(defn read-env-variables
  "Read environment variables that correspond to config variables into dyns."
  []
  (setwhen :gitpath "JANET_GIT")
  (setwhen :tarpath "JANET_TAR")
  (setwhen :curlpath "JANET_CURL")
  (setwhen :pkglist "JANET_PKGLIST")
  (setwhen :modpath "JANET_MODPATH")
  (setwhen :headerpath "JANET_HEADERPATH")
  (setwhen :libpath "JANET_LIBPATH")
  (setwhen :binpath "JANET_BINPATH")
  (setwhen :buildpath "JANET_BUILDPATH"))

(def shorthand-mapping
  "Map some single characters to long options."
  {"v" :verbose
   "l" :local
   "s" :silent
   "n" :nocolor
   "u" :update-pkgs
   "t" :test})

# All jpm settings.
(defconf :binpath :string "The directory to install executable binaries and scripts to")
(defconf :config-file :string-opt "A config file to load to load settings from")
(defconf :gitpath :string "The path or command name of git used by jpm")
(defconf :tarpath :string "The path or command name of tar used by jpm")
(defconf :curlpath :string "The path or command name of curl used by jpm")
(defconf :headerpath :string "Directory containing Janet headers")
(defconf :manpath :string-opt "Directory to install man pages to")
(defconf :janet :string "The path or command name of the Janet binary used when spawning janet subprocesses")
(defconf :libpath :string
  "The directory that contains janet libraries for standalone binaries and other native artifacts")
(defconf :modpath :string-opt "The directory tree to install packages to")
(defconf :optimize :int-opt "The default optimization level to use for C/C++ compilation if otherwise unspecified" [0 1 2 3])
(defconf :pkglist :string-opt "The package listing bundle to use for mapping short package names to full URLs.")
(defconf :offline :boolean "Do not download remote repositories when installing packages")
(defconf :update-pkgs :boolean "Update package listing before doing anything.")
(defconf :buildpath :string-opt "The path to output intermediate files and build outputs to. Default is build/")

# Settings that probably shouldn't be set from the command line.
(defconf :ar :string "The archiver used to generate static C/C++ libraries")
(defconf :c++ :string "The C++ compiler to use for natives")
(defconf :c++-link :string "The C++ linker to use for natives - on posix, should be the same as the compiler")
(defconf :cc :string "The C compiler to use for natives")
(defconf :cc-link :string "The C linker to use for natives - on posix, should be the same as the compiler")
(defconf :cflags :string-array "List of flags to pass when compiling .c files to object files")
(defconf :cppflags :string-array "List of flags to pass when compiling .cpp files to object files")
(defconf :cflags-verbose :string-array "List of extra flags to pass when compiling in verbose mode")
(defconf :dynamic-cflags :string-array "List of flags to pass only when compiler shared objects")
(defconf :dynamic-lflags :string-array "List of flags to pass when linking shared objects")
(defconf :is-msvc :boolean "Switch to turn on if using MSVC compiler instead of POSIX compliant compiler")
(defconf :ldflags :string-array "Linker flags for OS libraries needed when compiling C/C++ artifacts")
(defconf :lflags :string-array "Non-library linker flags when compiling C/C++ artifacts")
(defconf :modext :string "File extension for shared objects")
(defconf :statext :string "File extension for static libraries")
(defconf :use-batch-shell :boolean "Switch to turn on if using the Batch shell on windows instead of POSIX shell")
(defconf :janet-lflags :string-array "Link flags to pass when linking to libjanet")
(defconf :janet-cflags :string-array "Compiler flags to pass when linking to libjanet")

# Settings that should probably only be set from the command line
(defconf :auto-shebang :boolean "Automatically add a shebang line to installed janet scripts")
(defconf :silent :boolean "Show less output than usually and silence output from subprocesses")
(defconf :verbose :boolean "Show more ouput than usual and turn on warn flags in compilers")
(defconf :workers :int-opt "The number of parallel workers to build with")
(defconf :nocolor :boolean "Disables color in the debug repl")
(defconf :test :boolean "Enable testing when installing.")
(defconf :local :boolean "Switch to use a local tree ./jpm_tree instead of the config specified tree.")
(defconf :tree :string-opt "Switch to use a custom tree instead of the config specified tree.")
(defconf :dest-dir :string-opt "Prefix to add to installed files. Useful for bootstrapping.")
(defconf :build-type :string-opt "A preset of options for debug, release, and develop builds." ["release" "debug" "develop"])

(set builtins-loaded true)
