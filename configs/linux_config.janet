(def prefix "/usr/local")

(def config 
  {:ar "ar"
   :auto-shebang true
   :binpath (string prefix "/bin")
   :c++ "c++"
   :c++-link "c++"
   :cc "cc"
   :cc-link "cc"
   :cflags @["-std=c99"]
   :cflags-verbose @["-Wall" "-Wextra"]
   :cppflags @["-std=c++11"]
   :curlpath "curl"
   :dynamic-cflags @["-fPIC"]
   :dynamic-lflags @["-shared" "-lpthread"]
   :gitpath "git"
   :headerpath (string prefix "/include/janet")
   :is-msvc false
   :janet "janet"
   :janet-cflags @[]
   :janet-lflags @["-lm" "-ldl" "-lrt"]
   :ldflags @[]
   :lflags @[]
   :libpath (string prefix "/lib")
   :modext ".so"
   :modpath (string prefix "/lib/janet")
   :nocolor false
   :optimize 2
   :pkglist "https://github.com/janet-lang/pkgs.git"
   :silent false
   :statext ".a"
   :tarpath "tar"
   :test false
   :use-batch-shell false
   :verbose false})
