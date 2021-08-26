###
### Test that the installation works correctly.
###

(import /jpm/shutil)

(os/cd "testinstall")
(defer (os/cd "..")
  (os/execute [(dyn :executable) "runtest.janet"] :px))
