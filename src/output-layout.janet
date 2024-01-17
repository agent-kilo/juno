(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- init [self server]
  (put self :base (wlr-output-layout-create))
  (put self :server server)
  self)


(def- proto @{})


(defn create [server]
  (init (table/setproto @{} proto) server))
