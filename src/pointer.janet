(use janetland/wl)
(use janetland/wlr)

(use ./util)


(defn- handle-pointer-destroy [pointer listener data]
  (:destroy pointer)
  (:remove-input (>: pointer :server :backend) pointer))


(defn- init [self backend device]
  (put self :device device)
  (put self :server (backend :server))
  (put self :listeners @{})

  (wlr-cursor-attach-input-device (>: backend :server :cursor :base) device)

  (put (self :listeners) :destroy
     (wl-signal-add (>: self :device :events.destroy)
                    (fn [listener data]
                      (handle-pointer-destroy self listener data))))

  self)


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(def- proto
  @{:destroy destroy})


(defn create [backend device]
  (init (table/setproto @{} proto) backend device))
