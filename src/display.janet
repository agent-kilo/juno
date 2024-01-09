(use janetland/wl)
(use janetland/wlr)

(use ./util)


(defn- init [self server]
  (put self :base (wl-display-create))
  (put self :event-loop (wl-display-get-event-loop (self :base)))
  (put self :event-loop-stream (wl-event-loop-fd-to-stream (wl-event-loop-get-fd (self :event-loop))))
  (put self :server server)
  (put self :socket (wl-display-add-socket-auto (self :base)))
  self)


(defn- destroy [self]
  (wl-display-destroy (self :base)))


(def- proto
  @{:destroy destroy})


(defn create [server]
  (init (table/setproto @{} proto) server))
