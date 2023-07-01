###
### C and C++ compiler rule utilties
###

(use ./config)
(use ./rules)
(use ./shutil)

(def- entry-replacer
  "Convert url with potential bad characters into an entry-name"
  (peg/compile ~(% (any (+ '(range "AZ" "az" "09" "__") (/ '1 ,|(string "_" ($ 0) "_")))))))

(defn entry-replace
  "Escape special characters in the entry-name"
  [name]
  (get (peg/match entry-replacer name) 0))

(defn embed-name
  "Rename a janet symbol for embedding."
  [path]
  (->> path
       (string/replace-all "\\" "___")
       (string/replace-all "/" "___")
       (string/replace-all ".janet" "")))

(defn out-path
  "Take a source file path and convert it to an output path."
  [path from-ext to-ext]
  (->> path
       (string/replace-all "\\" "___")
       (string/replace-all "/" "___")
       (string/replace-all from-ext to-ext)
       (string (find-build-dir))))

(defn make-define
  "Generate strings for adding custom defines to the compiler."
  [define value]
  (if value
    (string "-D" define "=" value)
    (string "-D" define)))

(defn make-defines
  "Generate many defines. Takes a dictionary of defines. If a value is
  true, generates -DNAME (/DNAME on windows), otherwise -DNAME=value."
  [defines]
  (def ret (seq [[d v] :pairs defines] (make-define d (if (not= v true) v))))
  (array/push ret (make-define "JANET_BUILD_TYPE" (dyn:build-type "release")))
  ret)

(defn- getflags
  "Generate the c flags from the input options."
  [opts compiler]
  (def flags (if (= compiler :cc) :cflags :cppflags))
  (def bt (dyn:build-type "release"))
  (def bto
    (opt opts
         :optimize
         (case bt
           "release" 2
           "debug" 0
           "develop" 2
           2)))
  (def oflag
    (if (dyn :is-msvc)
      (case bto 0 "/Od" 1 "/O1" 2 "/O2" "/O2")
      (case bto 0 "-O0" 1 "-O1" 2 "-O2" "-O3")))
  (def debug-syms
    (if (or (= bt "develop") (= bt "debug"))
      (if (dyn :is-msvc) ["/DEBUG"] ["-g"])
      []))
  @[;(opt opts flags)
    ;(if (dyn:verbose) (dyn:cflags-verbose) [])
    ;debug-syms
    (string "-I" (dyn:headerpath))
    (string "-I" (dyn:modpath))
    oflag])

(defn entry-name
  "Name of symbol that enters static compilation of a module."
  [name]
  (string "janet_module_entry_" (entry-replace name)))

(defn compile-c
  "Compile a C file into an object file."
  [compiler opts src dest &opt static?]
  (def cc (opt opts compiler))
  (def cflags [;(getflags opts compiler)
               ;(if static? [] (dyn :dynamic-cflags))])
  (def entry-defines (if-let [n (and static? (opts :entry-name))]
                       [(make-define "JANET_ENTRY_NAME" n)]
                       []))
  (def defines [;(make-defines (opt opts :defines {})) ;entry-defines])
  (def headers (or (opts :headers) []))
  (rule dest [src ;headers]
        (unless (dyn:verbose) (print "compiling " src " to " dest "...") (flush))
        (create-dirs dest)
        (if (dyn :is-msvc)
          (clexe-shell cc ;defines "/c" ;cflags (string "/Fo" dest) src)
          (shell cc "-c" src ;defines ;cflags "-o" dest))))

  (comment

    (def dep-ldflags (seq [x :in deplibs] (string (dyn:modpath) "/" x (dyn:modext)))) # original behaviour when building wjpu with tarray as a dependency: \spork\tarray.dll : fatal error LNK1107: invalid or corrupt file: cannot read at 0x2D0
    (seq [x :in deplibs] (string (dyn:modpath) "/" x ".lib")) # see above for original behaviour; using :importlibext works for wjpu + tarray:
see https://stackoverflow.com/questions/9688200/difference-between-shared-objects-so-static-libraries-a-and-dlls-so
   ```
When a developer wants to use an already-built DLL, she must either reference
an "export library" (*.LIB) created by the DLL developer when she created the
DLL, or she must explicitly load the DLL at run time and request the entry
point address by name via the LoadLibrary() and GetProcAddress() mechanisms.
Most of the time, linking against a LIB file (which simply contains the linker
metadata for the DLL's exported entry points) is the way DLLs get used. Dynamic
loading is reserved typically for implementing "polymorphism" or "runtime
configurability" in program behaviors (accessing add-ons or later-defined
functionality, aka "plugins").```)

