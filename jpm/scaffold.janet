###
### Project scaffolding
###
### Generate new projects quickly.
###

(def- template-peg
  "Extract string pieces to generate a templating function"
  (peg/compile
    ~{:sub (group
             (+ (* "${" '(to "}") "}")
                (* "$" '(some (range "az" "AZ" "09" "__" "--")))))
      :main (any (* '(to (+ "$$" -1 :sub)) (+ '"$$" :sub 0)))}))

(defn- make-template
  "Make a simple string template as defined by Python PEP292 (shell-like $ substitution).
  Also allows dashes in indentifiers."
  [source]
  (def frags (peg/match template-peg source))
  (def partitions (partition-by type frags))
  (def string-args @[])
  (each chunk partitions
    (case (type (get chunk 0))
      :string (array/push string-args (string ;chunk))
      :array (each sym chunk
               (array/push string-args ~(,get opts ,(keyword (first sym)))))))
  ~(fn [opts] (,string ,;string-args)))

(defmacro- deftemplate
  "Define a template inline"
  [template-name body]
  ~(def ,template-name :private ,(make-template body)))

(defn- opt-ask
  "Ask user for input"
  [key input-options]
  (def dflt (get input-options key))
  (if (nil? dflt)
    (string/trim (getline (string key "? ")))
    dflt))

(deftemplate project-template
  ````
  (declare-project
    :name "$name"
    :description ```$description ```
    :version "0.0.0")

  (declare-source
    :prefix "$name"
    :source ["src/init.janet"])
  ````)

(deftemplate native-project-template
  ````
  (declare-project
    :name "$name"
    :description ```$description ```
    :version "0.0.0")

  (declare-source
    :prefix "$name"
    :source ["$name/init.janet"])

  (declare-native
    :name "${name}-native"
    :source @["c/module.c"])
  ````)

(deftemplate module-c-template
  ```
  #include <janet.h>

  /***************/
  /* C Functions */
  /***************/

  JANET_FN(cfun_hello_native,
           "($name/hello-native)",
           "Evaluate to \"Hello!\". but implemented in C.") {
      janet_fixarity(argc, 0);
      (void) argv;
      return janet_cstringv("Hello!");
  }

  /****************/
  /* Module Entry */
  /****************/

  JANET_MODULE_ENTRY(JanetTable *env) {
      JanetRegExt cfuns[] = {
          JANET_REG("hello-native", cfun_hello_native),
          JANET_REG_END
      };
      janet_cfuns_ext(env, "$name", cfuns);
  }
  ```)

(deftemplate exe-project-template
  ````
  (declare-project
    :name "$name"
    :description ```$description ```
    :version "0.0.0")

  (declare-executable
    :name "$name"
    :entry "$name/init.janet")
  ````)

(deftemplate readme-template
  ```
  # ${name}

  Add project description here.
  ```)

(deftemplate changelog-template
  ```
  # Changelog
  All notable changes to this project will be documented in this file.
  Format for entires is <version-string> - release date.

  ## 0.0.0 - $date
  - Created this project.
  ```)

(deftemplate license-template
  ```
  Copyright (c) $year $author and contributors

  Permission is hereby granted, free of charge, to any person obtaining a copy of
  this software and associated documentation files (the "Software"), to deal in
  the Software without restriction, including without limitation the rights to
  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
  of the Software, and to permit persons to whom the Software is furnished to do
  so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
  ```)

(deftemplate init-template
  ```
  (defn hello
    `Evaluates to "Hello!"`
    []
    "Hello!")

  (defn main
    [& args]
    (print (hello)))
  ```)

(deftemplate test-template
  ```
  (use ../$name/init)

  (assert (= (hello) "Hello!"))
  ```)

(deftemplate native-test-template
  ```
  (use ${name}-native)

  (assert (= (hello-native) "Hello!"))
  ```)

(defn- format-date
  []
  (def x (os/date))
  (string/format "%d-%.2d-%.2d" (x :year) (inc (x :month)) (inc (x :month-day))))

(defn scaffold-project
  "Generate a standardized project scaffold."
  [name &opt options]
  (default options {})
  (def year (get (os/date) :year))
  (def author (opt-ask :author options))
  (def description (opt-ask :description options))
  (def date (format-date))
  (def scaffold-native (get options :c))
  (def scaffold-exe (get options :exe))
  (def template-opts (merge-into @{:name name :year year :author author :date date :description description} options))
  (print "creating project directory for " name)
  (os/mkdir name)
  (os/mkdir (string name "/test"))
  (os/mkdir (string name "/" name))
  (os/mkdir (string name "/bin"))
  (spit (string name "/" name "/init.janet") (init-template template-opts))
  (spit (string name "/test/basic.janet") (test-template template-opts))
  (spit (string name "/README.md") (readme-template template-opts))
  (spit (string name "/LICENSE") (license-template template-opts))
  (spit (string name "/CHANGELOG.md") (changelog-template template-opts))
  (cond
    scaffold-native
    (do
      (os/mkdir (string name "/c"))
      (spit (string name "/c/module.c") (module-c-template template-opts))
      (spit (string name "/test/native.janet") (native-test-template template-opts))
      (spit (string name "/project.janet") (native-project-template template-opts)))
    scaffold-exe
    (do
      (spit (string name "/project.janet") (exe-project-template template-opts)))
    (do
      (spit (string name "/project.janet") (project-template template-opts)))))
