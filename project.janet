(declare-project
 :name "Juno"
 :description "A Wayland compositor built with Janet & wlroots."
 :dependencies [{:url (string "file://" (os/getenv "HOME") "/w/wl/janetland.tar.gz")
                 :type :tar}
                {:url "https://github.com/janet-lang/spork.git"
                 :tag "d644da0fd05612a2d5a3c97277bf7b9bb96dcf6b"}])


(defn spawn-and-wait [& args]
  (def os-env (os/environ))
  (put os-env :out :pipe)
  (def proc (os/spawn args :ep os-env))
  (os/proc-wait proc)
  (def out (in proc :out))
  (def ret (in proc :return-code))
  (when (not (= ret 0))
    (error (string/format "subprocess exited abnormally: %d" ret)))
  (:read out :all))

(defn pkg-config [& args]
  (string/trim (spawn-and-wait "pkg-config" ;args)))


(def wlr-cflags
  (let [arr @[]]
    (array/concat
     arr
     @["-DWLR_USE_UNSTABLE"]
     (string/split " " (pkg-config "--libs" "wlroots"))
     (string/split " " (pkg-config "--libs" "wayland-server"))
     (string/split " " (pkg-config "--libs" "xkbcommon"))
     (string/split " " (pkg-config "--libs" "xcb")))))

(def common-cflags ["-g" "-Wall" "-Wextra"])


(declare-executable
 :name "juno"
 :entry "src/main.janet"
 :cflags [;common-cflags ;wlr-cflags])
