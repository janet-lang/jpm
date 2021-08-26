(unless (os/getenv "INCLUDE")
  (errorf "Run from a developer console or run the vcvars%d.bat script to setup compiler environment."
          (if (= (os/arch) :x64) 64 32)))

(def config
  {:ar "lib.exe"
   :auto-shebang true
   :c++ "cl.exe"
   :c++-link "link.exe"
   :cc "cl.exe"
   :cc-link "link.exe"
   :cflags @["/nologo" "/MD"]
   :cppflags @["/nologo" "/MD" "/EHsc"]
   :cflags-verbose @["-Wall" "-Wextra"]
   :curlpath "curl"
   :dynamic-cflags @["/LD"]
   :dynamic-lflags @["/DLL"]
   :gitpath "git"
   :is-msvc true
   :janet "janet"
   :janet-cflags @[]
   :janet-lflags @[]
   :ldflags @[]
   :lflags @["/nologo"]
   :local false
   :modext ".dll"
   :nocolor false
   :optimize 2
   :pkglist "https://github.com/janet-lang/pkgs.git"
   :silent false
   :statext ".static.lib"
   :tarpath "tar"
   :test false
   :use-batch-shell true
   :verbose false})