(defn link-c
  "Link C or C++ object files together to make a native module."
  [has-cpp opts target & objects]
  (def linker (dyn (if has-cpp :c++-link :cc-link)))
  (def cflags (getflags opts (if has-cpp :c++ :cc)))
  (def lflags [;(opt opts :lflags)
               ;(if (opts :static) [] (dyn:dynamic-lflags))])
  (def deplibs (get opts :native-deps []))
  (def linkext (if (is-win-or-mingw)
                    (dyn :importlibext)
                    (dyn :modext)))
  (def dep-ldflags (seq [x :in deplibs] (string (dyn:modpath) "/" x linkext)))
  # Use import libs on windows - we need an import lib to link natives to other natives.
  (def dep-importlibs
    (if (is-win-or-mingw)
      (seq [x :in deplibs] (string (dyn:modpath) "/" x (dyn :importlibext)))
      @[]))
  (when-let [import-lib (dyn :janet-importlib)]
    (array/push dep-importlibs import-lib))
  (def dep-importlibs (distinct dep-importlibs))
  (def ldflags [;(opt opts :ldflags []) ;dep-ldflags])
  (rule target objects
        (unless (dyn:verbose) (print "creating native module " target "...") (flush))
        (create-dirs target)
        (if (dyn :is-msvc)
          (clexe-shell linker (string "/OUT:" target) ;objects ;dep-importlibs ;ldflags ;lflags)
          (shell linker ;cflags `-o` target ;objects ;dep-importlibs ;ldflags ;lflags))))

(defn archive-c
  "Link object files together to make a static library."
  [opts target & objects]
  (def ar (opt opts :ar))
  (rule target objects
        (unless (dyn:verbose) (print "creating static library " target "...") (flush))
        (create-dirs target)
        (if (dyn :is-msvc)
          (shell ar "/nologo" (string "/out:" target) ;objects)
          (shell ar "rcs" target ;objects))))

#
# Standalone C compilation
#

(defn create-buffer-c-impl
  [bytes dest name]
  (create-dirs dest)
  (def out (file/open dest :wn))
  (def chunks (seq [b :in bytes] (string b)))
  (file/write out
              "#include <janet.h>\n"
              "static const unsigned char bytes[] = {"
              (string/join (interpose ", " chunks))
              "};\n\n"
              "const unsigned char *" name "_embed = bytes;\n"
              "size_t " name "_embed_size = sizeof(bytes);\n")
  (file/close out))

(defn create-buffer-c
  "Inline raw byte file as a c file."
  [source dest name]
  (rule dest [source]
        (print "generating " dest "...")
        (flush)
        (create-dirs dest)
        (with [f (file/open source :rn)]
          (create-buffer-c-impl (:read f :all) dest name))))

(defn modpath-to-meta
  "Get the meta file path (.meta.janet) corresponding to a native module path (.so)."
  [path]
  (string (string/slice path 0 (- (length (dyn:modext)))) "meta.janet"))

(defn modpath-to-static
  "Get the static library (.a) path corresponding to a native module path (.so)."
  [path]
  (string (string/slice path 0 (- -1 (length (dyn:modext)))) (dyn:statext)))

