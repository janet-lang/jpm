###
### Generation of jpm config files based on autodetection.
###

(import ./shutil)

(defn generate-config
  "Make a pretty good configuration file for the current target. Returns a buffer with config source contents.
  If `destdir` is given, will generate the folders needed to create a jpm tree."
  [&opt destdir silent as-data]

  (def hostos (os/which))
  (def iswin (= :windows hostos))
  (def ismingw (= :mingw hostos))
  (def win-prefix (os/getenv "JANET_WINDOWS_PREFIX"))

  # Msys2 can do some strange things to paths. Using /usr/local directly may _appear_ to work,
  # but there is some functionality to rewrite paths like /usr/local/bin/jpm to C:\\msys64\\usr\\local\\bin\\jpm
  # in some places, where in others it will be converted to D:\\usr\\local\\bin\\jpm
  (def prefix-guess
    (let [de (dyn :executable)
          suffix-win "\\bin\\janet.exe"
          suffix-posix "/bin/janet"]
      (cond
        (string/has-suffix? suffix-win de) (string/replace-all "\\" "/" (string/slice de 0 (- -1 (length suffix-win))))
        (string/has-suffix? suffix-posix de) (string/slice de 0 (- -1 (length suffix-posix)))
        "/usr/local")))

  (def prefix (dyn :prefix (os/getenv "JANET_PREFIX" (os/getenv "PREFIX" prefix-guess))))

  # Inherit from dyns and env variables
  (def pkglist (dyn :pkglist (os/getenv "JANET_PKGLIST" "https://github.com/janet-lang/pkgs.git")))
  (def manpath (dyn :manpath (os/getenv "JANET_MANPATH" (if win-prefix
                                                          (string win-prefix "/docs")
                                                          (string prefix "/share/man/man1")))))
  (def headerpath (dyn :headerpath (os/getenv "JANET_HEADERPATH" (if win-prefix
                                                                   (string win-prefix "/C")
                                                                   (string prefix "/include/janet")))))
  (def binpath (dyn :binpath (os/getenv "JANET_BINPATH" (if win-prefix
                                                          (string win-prefix "/bin")
                                                          (string prefix "/bin")))))
  (def libpath (dyn :libpath (os/getenv "JANET_LIBPATH" (if win-prefix
                                                          (string win-prefix "/C")
                                                          (string prefix "/lib")))))
  (def fix-modpath (dyn :fix-modpath (os/getenv "JANET_STRICT_MODPATH")))
  (def modpath (dyn :modpath (os/getenv "JANET_MODPATH" (if fix-modpath
                                                          (if win-prefix
                                                            (string win-prefix "/Library")
                                                            (string prefix "/lib/janet"))))))

  # Generate directories
  (when destdir
    (let [mp (or modpath (dyn :syspath))]
      (shutil/create-dirs (string destdir mp "/.manifests"))
      (when manpath (shutil/create-dirs (string destdir manpath)))
      (when binpath (shutil/create-dirs (string destdir binpath)))
      (when libpath (shutil/create-dirs (string destdir libpath)))
      (when headerpath (shutil/create-dirs (string destdir headerpath)))))

  (unless silent
    (when destdir (print "destdir: " destdir))
    (print "Using install prefix: " (if win-prefix win-prefix prefix))
    (print "binpath: " binpath)
    (print "libpath: " libpath)
    (print "manpath: " manpath)
    (print "headerpath: " headerpath)
    (print "modpath: " (or modpath "(default to JANET_PATH at runtime)"))
    (print "Setting package listing: " pkglist))

  # Write the config to a temporary file if not provided
  (def config
    @{:ar  (if iswin "lib.exe" "ar")
      :auto-shebang true
      :binpath binpath
      :c++ (if iswin "cl.exe" "c++")
      :c++-link (if iswin "link.exe" "c++")
      :cc (if iswin "cl.exe" "cc")
      :cc-link (if iswin "link.exe" "cc")
      :cflags (if iswin @["/nologo" "/MD"] @["-std=c99"])
      :cppflags (if iswin @["/nologo" "/MD" "/EHsc"] @["-std=c++11"])
      :cflags-verbose @[]
      :curlpath "curl"
      :dynamic-cflags (case hostos
                        :windows @["/LD"]
                        @["-fPIC"])
      :dynamic-lflags (case hostos
                        :windows @["/DLL"]
                        :macos @["-shared" "-undefined" "dynamic_lookup" "-lpthread"]
                        :mingw @["-shared"]
                        @["-shared" "-lpthread"])
      :gitpath "git"
      :headerpath headerpath
      :is-msvc iswin
      :janet "janet"
      :janet-cflags @[]
      :janet-lflags (case hostos
                      :linux @["-lm" "-ldl" "-lrt" "-pthread" "-rdynamic"]
                      :macos @["-lm" "-ldl" "-pthread" "-Wl,-export_dynamic"]
                      :mingw @["-lws2_32" "-lwsock32" "-lpsapi"]
                      :windows @[]
                      @["-lm" "-pthread"])
      :janet-importlib (case hostos
                         :windows (string headerpath "\\janet.lib")
                         :mingw (string libpath "/janet.lib"))
      :ldflags @[]
      :lflags (case hostos
                :windows @["/nologo"]
                @[])
      :libpath libpath
      :manpath manpath
      :modext (if (shutil/is-win-or-mingw) ".dll" ".so")
      :modpath modpath
      :nocolor false
      :pkglist pkglist
      :silent false
      :statext (if (shutil/is-win-or-mingw) ".static.lib" ".a")
      :tarpath "tar"
      :test false
      :use-batch-shell iswin
      :verbose false})

  (if as-data
    config
    (do
      # Sanity check for recursive data
      (def buf @"")
      (buffer/format buf "%j" config)
      (buffer/clear buf)
      (def output (buffer/format buf "# Autogenerated by generate-config in jpm/make-config.janet\n(def config %.99m)" config))
      output)))

(defn auto
  "Get an autodetected config."
  []
  (generate-config nil true true))
