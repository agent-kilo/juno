(use janetland/wl)
(use janetland/wlr)

(use ./util)


(defn- init [self backend device]
  (put self :device device)
  (put self :server (backend :server))
  (put self :listeners @{})
  (wlr-cursor-attach-input-device (>: backend :server :cursor :base) device)
  self)


(def- proto @{})


(defn create [backend device]
  (init (table/setproto @{} proto) backend device))
