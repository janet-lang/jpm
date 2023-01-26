###
### Rule generation for adding native source code
###

(use ./config)
(use ./rules)
(use ./shutil)
(use ./cc)

(defn- check-release
  []
  (= "release" (dyn:build-type "release")))

(defn install-rule
  "Add install and uninstall rule for moving files from src into destdir."
  [src destdir]
  (unless (check-release) (break))
  (def name (last (peg/match path-splitter src)))
  (def path (string destdir "/" name))
  (array/push (dyn :installed-files) path)
  (def dir (string (dyn :dest-dir "") destdir))
  (task "install" []
        (os/mkdir dir)
        (copy src dir)))

(defn install-file-rule
  "Add install and uninstall rule for moving file from src into destdir."
  [src dest]
  (unless (check-release) (break))
  (array/push (dyn :installed-files) dest)
  (def dest1 (string (dyn :dest-dir "") dest))
  (task "install" []
        (copyfile src dest1)))

(defn uninstall
  "Uninstall bundle named name"
  [name]
  (def manifest (find-manifest name))
  (when-with [f (file/open manifest)]
    (def man (parse (:read f :all)))
    (each path (get man :paths [])
      (def path1 (string (dyn :dest-dir "") path))
      (print "removing " path1)
      (rm path1))
    (print "removing manifest " manifest)
    (:close f) # I hate windows
    (rm manifest)
    (print "Uninstalled.")))