(defn make-bin-source
  [declarations lookup-into-invocations no-core]
  (string
    declarations
    ```

int main(int argc, const char **argv) {

#if defined(JANET_PRF)
    uint8_t hash_key[JANET_HASH_KEY_SIZE + 1];
#ifdef JANET_REDUCED_OS
    char *envvar = NULL;
#else
    char *envvar = getenv("JANET_HASHSEED");
#endif
    if (NULL != envvar) {
        strncpy((char *) hash_key, envvar, sizeof(hash_key) - 1);
    } else if (janet_cryptorand(hash_key, JANET_HASH_KEY_SIZE) != 0) {
        fputs("unable to initialize janet PRF hash function.\n", stderr);
        return 1;
    }
    janet_init_hash_key(hash_key);
#endif

    janet_init();

    ```
    (if no-core
    ```
    /* Get core env */
    JanetTable *env = janet_table(8);
    JanetTable *lookup = janet_core_lookup_table(NULL);
    JanetTable *temptab;
    int handle = janet_gclock();
    ```
    ```
    /* Get core env */
    JanetTable *env = janet_core_env(NULL);
    JanetTable *lookup = janet_env_lookup(env);
    JanetTable *temptab;
    int handle = janet_gclock();
    ```)
    lookup-into-invocations
    ```
    /* Unmarshal bytecode */
    Janet marsh_out = janet_unmarshal(
      janet_payload_image_embed,
      janet_payload_image_embed_size,
      0,
      lookup,
      NULL);

    /* Verify the marshalled object is a function */
    if (!janet_checktype(marsh_out, JANET_FUNCTION)) {
        fprintf(stderr, "invalid bytecode image - expected function.");
        return 1;
    }
    JanetFunction *jfunc = janet_unwrap_function(marsh_out);

    /* Check arity */
    janet_arity(argc, jfunc->def->min_arity, jfunc->def->max_arity);

    /* Collect command line arguments */
    JanetArray *args = janet_array(argc);
    for (int i = 0; i < argc; i++) {
        janet_array_push(args, janet_cstringv(argv[i]));
    }

    /* Create enviornment */
    temptab = env;
    janet_table_put(temptab, janet_ckeywordv("args"), janet_wrap_array(args));
    janet_table_put(temptab, janet_ckeywordv("executable"), janet_cstringv(argv[0]));
    janet_gcroot(janet_wrap_table(temptab));

    /* Unlock GC */
    janet_gcunlock(handle);

    /* Run everything */
    JanetFiber *fiber = janet_fiber(jfunc, 64, argc, argc ? args->data : NULL);
    fiber->env = temptab;
#ifdef JANET_EV
    janet_gcroot(janet_wrap_fiber(fiber));
    janet_schedule(fiber, janet_wrap_nil());
    janet_loop();
    int status = janet_fiber_status(fiber);
    janet_deinit();
    return status;
#else
    Janet out;
    JanetSignal result = janet_continue(fiber, janet_wrap_nil(), &out);
    if (result != JANET_SIGNAL_OK && result != JANET_SIGNAL_EVENT) {
      janet_stacktrace(fiber, out);
      janet_deinit();
      return result;
    }
    janet_deinit();
    return 0;
#endif
}

```))

