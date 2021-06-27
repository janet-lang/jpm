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
  "A table of all of the dynamic config bindings to parsers."
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
    :string parse-string
    :string-opt parse-string
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
    :string string?
    :string-opt string-or-nil?
    :string-array string-array?
    :boolean boolean-or-nil?})

(defmacro defdyn
  "Define a function that wraps (dyn :keyword). This will
  allow use of dynamic bindings with static runtime checks."
  [kw &opt parser docs & meta]
  (put config-parsers kw (get config-parser-types parser))
  (put config-checkers kw (get config-checker-types parser))
  (put config-docs kw docs)
  (put config-set kw parser)
  (let [s (symbol "dyn:" kw)]
    ~(defn ,s ,;meta [&opt dflt]
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
  (def output (buffer/format buf "%p" d))
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
    (def value (dyn k))
    (when (and checker (not (checker value)))
      (errorf "invalid configuration binding %v, expected %v, got %v" k ctype value))))

(defn load-config-file
  "Load a configuration from a file. If override is set, will override already set values.
  Otherwise will prefer the current value over the settings from the config file."
  [path &opt override]
  (def config-table
    (if (string/has-suffix? ".janet" path)
      (-> path dofile (get-in ['config :value]))
      (-> path slurp parse)))
  (load-config config-table override))

# All jpm settings.
(defdyn :binpath :string "The directory to install executable binaries and scripts to")
(defdyn :config-file :string-opt "A config file to load to load settings from")
(defdyn :gitpath :string "The path or command name of git used by jpm")
(defdyn :tarpath :string "The path or command name of tar used by jpm")
(defdyn :curlpath :string "The path or command name of curl used by jpm")
(defdyn :headerpath :string "Directory containing Janet headers")
(defdyn :janet :string "The path or command name of the Janet binary used when spawning janet subprocesses")
(defdyn :libpath :string
  "The directory that contains janet libraries for standalone binaries and other native artifacts")
(defdyn :modpath :string-opt "The directory tree to install packages to")
(defdyn :optimize :int "The default optimization level to use for C/C++ compilation if otherwise unspecified")
(defdyn :pkglist :string-opt "The package listing bundle to use for mapping short package names to full URLs.")
(defdyn :offline :boolean "Do not download remote repositories when installing packages")

# Settings that probably shouldn't be set from the command line.
(defdyn :ar :string "The archiver used to generate static C/C++ libraries")
(defdyn :c++ :string "The C++ compiler to use for natives")
(defdyn :c++-link :string "The C++ linker to use for natives - on posix, should be the same as the compiler")
(defdyn :cc :string "The C compiler to use for natives")
(defdyn :cc-link :string "The C linker to use for natives - on posix, should be the same as the compiler")
(defdyn :cflags :string-array "List of flags to pass when compiling .c files to object files")
(defdyn :cppflags :string-array "List of flags to pass when compiling .cpp files to object files")
(defdyn :cflags-verbose :string-array "List of extra flags to pass when compiling in verbose mode")
(defdyn :dynamic-cflags :string-array "List of flags to pass only when compiler shared objects")
(defdyn :dynamic-lflags :string-array "List of flags to pass when linking shared objects")
(defdyn :is-msvc :boolean "Switch to turn on if using MSVC compiler instead of POSIX compliant compiler")
(defdyn :msvc-vcvars-script :string-opt "Path to the vcvars[32/64/all].bat script to do compilation")
(defdyn :ldflags :string-array "Linker flags for OS libraries needed when compiling C/C++ artifacts")
(defdyn :lflags :string-array "Non-library linker flags when compiling C/C++ artifacts")
(defdyn :modext :string "File extension for shared objects")
(defdyn :statext :string "File extension for static libraries")
(defdyn :use-batch-shell :boolean "Switch to turn on if using the Batch shell on windows instead of POSIX shell")
(defdyn :janet-lflags :string-array "Link flags to pass when linking to libjanet")
(defdyn :janet-cflags :string-array "Compiler flags to pass when linking to libjanet")

# Settings that should probably only be set from the command line
(defdyn :auto-shebang :boolean "Automatically add a shebang line to installed janet scripts")
(defdyn :silent :boolean "Show less output than usually and silence output from subprocesses")
(defdyn :verbose :boolean "Show more ouput than usual and turn on warn flags in compilers")
(defdyn :workers :int-opt "The number of parallel workers to build with")
(defdyn :nocolor :boolean "Disables color in the debug repl")
