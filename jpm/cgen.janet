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
    (assert (even? (length args)) "expected even number of arguments")
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
    (case (type definition)
      :tuple
      (case (get definition 0)
        'struct (emit-struct-def nil (slice definition 1) alias)
        'named-struct (emit-struct-def (definition 1) (slice definition 1) alias)
        'enum (emit-enum-def nil (slice definition 1) alias)
        'named-enum (emit-enum-def (definition 1) (slice definition 2) alias)
        'union (emit-union-def nil (slice definition 1) alias)
        'named-union (emit-union-def (definition 1) (slice definition 2) alias)
        'fn (emit-fn-pointer-type (definition 1) (slice definition 2) alias)
        'ptr (emit-ptr-type (definition 1) alias)
        '* (emit-ptr-type (definition 1) alias)
        'ptrptr (emit-ptr-ptr-type (definition 1) alias)
        '** (emit-ptr-ptr-type (definition 1) alias)
        'array (emit-array-type (definition 1) (get definition 2) alias)
        'const (emit-const-type (definition 1) alias)
        (errorf "unexpected type form %v" definition))
      :keyword (do (prin definition) (if alias (prin " " alias)))
      :symbol (do (prin definition) (if alias (prin " " alias)))
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
     (case (type form)
       :symbol (prin form)
       :keyword (prin form)
       :number (prinf "%.17g" form)
       :string (prinf "%v" form) # todo - better match escape codes
       :tuple
       (do
         (unless noparen (prin "("))
         (case (get form 0)
           'literal (prin (string (form 1)))
           'quote (prin (string (form 1)))
           '+ (emit-binop ;form)
           '- (emit-binop ;form)
           '* (emit-binop ;form)
           '/ (emit-binop ;form)
           '% (emit-binop ;form)
           '< (emit-binop ;form)
           '> (emit-binop ;form)
           '<= (emit-binop ;form)
           '>= (emit-binop ;form)
           '== (emit-binop ;form)
           '!= (emit-binop ;form)
           'and (emit-binop "&&" ;(slice form 1))
           'or (emit-binop "||" ;(slice form 1))
           'band (emit-binop "&" ;(slice form 1))
           'bor (emit-binop "|" ;(slice form 1))
           'bxor (emit-binop "^" ;(slice form 1))
           'bnot (emit-unop "~" (form 1))
           'not (emit-unop "!" (form 1))
           'neg (emit-unop "-" (form 1))
           'blshift (emit-binop "<<" (form 1) (form 2))
           'brshift (emit-binop ">>" (form 1) (form 2))
           'index (emit-aindex (form 1) (form 2))
           'call (emit-funcall (slice form 1))
           'set (emit-set (form 1) (form 2))
           'deref (emit-deref (form 1))
           'addr (emit-address (form 1))
           'cast (emit-cast (form 1) (form 2))
           'struct (emit-struct-ctor (slice form 1))
           'array (emit-array-ctor (slice form 1))
           '-> (emit-indexer "->" (form 1) (form 2))
           '. (emit-indexer "." (form 1) (form 2))
           (emit-funcall form))
         (unless noparen (prin ")")))
       :array (do
                (unless noparen (prin "("))
                (emit-array-ctor form)
                (unless noparen (prin ")")))
       :struct (do
                 (unless noparen (prin "("))
                 (emit-struct-ctor (mapcat identity (sort (pairs form))))
                 (unless noparen (print ")")))
       :table (do
                (unless noparen (prin "("))
                (emit-struct-ctor (mapcat identity (sort (pairs form))))
                (unless noparen (print ")")))
       (errorf "invalid expression %v" form)))

  # Statements

  (defn emit-declaration
    [v vtype &opt value]
    (emit-type vtype)
    (prin " " v)
    (when (not= nil value)
      (prin " = ")
      (emit-expression value true)))

  (setfn emit-statement
    [form]
    (case (get form 0)
      'def (emit-declaration (form 1) (form 2) (form 3))
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
    [condition body]
    (emit-indent)
    (prin "while (")
    (emit-expression condition true)
    (prin ") ")
    (emit-block body)
    (print))

  (defn emit-return
    [v]
    (emit-indent)
    (prin "return ")
    (emit-expression v true)
    (print ";"))

  (setfn emit-block
    [form &opt nobracket]
    (unless nobracket
      (emit-block-start))
    (case (get form 0)
      'do (emit-do (slice form 1))
      'while (emit-while (form 1) (form 2))
      'if (emit-cond (slice form 1))
      'cond (emit-cond (slice form 1))
      'return (emit-return (form 1))
      'break (do (emit-indent) (print "break;"))
      'continue (do (emit-indent) (print "continue;"))
      'label (print "label " (form 1) ":")
      'goto (do (emit-indent) (print "goto " (form 1)))
      (do (emit-indent) (emit-statement form) (print ";")))
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
    [& args]
    (print "#" (string/join (map string args) " ")))
 
  (setfn emit-top
    [form]
    (case (get form 0)
      'defn (if (indexed? (form 1))
              (emit-function (form 1) (form 2) (form 3) (form 4) (slice form 5))
              (emit-function [] (form 1) (form 2) (form 3) (slice form 4)))
      'deft (do (print) (emit-typedef (form 1) (form 2)))
      'def (do (print)
             (if (indexed? (form 1))
               (do
                 (emit-storage-classes (form 1))
                 (emit-declaration (form 2) (form 3) (form 4)) (print ";"))
               (emit-declaration (form 1) (form 2) (form 3) (print ";"))))
      'directive (emit-directive ;(slice form 1))
      '@ (emit-directive ;(slice form 1))
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
