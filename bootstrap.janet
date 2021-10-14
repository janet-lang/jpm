#!/usr/bin/env janet

# A script to install jpm to a given tree. This script can be run during installation
# time and will try to autodetect the host platform and generate the correct config file
# for installation and then install jpm

(import ./jpm/shutil)
(import ./jpm/make-config)

(def destdir (os/getenv "DESTDIR"))
(defn do-bootstrap
  [conf]
  (print "destdir: " destdir)
  (print "Running jpm to self install...")
  (os/execute [(dyn :executable) "jpm/cli.janet" "install" ;(if destdir [(string "--dest-dir=" destdir)] [])]
              :epx
              (merge-into (os/environ)
                          {"JPM_BOOTSTRAP_CONFIG" conf
                           "JANET_JPM_CONFIG" conf})))

(when-let [override-config (get (dyn :args) 1)]
  (do-bootstrap override-config)
  (os/exit 0))

(def temp-config-path "./temp-config.janet")
(spit temp-config-path (make-config/generate-config (or destdir "")))
(do-bootstrap temp-config-path)
(os/rm temp-config-path)
