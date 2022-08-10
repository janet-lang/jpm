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

(defn mangle
  "Convert any sequence of bytes to a valid C identifier in a way that is unlikely to collide.
  `print-ir` will not mangle symbols for you."
  [token]
  (first (peg/match mangle-peg token)))

(defn print-ir
  "Compile the CGEN IR to C and print it to (dyn :out)."
  [ir]

  # Basic utilities

  (def indent @"")
  (defn emit-indent [] (prin indent))
  (defn emit-block-start [] (prin "{") (buffer/push indent "  ") (print))
  (defn emit-block-end [&opt nl] (buffer/popn indent 2) (emit-indent) (prin "}") (when nl (print)))

  # Mutually recrusive functions

  (var emit-type nil)
  (var emit-expression nil)
  (var emit-statement nil)
  (var emit-block nil)
  (var emit-top nil)

  # Types (for type declarations)

  (defn emit-struct-union-def
    [which name args defname]
    (when (or (nil? args) (empty? args))
      (prin which " " name)
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

  (defn emit-struct-def
    [name args defname]
    (emit-struct-union-def "struct" name args defname))

  (defn emit-union-def
    [name args defname]
    (emit-struct-union-def "union" name args defname))

  (defn emit-enum-def
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

  (defn emit-fn-pointer-type
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

  (defn emit-ptr-type
    [x alias]
    (emit-type x)
    (prin " *")
    (if alias (prin alias)))

  (defn emit-ptr-ptr-type
    [x alias]
    (emit-type x)
    (prin " **")
    (if alias (prin alias)))

  (defn emit-const-type
    [x alias]
    (prin "const ")
    (emit-type x)
    (if alias (prin " " alias)))

  (defn emit-array-type
    [x n alias]
    (if-not alias (prin "("))
    (emit-type x)
    (if alias (prin " " alias))
    (prin "[")
    (when n
      (emit-expression n true))
    (prin "]")
    (if-not alias (prin ")")))

  (setfn emit-type
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
             (errorf "unexpected type form %v" definition))
           (errorf "unexpected type form %v" definition)))

  (defn emit-typedef
    [alias definition]
    (prin "typedef ")
    (emit-type definition alias)
    (print ";"))

  # Expressions

  (defn emit-funcall
    [items]
    (def f (get items 0))
    (emit-expression f (symbol? f))
    (prin "(")
    (for i 1 (length items)
      (if (not= i 1) (prin ", "))
      (emit-expression (in items i) true))
    (prin ")"))

  (defn emit-binop
    [op & xs]
    (var is-first true)
    (each x xs
      (if-not is-first (prin " " op " "))
      (set is-first false)
      (emit-expression x)))

  (defn emit-indexer
    [op ds field]
    (emit-expression ds)
    (prin op field))

  (defn emit-unop
    [op x]
    (prin op)
    (emit-expression x))

  (defn emit-aindex
    [a index]
    (emit-expression a)
    (prin "[")
    (emit-expression index true)
    (prin "]"))

  (defn emit-set
    [lvalue rvalue]
    (emit-expression lvalue true)
    (prin " = ")
    (emit-expression rvalue true))

  (defn emit-deref
    [ptr]
    (prin "*")
    (emit-expression ptr))

  (defn emit-address
    [expr]
    (prin "&")
    (emit-expression expr))

  (defn emit-cast
    [ctype expr]
    (prin "(" ctype ")")
    (emit-expression expr))

  (defn emit-struct-ctor
    [args]
    (assert (even? (length args)) "expected an even number of arguments for a struct literal")
    (emit-block-start)
    (each [k v] (partition 2 args)
      (emit-indent)
      (prin "." k " = ")
      (emit-expression v true)
      (print ","))
    (emit-block-end))

  (defn emit-array-ctor
    [args]
    (var is-first true)
    (prin "{")
    (each x args
      (if-not is-first (prin ", "))
      (set is-first false)
      (emit-expression x true))
    (prin "}"))

  (setfn emit-expression
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
             (def bops
               {'+ '+ '- '- '* '* '/ '/ '% '% '< '<
                '> '> '<= '<= '>= '>= '== '== '!= '!=
                'and "&&" 'or "||" 'band "&" 'bor "|" 'bxor "^"
                'blshift "<<" 'brshift ">>"})
             (def uops {'bnot "~" 'not "!" 'neg "-"})
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

  (defn emit-declaration
    [v vtype &opt value]
    (emit-type vtype)
    (match v
      ['array n & i]
      (do
        (prin " " n)
        (prin "[")
        (if-not (empty? i) (prin i))
        (prin "]"))
      (prin " " v))
    (when (not= nil value)
      (prin " = ")
      (emit-expression value true)))

  (setfn emit-statement
         [form]
         (match form
           ['def n t & v] (emit-declaration n t (first v))
           (emit-expression form true)))

  # Blocks

  (defn emit-do
    [statements]
    (emit-indent)
    (emit-block-start)
    (each s statements
      (emit-block s true))
    (emit-block-end)
    (print))

  (defn emit-cond
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

  (defn emit-while
    [condition stm body]
    (emit-indent)
    (prin "while (")
    (emit-expression condition true)
    (prin ") ")
    (if (empty? body)
      (emit-block stm)
      (emit-do [stm ;body]))
    (print))

  (defn emit-return
    [v]
    (emit-indent)
    (prin "return ")
    (emit-expression v true)
    (print ";"))

  (defn emit-janet [code &opt inner]
    (each form code
      (match
        [(truthy? inner)
         (protect (match
                    (compile form)
                    (f (function? f)) (f)
                    (t (table? t)) (error (t :error))))]
        [true [true (t (indexed? t))]] (each f t (emit-block f true))
        [false [true (t (indexed? t))]] (each f t (emit-top f))
        [_ [true (s (bytes? s))]] (print s)
        [_ [false err]] (error err))))

  (setfn emit-block
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
           ['$ & code] (do (emit-janet code true))
           stm (do (emit-indent) (emit-statement stm) (print ";")))
         (unless nobracket (emit-block-end)))

  # Top level forms

  (defn emit-storage-classes
    [classes]
    (each class classes
      (prin class " ")))

  (defn emit-function
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
    (prin ") ")
    (emit-do body))

  (defn emit-directive
    [args]
    (print "#" (string/join (map string args) " ")))

  (setfn emit-top
         [form]
         (match form
           ['defn (sc (indexed? sc)) n al rt & b] (emit-function sc n al rt b)
           ['defn n al rt & b] (emit-function [] n al rt b)
           ['deft n d] (do (print) (emit-typedef n d))
           ['def (sc (indexed? sc)) n t d]
           (do (print)
             (emit-storage-classes sc)
             (emit-declaration n t d)
             (print ";"))
           ['def n t d] (do (emit-declaration n t d) (print ";"))
           ['directive & directive] (emit-directive directive)
           ['@ & directive] (emit-directive directive)
           ['$ & code] (emit-janet code)
           (errorf "unknown top-level form %v" form)))

  # Final compilation
  (each top ir
    (emit-top top)))

(defmacro ir
  "Macro that automatically quotes the body provided and calls (print-ir ...) on the body."
  [& body]
  ~(,print-ir ',body))

#
# Module loading
#

(defn- loader
  [path &]
  (with-dyns [:current-file path]
    (let [p (parser/new)
          c @[]]
      (:consume p (slurp path))
      (while (:has-more p)
        (array/push c (:produce p)))
      (defn tmpl [&opt rp]
        (default rp (string/slice path 0 -4))
        (with [o (file/open rp :wbn)]
          (with-dyns [:out o :current-file path] (print-ir c))))
      @{'render @{:doc "Main template function."
                  :value tmpl}})))

(defn add-loader
  "Adds the custom template loader to Janet's module/loaders and
  update module/paths."
  []
  (put module/loaders :cgen loader)
  (module/add-paths ".cgen" :cgen))