(defn declare-native
  "Declare a native module. This is a shared library that can be loaded
  dynamically by a janet runtime. This also builds a static libary that
  can be used to bundle janet code and native into a single executable."
  [&keys opts]
  (def sources (opts :source))
  (def name (opts :name))
  (def path (string (dyn:modpath) "/" (dirname name)))
  (def declare-targets @{})

  (def modext (dyn:modext))
  (def statext (dyn:statext))

  # Make dynamic module
  (def lname (string (find-build-dir) name modext))

  # Get objects to build with
  (var has-cpp false)
  (def objects
    (seq [src :in sources]
      (def suffix
        (cond
          (string/has-suffix? ".cpp" src) ".cpp"
          (string/has-suffix? ".cc" src) ".cc"
          (string/has-suffix? ".c" src) ".c"
          (errorf "unknown source file type: %s, expected .c, .cc, or .cpp" src)))
      (def op (out-path src suffix ".o"))
      (if (= suffix ".c")
        (compile-c :cc opts src op)
        (do (compile-c :c++ opts src op)
          (set has-cpp true)))
      op))
  
  (array/concat objects (get opts :objects []))

  (when-let [embedded (opts :embedded)]
    (loop [src :in embedded]
      (def c-src (out-path src ".janet" ".janet.c"))
      (def o-src (out-path src ".janet" ".janet.o"))
      (array/push objects o-src)
      (create-buffer-c src c-src (embed-name src))
      (compile-c :cc opts c-src o-src)))
  (link-c has-cpp opts lname ;objects)
  (put declare-targets :native lname)
  (add-dep "build" lname)
  (install-rule lname path)

  # Add meta file
  (def metaname (modpath-to-meta lname))
  (def ename (entry-name name))
  (rule metaname []
        (print "generating meta file " metaname "...")
        (flush)
        (os/mkdir (find-build-dir))
        (create-dirs metaname)
        (spit metaname (string/format
                         "# Metadata for static library %s\n\n%.20p"
                         (string name statext)
                         {:static-entry ename
                          :cpp has-cpp
                          :ldflags ~',(opts :ldflags)
                          :lflags ~',(opts :lflags)})))
  (add-dep "build" metaname)
  (put declare-targets :meta metaname)
  (install-rule metaname path)

  # Make static module
  (unless (dyn :nostatic)
    (def sname (string (find-build-dir) name statext))
    (def opts (merge @{:entry-name ename} opts))
    (def sobjext ".static.o")
    (def sjobjext ".janet.static.o")

    # Get static objects
    (def sobjects
      (seq [src :in sources]
        (def suffix
          (cond
            (string/has-suffix? ".cpp" src) ".cpp"
            (string/has-suffix? ".cc" src) ".cc"
            (string/has-suffix? ".c" src) ".c"
            (errorf "unknown source file type: %s, expected .c, .cc, or .cpp" src)))
        (def op (out-path src suffix sobjext))
        (compile-c (if (= ".c" suffix) :cc :c++) opts src op true)
        # Add artificial dep between static object and non-static object - prevents double errors
        # when doing default builds.
        (add-dep op (out-path src suffix ".o"))
        op))

    (when-let [embedded (opts :embedded)]
      (loop [src :in embedded]
        (def c-src (out-path src ".janet" ".janet.c"))
        (def o-src (out-path src ".janet" sjobjext))
        (array/push sobjects o-src)
        # Buffer c-src is already declared by dynamic module
        (compile-c :cc opts c-src o-src true)))

    (archive-c opts sname ;sobjects)
    (when (check-release)
      (add-dep "build" sname))
    (put declare-targets :static sname)
    (install-rule sname path))

  declare-targets)

(defn declare-source
  "Create Janet modules. This does not actually build the module(s),
  but registers them for packaging and installation. :source should be an
  array of files and directores to copy into JANET_MODPATH or JANET_PATH.
  :prefix can optionally be given to modify the destination path to be
  (string JANET_PATH prefix source)."
  [&keys {:source sources :prefix prefix}]
  (def path (string (dyn:modpath) (if prefix "/") prefix))
  (if (bytes? sources)
    (install-rule sources path)
    (each s sources
      (install-rule s path))))

(defn declare-headers
  "Declare headers for a library installation. Installed headers can be used by other native
  libraries."
  [&keys {:headers headers :prefix prefix}]
  (def path (string (dyn:modpath) "/" (or prefix "")))
  (if (bytes? headers)
    (install-rule headers path)
    (each h headers
      (install-rule h path))))

(defn declare-bin
  "Declare a generic file to be installed as an executable."
  [&keys {:main main}]
  (install-rule main (dyn:binpath)))

(defn declare-executable
  "Declare a janet file to be the entry of a standalone executable program. The entry
  file is evaluated and a main function is looked for in the entry file. This function
  is marshalled into bytecode which is then embedded in a final executable for distribution.\n\n
  This executable can be installed as well to the --binpath given."
  [&keys {:install install :name name :entry entry :headers headers
          :cflags cflags :lflags lflags :deps deps :ldflags ldflags
          :no-compile no-compile :no-core no-core}]
  (def name (if (is-win-or-mingw) (string name ".exe") name))
  (def dest (string (find-build-dir) name))
  (create-executable @{:cflags cflags :lflags lflags :ldflags ldflags :no-compile no-compile} entry dest no-core)
  (if no-compile
    (let [cdest (string dest ".c")]
      (add-dep "build" cdest))
    (do
      (add-dep "build" dest)
      (when headers
        (each h headers (add-dep dest h)))
      (when deps
        (each d deps (add-dep dest d)))
      (when install
        (install-rule dest (dyn:binpath))))))

(defn declare-binscript
  ``Declare a janet file to be installed as an executable script. Creates
  a shim on windows. If hardcode is true, will insert code into the script
  such that it will run correctly even when JANET_PATH is changed. if auto-shebang
  is truthy, will also automatically insert a correct shebang line.
  ``
  [&keys {:main main :hardcode-syspath hardcode :is-janet is-janet}]
  (def binpath (dyn:binpath))
  (def auto-shebang (and is-janet (dyn:auto-shebang)))
  (if (or auto-shebang hardcode)
    (let [syspath (dyn:modpath)]
      (def parts (peg/match path-splitter main))
      (def name (last parts))
      (def path (string binpath "/" name))
      (array/push (dyn :installed-files) path)
      (task "install" []
            (def contents
              (with [f (file/open main :rbn)]
                (def first-line (:read f :line))
                (def second-line (string/format "(put root-env :syspath %v)\n" syspath))
                (def rest (:read f :all))
                (string (if auto-shebang
                          (string "#!" (dyn:binpath) "/janet\n"))
                        first-line (if hardcode second-line) rest)))
            (def destpath (string (dyn :dest-dir "") path))
            (create-dirs destpath)
            (print "installing " main " to " destpath)
            (spit destpath contents)
            (unless (is-win-or-mingw) (shell "chmod" "+x" destpath))))
    (install-rule main binpath))
  # Create a dud batch file when on windows.
  (when (is-win-or-mingw)
    (def name (last (peg/match path-splitter main)))
    (def fullname (string binpath "/" name))
    (def bat (string "@echo off\r\ngoto #_undefined_# 2>NUL || title %COMSPEC% & janet \"" fullname "\" %*"))
    (def newname (string binpath "/" name ".bat"))
    (array/push (dyn :installed-files) newname)
    (task "install" []
          (spit (string (dyn :dest-dir "") newname) bat))))

(defn declare-archive
  "Build a janet archive. This is a file that bundles together many janet
  scripts into a janet image. This file can the be moved to any machine with
  a janet vm and the required dependencies and run there."
  [&keys opts]
  (def entry (opts :entry))
  (def name (opts :name))
  (def iname (string (find-build-dir) name ".jimage"))
  (rule iname (or (opts :deps) [])
        (create-dirs iname)
        (spit iname (make-image (require entry))))
  (def path (dyn:modpath))
  (add-dep "build" iname)
  (install-rule iname path))

(defn declare-manpage
  "Mark a manpage for installation"
  [page]
  (when-let [mp (dyn :manpath)]
    (install-rule page mp)))

(defn- make-monkeypatch
  [build-dir]
  (string/format
    `(defn- check-is-dep [x] (unless (or (string/has-prefix? "/" x) (string/has-prefix? "." x)) x))
    (array/push module/paths [%v :native check-is-dep])`
    (string build-dir ":all:" (dyn:modext))))

(defn run-repl
  "Run a repl that has the same environment as the test environment."
  []
  (def bd (find-build-dir))
  (def monkey-patch (make-monkeypatch bd))
  (def environ (merge-into (os/environ) {"JANET_PATH" (dyn:modpath)}))
  (os/execute
    [(dyn:janet) "-r" "-e" monkey-patch]
    :ep
    environ))

(defn run-script
  "Run a local script in the monkey patched environment."
  [path]
  (def bd (find-build-dir))
  (def monkey-patch (make-monkeypatch bd))
  (def environ (merge-into (os/environ) {"JANET_PATH" (dyn:modpath)}))
  (os/execute
    [(dyn:janet) "-e" monkey-patch "--" path]
    :ep
    environ))

(defn run-tests
  "Run tests on a project in the current directory. The tests will
  be run in the environment dictated by (dyn :modpath)."
  [&opt root-directory build-directory]
  (def bd (or build-directory (find-build-dir)))
  (def monkey-patch (make-monkeypatch bd))
  (def environ (merge-into (os/environ) {"JANET_PATH" (dyn:modpath)}))
  (var errors-found 0)
  (defn dodir
    [dir bdir]
    (each sub (sort (os/dir dir))
      (def ndir (string dir "/" sub))
      (case (os/stat ndir :mode)
        :file (when (string/has-suffix? ".janet" ndir)
                (print "running " ndir " ...")
                (flush)
                (def result (os/execute
                              [(dyn:janet) "-e" monkey-patch ndir]
                              :ep
                              environ))
                (when (not= 0 result)
                  (++ errors-found)
                  (eprintf "non-zero exit code in %s: %d" ndir result)))
        :directory (dodir ndir bdir))))
  (dodir (or root-directory "test") bd)
  (if (zero? errors-found)
    (print "All tests passed.")
    (do
      (printf "Failing test scripts: %d" errors-found)
      (os/exit 1)))
  (flush))

(defn declare-project
  "Define your project metadata. This should
  be the first declaration in a project.janet file.
  Also sets up basic task targets like clean, build, test, etc."
  [&keys meta]
  (setdyn :project (struct/to-table meta))

  (def installed-files @[])
  (def manifests (find-manifest-dir))
  (def manifest (find-manifest (meta :name)))
  (setdyn :manifest manifest)
  (setdyn :manifest-dir manifests)
  (setdyn :installed-files installed-files)

  (task "build" [])

  (unless (check-release)
    (task "install" []
      (print "The install target is only enabled for release builds.")
      (os/exit 1)))

  (when (check-release)

    (task "manifest" [manifest])
    (rule manifest ["uninstall"]
          (print "generating " manifest "...")
          (flush)
          (os/mkdir manifests)
          (def has-git (os/stat ".git" :mode))
          (def bundle-type (dyn :bundle-type (if has-git :git :local)))
          (def man
            @{:dependencies (array/slice (get meta :dependencies []))
              :version (get meta :version "0.0.0")
              :paths installed-files
              :type bundle-type})
          (case bundle-type
            :git
            (do
              (if-let [shallow (dyn :shallow)]
                (put man :shallow shallow))
              (protect
                (if-let [x (exec-slurp (dyn:gitpath) "remote" "get-url" "origin")]
                  (put man :url (if-not (empty? x) x))))
              (protect
                (if-let [x (exec-slurp (dyn:gitpath) "rev-parse" "HEAD")]
                  (put man :tag (if-not (empty? x) x)))))
            :tar
            (do
              (put man :url (slurp ".bundle-tar-url")))
            :local nil
            (errorf "unknown bundle type %v" bundle-type))
          (spit manifest (string/format "%j\n" (table/to-struct man))))

    (task "install" ["uninstall" "build" manifest]
          (when (dyn :test)
            (run-tests))
          (print "Installed as '" (meta :name) "'.")
          (flush))

    (task "uninstall" []
          (uninstall (meta :name))))

  (task "clean" []
        # cut off trailing path separator (needed in msys2)
        (def bd (string/slice (find-build-dir) 0 -2))
        (when (os/stat bd :mode)
          (rm bd)
          (print "Deleted build directory " bd)
          (flush)))

  (task "test" ["build"]
         (run-tests)))
