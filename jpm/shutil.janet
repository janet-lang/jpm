###
### Utilties for running shell-like commands
###

(use ./config)

(defn is-win
  "Check if we should assume a DOS-like shell or default
  to posix shell."
  []
  (dyn :use-batch-shell))

(defn find-manifest-dir
  "Get the path to the directory containing manifests for installed
  packages."
  []
  (string (dyn :dest-dir "") (dyn:modpath) "/.manifests"))

(defn find-manifest
  "Get the full path of a manifest file given a package name."
  [name]
  (string (find-manifest-dir) "/" name ".jdn"))

(defn find-cache
  "Return the path to the global cache."
  []
  (def path (dyn:modpath))
  (string (dyn :dest-dir "") path "/.cache"))

(defn rm
  "Remove a directory and all sub directories."
  [path]
  (case (os/lstat path :mode)
    :directory (do
      (each subpath (os/dir path)
        (rm (string path "/" subpath)))
      (os/rmdir path))
    nil nil # do nothing if file does not exist
    # Default, try to remove
    (os/rm path)))

(defn rimraf
  "Hard delete directory tree"
  [path]
  (if (is-win)
    # windows get rid of read-only files
    (when (os/stat path :mode)
      (os/shell (string `rmdir /S /Q "` path `"`)))
    (rm path)))

(defn clear-cache
  "Clear the global git cache."
  []
  (def cache (find-cache))
  (print "clearing cache " cache "...")
  (rimraf cache))

(defn clear-manifest
  "Clear the global installation manifest."
  []
  (def manifest (find-manifest-dir))
  (print "clearing manifests " manifest "...")
  (rimraf manifest))

(def path-splitter
  "split paths on / and \\."
  (peg/compile ~(any (* '(any (if-not (set `\/`) 1)) (+ (set `\/`) -1)))))

(defn create-dirs
  "Create all directories needed for a file (mkdir -p)."
  [dest]
  (def segs (peg/match path-splitter dest))
  (def i1 (if (and (is-win) (string/has-suffix? ":" (first segs))) 2 1))
  (for i i1 (length segs)
    (def path (string/join (slice segs 0 i) "/"))
    (unless (empty? path) (os/mkdir path))))

(defn devnull
  []
  (os/open (if (= :windows (os/which)) "NUL" "/dev/null") :rw))

(defn- patch-path
  "Add the bin-path to the regular path"
  [path]
  (if-let [bp (dyn:binpath)]
    (string bp (if (= :windows (os/which)) ";" ":") path)
    path))

(defn- patch-env
  []
  (def environ (os/environ))
  # Windows uses "Path"
  (def PATH (if (in environ "Path") "Path" "PATH"))
  (def env (merge-into environ {"JANET_PATH" (dyn:modpath)
                                PATH (patch-path (os/getenv PATH))})))

(defn shell
  "Do a shell command"
  [& args]
  # First argument is executable and must not contain spaces, workaround
  # for binaries which have spaces such as `zig cc`.
  # TODO - remove?
  (def args (tuple ;(string/split " " (args 0)) ;(map string (slice args 1))))
  (when (dyn :verbose)
    (flush)
    (print ;(interpose " " args)))
  (def env (patch-env))
  (if (dyn :silent)
    (with [dn (devnull)]
      (put env :out dn)
      (put env :err dn)
      (os/execute args :epx env))
    (os/execute args :epx env)))

(defn exec-slurp
  "Read stdout of subprocess and return it trimmed in a string."
  [& args]
  (when (dyn :verbose)
    (flush)
    (print ;(interpose " " args)))
  (def env (patch-env))
  (put env :out :pipe)
  (def proc (os/spawn args :epx env))
  (def out (get proc :out))
  (def buf @"")
  (ev/gather
    (:read out :all buf)
    (:wait proc))
  (string/trimr buf))

(defn drop1-shell
  "Variant of `shell` to play nice with cl.exe, which outputs some junk to terminal that can't be turned off."
  [std args]
  (if (dyn :silent) (break (shell ;args)))
  (when (dyn :verbose)
    (flush)
    (print ;(interpose " " args)))
  (def env (patch-env))
  (put env std :pipe)
  (def proc (os/spawn args :ep env))
  (def out (get proc std))
  (def buf @"")
  (var index nil)
  (ev/gather
    (do
      (:read out :all buf)
      (set index (string/find "\n" buf)))
    (:wait proc))
  (def rc (proc :return-code))
  (if (and (zero? rc) index)
    (prin (buffer/slice buf (inc index)))
    (prin buf))
  (unless (zero? rc)
    (errorf "command failed with non-zero exit code %d" rc))
  0)

(defn clexe-shell [& args] (drop1-shell :out args))

(defn copy
  "Copy a file or directory recursively from one location to another."
  [src dest]
  (print "copying " src " to " dest "...")
  (if (is-win)
    (let [end (last (peg/match path-splitter src))
          isdir (= (os/stat src :mode) :directory)]
      (shell "C:\\Windows\\System32\\xcopy.exe"
             (string/replace-all "/" "\\" src)
             (string/replace-all "/" "\\" (if isdir (string dest "\\" end) dest))
             "/y" "/s" "/e" "/i"))
    (shell "cp" "-rf" src dest)))

(defn copyfile
  "Copy a file one location to another."
  [src dest]
  (print "copying file " src " to " dest "...")
  (->> src slurp (spit dest)))

(defn abspath
  "Create an absolute path. Does not resolve . and .. (useful for
  generating entries in install manifest file)."
  [path]
  (if (if (is-win)
        (peg/match '(+ "\\" (* (range "AZ" "az") ":\\")) path)
        (string/has-prefix? "/" path))
    path
    (string (os/cwd) "/" path)))

(def- filepath-replacer
  "Convert url with potential bad characters into a file path element."
  (peg/compile ~(% (any (+ (/ '(set "<>:\"/\\|?*") "_") '1)))))

(defn filepath-replace
  "Remove special characters from a string or path
  to make it into a path segment."
  [repo]
  (get (peg/match filepath-replacer repo) 0))
