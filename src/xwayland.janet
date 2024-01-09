(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- handle-ready [xwayland listener data]
  # TODO
  )


(defn- handle-new-surface [xwayland listener data]
  # TODO
  )


(defn- init [self server]
  # TODO: lazy-load config
  (def wlr-xwayland (wlr-xwayland-create (>: server :display :base) (server :compositor) false))

  (put self :base wlr-xwayland)
  (put self :server server)
  (put self :listeners @{})

  (put (self :listeners) :ready
     (wl-signal-add (>: self :base :events.ready)
                    (fn [listener data]
                      (handle-ready self listener data))))
  (put (self :listeners) :new_surface
     (wl-signal-add (>: self :base :events.new_surface)
                    (fn [listener data]
                      (handle-new-surface self listener data))))

  self)


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener))
  (wlr-xwayland-destroy (self :base)))


(def- proto
  @{:destroy destroy})


(defn create [server]
  (init (table/setproto @{} proto) server))
