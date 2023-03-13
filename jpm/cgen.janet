###
### cgen.janet
### 
###
### A DSL that compiles to C. Let's
### you use Janet's macro system to
### emit C code.
###
### The semantics of the IR are basically the
### same as C so a higher level language (or type system)
### should be built on top of this. This IR emits a very useful
### subset of valid C 99.
###

(defmacro- setfn
  [name & body]
  ~(set ,name (fn ,name ,;body)))

(def- mangle-peg
  (peg/compile
    ~{:valid (range "az" "AZ" "__")
      :one (+ (/ "-" "_") ':valid (/ '1 ,|(string "_X" ($ 0))))
      :main (% (* :one (any (+ ':d :one))))}))

(def- bops
 {'+ '+ '- '- '* '* '/ '/ '% '% '< '<
  '> '> '<= '<= '>= '>= '== '== '!= '!=
  '>> ">>" '<< "<<" '&& "&&" '^ "^"
  'and "&&" 'or "||" 'band "&" 'bor "|" 'bxor "^"
  'blshift "<<" 'brshift ">>"})

(def- uops {'bnot "~" 'not "!" 'neg "-" '! "!"})

(defn mangle
  "Convert any sequence of bytes to a valid C identifier in a way that is unlikely to collide.
  `print-ir` will not mangle symbols for you."
  [token]
  (first (peg/match mangle-peg token)))

(defdyn *indent* "current indent buffer")
(defn- indent [] (or (dyn *indent*) (setdyn *indent* @"")))
(defn- emit-indent [] (prin (indent)))
(defn- emit-block-start [] (prin "{") (buffer/push (indent) "  ") (print))
(defn- emit-block-end [&opt nl] (buffer/popn (indent) 2) (emit-indent) (prin "}") (when nl (print)))

(var- emit-type nil)
(var- emit-expression nil)
(var- emit-statement nil)
(var- emit-block nil)

(defn- emit-struct-union-def
  [which name args defname]
  (when (or (nil? args) (empty? args))
    (prin which " " name)
    (if defname (prin " " defname))
    (break))
  (assert (even? (length args)) (string/format "expected even number of arguments, got %j" args))
  (prin which " ")
  (if name (prin name " "))
  (emit-block-start)
  (each [field ftype] (partition 2 args)
    (emit-indent)
    (emit-type ftype field)
    (print ";"))
  (emit-block-end)
  (if defname (prin " " defname)))

(defn- emit-struct-def
  [name args defname]
  (emit-struct-union-def "struct" name args defname))

(defn- emit-union-def
  [name args defname]
  (emit-struct-union-def "union" name args defname))

(defn- emit-enum-def
  [name args defname]
  (prin "enum ")
  (if name (prin name " "))
  (emit-block-start)
  (each x args
    (emit-indent)
    (if (tuple? x)
      (do
        (prin (x 0) " = ")
        (emit-expression (x 1))
        (print ","))
      (print x ",")))
  (emit-block-end)
  (if defname (prin " " defname)))

(defn- emit-fn-pointer-type
  [ret-type args defname]
  (prin "(")
  (emit-type ret-type)
  (prin ")(*" defname ")(")
  (var is-first true)
  (each x args
    (unless is-first (prin ", "))
    (set is-first false)
    (if (tuple? x)
      (emit-type (x 1) (x 0))
      (emit-type x)))
  (prin ")"))

(defn- emit-ptr-type
  [x alias]
  (emit-type x)
  (prin " *")
  (if alias (prin alias)))

(defn- emit-ptr-ptr-type
  [x alias]
  (emit-type x)
  (prin " **")
  (if alias (prin alias)))

(defn- emit-const-type
  [x alias]
  (prin "const ")
  (emit-type x)
  (if alias (prin " " alias)))

(defn- emit-array-type
  [x n alias]
  (if-not alias (prin "("))
  (emit-type x)
  (if alias (prin " " alias))
  (prin "[")
  (when n
    (emit-expression n true))
  (prin "]")
  (if-not alias (prin ")")))

(setfn
  emit-type
  [definition &opt alias]
  (match definition
    (d (bytes? d)) (do (prin d) (if alias (prin " " alias)))
    (t (tuple? t))
    (match t
      ['struct & body] (emit-struct-def nil body alias)
      ['named-struct n & body] (emit-struct-def n body alias)
      ['enum & body] (emit-enum-def nil body alias)
      ['named-enum n & body] (emit-enum-def n body alias)
      ['union & body] (emit-union-def nil body alias)
      ['named-union n & body] (emit-union-def n body alias)
      ['fn n & body] (emit-fn-pointer-type n body alias)
      ['ptr val] (emit-ptr-type val alias)
      ['* val] (emit-ptr-type val alias)
      ['ptrptr val] (emit-ptr-ptr-type val alias)
      ['** val] (emit-ptr-ptr-type (definition 1) alias)
      ['const t] (emit-const-type t alias)
      ['array t] (emit-array-type t (get definition 2) alias)
      (errorf "unexpected type form %v" definition))
    (errorf "unexpected type form %v" definition)))

(defn- emit-typedef
  [alias definition]
  (prin "typedef ")
  (emit-type definition alias)
  (print ";"))

# Expressions

(defn- emit-funcall
  [items]
  (def f (get items 0))
  (emit-expression f (symbol? f))
  (prin "(")
  (for i 1 (length items)
    (if (not= i 1) (prin ", "))
    (emit-expression (in items i) true))
  (prin ")"))

(defn- emit-binop
  [op & xs]
  (var is-first true)
  (each x xs
    (if-not is-first (prin " " op " "))
    (set is-first false)
    (emit-expression x)))

(defn- emit-indexer
  [op ds field]
  (emit-expression ds)
  (prin op field))

(defn- emit-unop
  [op x]
  (prin op)
  (emit-expression x))

(defn- emit-aindex
  [a index]
  (emit-expression a)
  (prin "[")
  (emit-expression index true)
  (prin "]"))

(defn- emit-set
  [lvalue rvalue]
  (emit-expression lvalue true)
  (prin " = ")
  (emit-expression rvalue true))

(defn- emit-deref
  [ptr]
  (prin "*")
  (emit-expression ptr))

(defn- emit-address
  [expr]
  (prin "&")
  (emit-expression expr))

(defn- emit-cast
  [ctype expr]
  (prin "(" ctype ")")
  (emit-expression expr))

(defn- emit-struct-ctor
  [args]
  (assert (even? (length args)) "expected an even number of arguments for a struct literal")
  (emit-block-start)
  (each [k v] (partition 2 args)
    (emit-indent)
    (prin "." k " = ")
    (emit-expression v true)
    (print ","))
  (emit-block-end))

(defn- emit-array-ctor
  [args]
  (var is-first true)
  (prin "{")
  (each x args
    (if-not is-first (prin ", "))
    (set is-first false)
    (emit-expression x true))
  (prin "}"))

(setfn
  emit-expression
  [form &opt noparen]
  (match form
    (f (or (symbol? f) (keyword? f))) (prin f)
    (n (number? n)) (prinf "%.17g" n)
    (s (string? s)) (prinf "%v" s) # todo - better match escape codes
    (a (array? a)) (do
                     (unless noparen (prin "("))
                     (emit-array-ctor a)
                     (unless noparen (prin ")")))
    (d (dictionary? d))
    (do
      (unless noparen (prin "("))
      (emit-struct-ctor (mapcat identity (sort (pairs d))))
      (unless noparen (print ")")))
    (t (tuple? t))
    (do
      (unless noparen (prin "("))
      (match t
        [(bs (bops bs)) & rest] (emit-binop (bops bs) ;rest)
        [(bs (uops bs)) & rest] (emit-unop (uops bs) ;rest)
        ['literal l] (prin (string l))
        ['quote q] (prin (string q))
        ['index v i] (emit-aindex v i)
        ['call & args] (emit-funcall args)
        ['set v i] (emit-set v i)
        ['deref v] (emit-deref v)
        ['addr v] (emit-address v)
        ['cast t v] (emit-cast t v)
        ['struct & vals] (emit-struct-ctor vals)
        ['array & vals] (emit-array-ctor vals)
        ['-> v f] (emit-indexer "->" v f)
        ['. v f] (emit-indexer "." v f)
        (emit-funcall t))
      (unless noparen (prin ")")))
    ie (errorf "invalid expression %v" ie)))

# Statements

(defn- emit-declaration
  [v vtype &opt value]
  (emit-type vtype v)
  (when (not= nil value)
    (prin " = ")
    (emit-expression value true)))

(setfn
  emit-statement
  [form]
  (match form
    ['def & args] (emit-declaration ;args)
    (emit-expression form true)))

# Blocks

(defn- emit-do
  [statements]
  (emit-indent)
  (emit-block-start)
  (each s statements
    (emit-block s true))
  (emit-block-end)
  (print))

(defn- emit-cond
  [args]
  (assert (>= (length args) 2) "expected at least 2 arguments to if")
  (var is-first true)
  (each [condition branch] (partition 2 args)
    (if (= nil branch)
      (do
        (prin " else ")
        (emit-block condition))
      (do
        (if is-first
          (do (emit-indent) (prin "if ("))
          (prin " else if ("))
        (set is-first false)
        (emit-expression condition true)
        (prin ") ")
        (emit-block branch))))
  (print))

(defn- emit-while
  [condition stm body]
  (emit-indent)
  (prin "while (")
  (emit-expression condition true)
  (prin ") ")
  (if (empty? body)
    (emit-block stm)
    (emit-do [stm ;body]))
  (print))

(defn- emit-return
  [v]
  (emit-indent)
  (prin "return ")
  (emit-expression v true)
  (print ";"))

(setfn
  emit-block
  [form &opt nobracket]
  (unless nobracket
    (emit-block-start))
  (match form
    ['do & body] (emit-do body)
    ['while cond stm & body] (emit-while cond stm body)
    ['if & body] (emit-cond body)
    ['cond & body] (emit-cond body)
    ['return val] (emit-return val)
    ['break] (do (emit-indent) (print "break;"))
    ['continue] (do (emit-indent) (print "continue;"))
    ['label lab] (print "label " lab ":")
    ['goto lab] (do (emit-indent) (print "goto " (form 1)))
    stm (do (emit-indent) (emit-statement stm) (print ";")))
  (unless nobracket (emit-block-end)))

# Top level forms

(defn- emit-storage-classes
  [classes]
  (each class classes
    (prin class " ")))

(defn- emit-function
  [classes name arglist rtype body]
  (print)
  (emit-storage-classes classes)
  (prin rtype " " name "(")
  (var is-first true)
  (each arg arglist
    (unless is-first (prin ", "))
    (set is-first false)
    (emit-type (arg 1))
    (prin " " (arg 0)))
  (prin ")")
  (if (empty? body)
    (print ";")
    (do
      (prin " ")
      (emit-do body))))

(defn- do-directive
  [& args]
  (print "#" (string/join (map string args) " ")))

(defn- do-function
  [& form]
  (match form
    [(sc (indexed? sc)) n al rt & b] (emit-function sc n al rt b)
    [n al rt & b] (emit-function [] n al rt b)
    (error "invalid function form")))

(defn- do-declare
  [& form]
  (match form
    [n t d] (do (emit-declaration n t d) (print ";"))
    [(sc (indexed? sc)) n t d]
    (do (print)
      (emit-storage-classes sc)
      (emit-declaration n t d)
      (print ";"))
    (error "invalid declare form")))

(defn- do-typedef
  [n d]
  (print)
  (emit-typedef n d))

(def- injected-macros
  "Make functions that can be used at the top level to generate code."
  {'function do-function
   'directive do-directive
   '@ do-directive
   'declare do-declare
   'typedef do-typedef})

(defn- qq-wrap
  [args]
  (map (fn [x] ['quasiquote x]) args))

###
### Safe expansion
###

(defn print-ir
  "Compile the CGEN IR (without any dynamic evaluation) to C and print it to (dyn :out)."
  [ir]
  (each el ir
    (def [head & rest] el)
    (if-let [x (get injected-macros head)]
      (x ;rest)
      (errorf "unknown top level form %v" el))))

(defmacro ir
  "Macro that automatically quotes the body provided and calls (print-ir ...) on the body."
  [& body]
  ~(,print-ir ',body))

(defn process-file
  "Load CGEN IR from a file, evalute it, and dump to an output file. If `out-path` is
  not provided, will replace the .cgen suffix with .c in the input path file name. Normal
  Janet code can go inline with the C code, and can be used to preprocess the system level code."
  [in-path &opt out-path]
  (default out-path (string/slice in-path 0 -4))
  (def env (make-env))
  (eachp [sym fun] injected-macros
    (put env sym @{:value fun :macro true}))
  (with [o (file/open out-path :wbn)]
    (put env :out o)
    (dofile in-path :env env)))

###
### Dynamic expansion
###

(defn- loader
  [path &]
  (def c (-> path slurp parse-all))
  (defn tmpl [&opt rp]
    (default rp (string/slice path 0 -4))
    (with [o (file/open rp :wbn)]
      (with-dyns [:out o :current-file path] (print-ir c))))
  @{'render @{:doc "Main template function."
              :value tmpl}})

(defn add-loader
  "Adds the custom template loader to Janet's module/loaders and
  update module/paths."
  []
  (put module/loaders :cgen loader)
  (module/add-paths ".cgen" :cgen))

###
### For use with (import jpm/cgen)
###

(defmacro function [& args] ~(,do-function ,;(qq-wrap args)))
(defmacro directive [& args] ~(,do-directive ,;(qq-wrap args)))
(defmacro @ [& args] ~(,do-directive ,;(qq-wrap args)))
(defmacro declare [& args] ~(,do-declare ,;(qq-wrap args)))
(defmacro typedef [& args] ~(,do-typedef ,;(qq-wrap args)))
