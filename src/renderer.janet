(use janetland/wl)
(use janetland/wlr)

(use ./util)


(defn- init [self server]
  (def wlr-renderer (wlr-renderer-autocreate (>: server :backend :base)))

  (put self :base wlr-renderer)
  (put self :server server)

  (if-not (wlr-renderer-init-wl-display (self :base) (server :display))
    (error "wlr-renderer-init-wl-display failed"))

  self)


(def- proto @{})


(defn create [server]
  (init (table/setproto @{} proto) server))
