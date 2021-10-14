###
### Package management functionality
###

(use ./config)
(use ./shutil)
(use ./rules)

(defn- proto-flatten
  [into x]
  (when x
    (proto-flatten into (table/getproto x))
    (merge-into into x))
  into)

(def- mod-rules (require "./rules"))
(def- mod-shutil (require "./shutil"))
(def- mod-cc (require "./cc"))
(def- mod-cgen (require "./cgen"))
(def- mod-declare (require "./declare"))
(def- mod-make-config (require "./make-config"))
(def- mod-pm (curenv))

(defn make-jpm-env
  "Create an environment that is preloaded with jpm symbols."
  [&opt base-env]
  (def envs-to-add
    [mod-declare
     mod-shutil
     mod-rules
     mod-cc
     mod-cgen
     mod-pm
     mod-make-config
     (or base-env {})])
  (def env (make-env))
  (loop [e :in envs-to-add
         k :keys e :when (symbol? k)
         :let [x (get e k)]]
    (unless (get x :private)
      (put env k x)))
  (def currenv (proto-flatten @{} (curenv)))
  (loop [k :keys currenv :when (keyword? k)]
    (put env k (currenv k)))
  # For compatibility reasons
  (put env 'default-cflags @{:value (dyn:cflags)})
  (put env 'default-lflags @{:value (dyn:lflags)})
  (put env 'default-ldflags @{:value (dyn:ldflags)})
  (put env 'default-cppflags @{:value (dyn:cppflags)})
  (put env :syspath (dyn:modpath))
  env)

(defn require-jpm
  "Require a jpm file project file. This is different from a normal require
  in that code is loaded in the jpm environment."
  [path &opt no-deps base-env]
  (unless (os/stat path :mode)
    (error (string "cannot open " path)))
  (def env (make-jpm-env base-env))
  (dofile path :env env :exit true)
  env)

(defn import-rules
  "Import another file that defines more rules. This ruleset
  is merged into the current ruleset."
  [path &opt no-deps base-env]
  (def env (require-jpm path no-deps base-env))
  (when-let [rules (get env :rules)] (merge-into (getrules) rules))
  env)

(defn git
  "Make a call to git."
  [& args]
  (shell (dyn:gitpath) ;args))

(defn tar
  "Make a call to tar."
  [& args]
  (shell (dyn:tarpath) ;args))

(defn curl
  "Make a call to curl"
  [& args]
  (shell (dyn:curlpath) ;args))

(var- bundle-install-recursive nil)

(defn- resolve-bundle-name
  "Convert short bundle names to full tables."
  [bname]
  (if-not (string/find ":" bname)
    (let [pkgs (try
                 (require "pkgs")
                 ([err]
                   (bundle-install-recursive (dyn:pkglist))
                   (require "pkgs")))
          url (get-in pkgs ['packages :value (symbol bname)])]
      (unless url
        (error (string "bundle " bname " not found.")))
      url)
    bname))

(defn resolve-bundle
  "Convert any bundle string/table to the normalized table form."
  [bundle]
  (var repo nil)
  (var tag nil)
  (var btype :git)
  (if (dictionary? bundle)
    (do
      (set repo (or (get bundle :url) (get bundle :repo)))
      (set tag (or (get bundle :tag) (get bundle :sha) (get bundle :commit) (get bundle :ref)))
      (set btype (get bundle :type :git)))
    (let [parts (string/split "::" bundle)]
      (case (length parts)
        1 (set repo (get parts 0))
        2 (do (set repo (get parts 1)) (set btype (keyword (get parts 0))))
        3 (do
            (set btype (keyword (get parts 0)))
            (set repo (get parts 1))
            (set tag (get parts 2)))
        (errorf "unable to parse bundle string %v" bundle))))
  {:url (resolve-bundle-name repo) :tag tag :type btype})

(defn download-git-bundle
  "Download a git bundle from a remote respository"
  [bundle-dir url tag]
  (def gd (string "--git-dir=" bundle-dir "/.git"))
  (def wt "--work-tree=.")
  (var fresh false)
  (if (dyn :offline)
    (if (not= :directory (os/stat bundle-dir :mode))
      (error (string "did not find cached repository for dependency " url))
      (set fresh true))
    (when (os/mkdir bundle-dir)
      (set fresh true)
      (print "cloning repository " url " to " bundle-dir)
      (git "clone" url bundle-dir)))
  (unless (or (dyn :offline) fresh)
    (git "-C" bundle-dir gd wt "pull" "--ff-only"))
  (unless (dyn :offline)
    (git "-C" bundle-dir gd wt "submodule" "update" "--init" "--recursive")))

(defn download-tar-bundle
  "Download a dependency from a tape archive. The archive should have exactly one
  top level directory that contains the contents of the project."
  [bundle-dir url &opt force-gz]
  (def has-gz (string/has-suffix? "gz" url))
  (def is-remote (string/find ":" url))
  (def dest-archive (if is-remote (string bundle-dir "/bundle-archive." (if has-gz "tar.gz" "tar")) url))
  (os/mkdir bundle-dir)
  (when is-remote
    (curl "-sL" url "--output" dest-archive))
  (spit (string bundle-dir "/.bundle-tar-url") url)
  (def tar-flags (if has-gz "-xzf" "-xf"))
  (tar tar-flags dest-archive "--strip-components=1" "-C" bundle-dir))

(defn download-bundle
  "Donwload the package source (using git) to the local cache. Return the
  path to the downloaded or cached soure code."
  [url bundle-type &opt tag]
  (def cache (find-cache))
  (os/mkdir cache)
  (def id (filepath-replace (string bundle-type "_" tag "_" url)))
  (def bundle-dir (string cache "/" id))
  (case bundle-type
    :git (download-git-bundle bundle-dir url tag)
    :tar (download-tar-bundle bundle-dir url)
    (errorf "unknown bundle type %v" bundle-type))
  bundle-dir)

(defn bundle-install
  "Install a bundle from a git repository."
  [bundle &opt no-deps]
  (def {:url url
        :tag tag
        :type bundle-type}
   (resolve-bundle bundle))
  (def bdir (download-bundle url bundle-type tag))
  (def olddir (os/cwd))
  (defer (os/cd olddir)
    (os/cd bdir)
    (with-dyns [:rules @{}
                :bundle-type (or bundle-type :git)
                :modpath (abspath (dyn:modpath))
                :headerpath (abspath (dyn:headerpath))
                :libpath (abspath (dyn:libpath))
                :binpath (abspath (dyn:binpath))]
      (def dep-env (require-jpm "./project.janet" true))
      (unless no-deps
        (def meta (dep-env  :project))
        (if-let [deps (meta :dependencies)]
          (each dep deps
            (bundle-install dep))))
      (each r ["build" "install"]
        (build-rules (get dep-env :rules {}) [r])))))

(set bundle-install-recursive bundle-install)

(defn make-lockfile
  [&opt filename]
  (default filename "lockfile.jdn")
  (def cwd (os/cwd))
  (def packages @[])
  # Read installed modules from manifests
  (def mdir (find-manifest-dir))
  (each man (os/dir mdir)
    (def package (parse (slurp (string mdir "/"  man))))
    (if (and (dictionary? package) (or (package :url) (package :repo)) (package :tag))
      (array/push packages package)
      (print "Cannot add local or malformed package " mdir "/" man " to lockfile, skipping...")))
  # Put in correct order, such that a package is preceded by all of its dependencies
  (def ordered-packages @[])
  (def resolved @{})
  (while (< (length ordered-packages) (length packages))
    (var made-progress false)
    (each p packages
      (def {:url u :repo r :tag s :dependencies d :type t} p)
      (def key (in (resolve-bundle p) :url))
      (def dep-bundles (map |(in (resolve-bundle $) :url) d))
      (unless (resolved key)
        (when (all resolved dep-bundles)
          (array/push ordered-packages {:url (or u r) :tag s :type t})
          (set made-progress true)
          (put resolved key true))))
    (unless made-progress
      (error (string/format "could not resolve package order for: %j"
                            (filter (complement resolved) (map |(or ($ :url) ($ :repo)) packages))))))
  # Write to file, manual format for better diffs.
  (with [f (file/open filename :w)]
    (with-dyns [:out f]
      (prin "@[")
      (eachk i ordered-packages
        (unless (zero? i)
          (prin "\n  "))
        (prinf "%j" (ordered-packages i)))
      (print "]")))
  (print "created " filename))

(defn load-lockfile
  "Load packages from a lockfile."
  [&opt filename]
  (default filename "lockfile.jdn")
  (def lockarray (parse (slurp filename)))
  (each bundle lockarray
    (bundle-install bundle true)))

(defmacro post-deps
  "Run code at the top level if jpm dependencies are installed. Build
  code that imports dependencies should be wrapped with this macro, as project.janet
  needs to be able to run successfully even without dependencies installed."
  [& body]
  (unless (dyn :jpm-no-deps)
    ~',(reduce |(eval $1) nil body)))

(defn do-rule
  "Evaluate a given rule in a one-off manner."
  [target]
  (build-rules (dyn :rules) [target] (dyn :workers)))

