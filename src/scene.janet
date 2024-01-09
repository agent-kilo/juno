(use janetland/wl)
(use janetland/wlr)

(use ./util)


(defn- init [self server]
  (def wlr-scene (wlr-scene-create))

  (put self :base wlr-scene)
  (put self :server server)

  (if-not (wlr-scene-attach-output-layout (self :base) (server :output-layout))
    (error "wlr-scene-attach-output-layout failed"))

  self)


(def- proto @{})


(defn create [server]
  (init (table/setproto @{} proto) server))
