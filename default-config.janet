(def default-config
  "A default configuration that is useful if no other configuration is found.
  Should work on many linux systems when Janet is install /usr/local."
  {:ar "ar"
   :auto-shebang true
   :binpath "/usr/local/bin"
   :c++ "c++"
   :c++-link "c++"
   :cc "cc"
   :cc-link "cc"
   :cflags @["-std=c99"]
   :cppflags @["-std=c++11"]
   :cflags-verbose @["-Wall" "-Wextra"]
   :curlpath "curl"
   :dynamic-cflags @["-fPIC"]
   :dynamic-lflags @["-shared" "-lpthread"]
   :gitpath "git"
   :headerpath "/usr/local/include/janet"
   :is-msvc false
   :janet "janet"
   :ldflags @[]
   :lflags @[]
   :libpath "/usr/local/lib"
   :modext ".so"
   :modpath "/usr/local/lib/janet"
   :nocolor false
   :optimize 2
   :pkglist "https://github.com/janet-lang/pkgs.git"
   :silent false
   :statext ".a"
   :tarpath "tar"
   :use-batch-shell false
   :verbose false})
