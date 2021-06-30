###
### Test that the installation works correctly.
###

(import ../cli)
(import ../commands)
(import ../shutil)
(import ../default-config)
(import ../config)

(cli/setup [])

(commands/clean)
(commands/build)
(shutil/shell "build/testexec")
(commands/quickbin "testexec.janet" (string "build/testexec2" (if (= :windows (os/which)) ".exe")))
(shutil/shell "build/testexec2")
(os/mkdir "modpath")
(setdyn :modpath (string (os/cwd) "/modpath"))
(setdyn :test true)
(commands/install "https://github.com/janet-lang/json.git")
(commands/install "https://github.com/janet-lang/path.git")
(commands/install "https://github.com/janet-lang/argparse.git")