(defn create-executable
  "Links an image with libjanet.a (or .lib) to produce an
  executable. Also will try to link native modules into the
  final executable as well."
  [opts source dest no-core]

  # Create executable's janet image
  (def cimage_dest (string dest ".c"))
  (def no-compile (opts :no-compile))
  (def bd (find-build-dir))
  (rule (if no-compile cimage_dest dest) [source]
        (print "generating executable c source " cimage_dest " from " source "...")
        (flush)
        (create-dirs dest)

        # Monkey patch stuff
        (def token (do-monkeypatch bd))
        (defer (undo-monkeypatch token)

          # Load entry environment and get main function.
          (def env (make-env))
          (def entry-env (dofile source :env env))
          (def main ((entry-env 'main) :value))
          (def dep-lflags @[])
          (def dep-ldflags @[])

          # Create marshalling dictionary
          (def mdict1 (invert (env-lookup root-env)))
          (def mdict
            (if no-core
              (let [temp @{}]
                (eachp [k v] mdict1
                  (if (or (cfunction? k) (abstract? k))
                    (put temp k v)))
                temp)
              mdict1))

          # Load all native modules
          (def prefixes @{})
          (def static-libs @[])
          (loop [[name m] :pairs module/cache
                 :let [n (m :native)]
                 :when n
                 :let [prefix (gensym)]]
            (print "found native " n "...")
            (flush)
            (put prefixes prefix n)
            (array/push static-libs (modpath-to-static n))
            (def oldproto (table/getproto m))
            (table/setproto m nil)
            (loop [[sym value] :pairs (env-lookup m)]
              (put mdict value (symbol prefix sym)))
            (table/setproto m oldproto))

          # Find static modules
          (var has-cpp false)
          (def declarations @"")
          (def lookup-into-invocations @"")
          (loop [[prefix name] :pairs prefixes]
            (def meta (eval-string (slurp (modpath-to-meta name))))
            (if (meta :cpp) (set has-cpp true))
            (buffer/push-string lookup-into-invocations
                                "    temptab = janet_table(0);\n"
                                "    temptab->proto = env;\n"
                                "    " (meta :static-entry) "(temptab);\n"
                                "    janet_env_lookup_into(lookup, temptab, \""
                                prefix
                                "\", 0);\n\n")
            (when-let [lfs (meta :lflags)]
              (array/concat dep-lflags lfs))
            (when-let [lfs (meta :ldflags)]
              (array/concat dep-ldflags lfs))
            (buffer/push-string declarations
                                "extern void "
                                (meta :static-entry)
                                "(JanetTable *);\n"))

          # Build image
          (def image (marshal main mdict))
          # Make image byte buffer
          (create-buffer-c-impl image cimage_dest "janet_payload_image")
          # Append main function
          (spit cimage_dest (make-bin-source declarations lookup-into-invocations no-core) :ab)
          (def oimage_dest (out-path cimage_dest ".c" ".o"))
          # Compile and link final exectable
          (unless no-compile
            (def ldflags [;dep-ldflags ;(opt opts :ldflags [])])
            (def lflags [;static-libs
                         (string (dyn:libpath) "/libjanet." (last (string/split "." (dyn:statext))))
                          ;dep-lflags ;(opt opts :lflags []) ;(dyn:janet-lflags)])
            (def defines (make-defines (opt opts :defines {})))
            (def cc (opt opts :cc))
            (def cflags [;(getflags opts :cc) ;(dyn:janet-cflags)])
            (print "compiling " cimage_dest " to " oimage_dest "...")
            (flush)
            (create-dirs oimage_dest)
            (if (dyn:is-msvc)
              (clexe-shell cc ;defines "/c" ;cflags (string "/Fo" oimage_dest) cimage_dest)
              (shell cc "-c" cimage_dest ;defines ;cflags "-o" oimage_dest))
            (if has-cpp
              (let [linker (opt opts (if (dyn :is-msvc) :c++-link :c++))
                    cppflags [;(getflags opts :c++) ;(dyn:janet-cflags)]]
                (print "linking " dest "...")
                (flush)
                (if (dyn:is-msvc)
                  (clexe-shell linker (string "/OUT:" dest) oimage_dest ;ldflags ;lflags)
                  (shell linker ;cppflags `-o` dest oimage_dest ;ldflags ;lflags)))
              (let [linker (opt opts (if (dyn:is-msvc) :cc-link :cc))]
                (print "linking " dest "...")
                (flush)
                (create-dirs dest)
                (if (dyn:is-msvc)
                  (clexe-shell linker (string "/OUT:" dest) oimage_dest ;ldflags ;lflags)
                  (shell linker ;cflags `-o` dest oimage_dest ;ldflags ;lflags))))))))
