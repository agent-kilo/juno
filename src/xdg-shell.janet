(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- handle-new-surface [xdg-shell listener data]
  (def wlr-xdg-surface (get-abstract-listener-data data 'wlr/wlr-xdg-surface))
  # TODO: create xdg view
  )


(defn- init [self server]
  (def wlr-xdg-shell (wlr-xdg-shell-create (server :display) 3)) # version = 3

  (put self :base wlr-xdg-shell)
  (put self :server server)
  (put self :listeners @{})

  (put (self :listeners) :new_surface
     (wl-signal-add (>: self :base :events.new_surface)
                    (fn [listener data]
                      (handle-new-surface self listener data))))

  self)


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(def- proto
  @{:destroy destroy})


(defn create [server]
  (init (table/setproto @{} proto) server))
