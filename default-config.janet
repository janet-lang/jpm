###
### default-config.janet
###
### A jpm configuration file that tries to autodetect reasonable defaults on various platforms.
### this configuration can be replaced during installation with --bootstrap-config.
###


(def hostos (os/which))
(def iswin (= :windows hostos))

(when iswin
  (unless (os/getenv "INCLUDE")
    (errorf "Run from a developer console or run the vcvars%d.bat script to setup compiler environment."
            (if (= (os/arch) :x64) 64 32))))

(def config
  @{:ar  (if iswin "lib.exe" "ar")
    :auto-shebang true
    :c++ (if iswin "cl.exe" "c++")
    :c++-link (if iswin "link.exe" "c++")
    :cc (if iswin "cl.exe" "cc")
    :cc-link (if iswin "link.exe" "cc")
    :cflags (if iswin @["/nologo" "/MD"] @["-std=c99"])
    :cppflags (if iswin @["/nologo" "/MD" "/EHsc"] @["-std=c++11"])
    :cflags-verbose (if iswin @[] @["-Wall" "-Wextra"])
    :curlpath "curl"
    :dynamic-cflags (case hostos
                      :windows @["/LD"]
                      @["-fPIC"])
    :dynamic-lflags (case hostos
                      :windows @["/DLL"]
                      :macos @["-shared" "-undefined" "dynamic_lookup" "-lpthread"]
                      @["-shared" "-lpthread"])
    :gitpath "git"
    :is-msvc iswin
    :janet "janet"
    :janet-cflags @[]
    :janet-lflags (case hostos
                    :linux @["-lm" "-ldl" "-lrt" "-pthread"]
                    :macos @["-lm" "-ldl" "-pthread"]
                    :windows @[]
                    @["-lm" "-pthread"])
    :ldflags @[]
    :lflags (case hostos
              :windows @["/nologo"]
              @[])
    :modext (if iswin ".dll" ".so")
    :nocolor false
    :optimize 2
    :pkglist "https://github.com/janet-lang/pkgs.git"
    :silent false
    :statext (if iswin ".static.lib" ".a")
    :tarpath "tar"
    :test false
    :use-batch-shell iswin
    :verbose false})

(unless iswin
  # Guess PREFIX to use for paths
  (def prefix "/usr/local")
  (put config :manpath (string prefix "/share/man/man1"))
  (put config :headerpath (string prefix "/include/janet"))
  (put config :binpath (string prefix "/bin"))
  (put config :libpath (string prefix "/lib"))
  (put config :modpath (or (os/getenv "JANET_PATH") (string prefix "/lib/janet"))))
