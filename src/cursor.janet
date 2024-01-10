(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- handle-motion [cursor listener data]
  # TODO
  )

(defn- handle-motion-absolute [cursor listener data]
  # TODO
  )

(defn- handle-button [cursor listener data]
  # TODO
  )

(defn- handle-axis [cursor listener data]
  # TODO
  )

(defn- handle-frame [cursor listener data]
  # TODO
  )


(defn- init [self server]
  (put self :base (wlr-cursor-create))
  (put self :server server)

  (put self :mode :passthrough) # TODO
  (put self :grabbed-view nil)
  (put self :grab-box nil)
  (put self :grabb-x 0)
  (put self :grabb-y 0)
  (put self :resize-edges [])

  (put self :listeners @{})

  # TODO: cursor config?
  (put self :xcursor-manager (wlr-xcursor-manager-create nil 24))
  (if-not (wlr-xcursor-manager-load (self :xcursor-manager) 1)
    (error "wlr-xcursor-manager-load failed"))

  (wlr-cursor-attach-output-layout (self :base) (server :output-layout))

  (put (self :listeners) :motion
     (wl-signal-add (>: self :base :events.motion)
                    (fn [listener data]
                      (handle-motion self listener data))))
  (put (self :listeners) :motion_absolute
     (wl-signal-add (>: self :base :events.motion_absolute)
                    (fn [listener data]
                      (handle-motion-absolute self listener data))))
  (put (self :listeners) :button
     (wl-signal-add (>: self :base :events.button)
                    (fn [listener data]
                      (handle-button self listener data))))
  (put (self :listeners) :axis
     (wl-signal-add (>: self :base :events.axis)
                    (fn [listener data]
                      (handle-axis self listener data))))
  (put (self :listeners) :frame
     (wl-signal-add (>: self :base :events.frame)
                    (fn [listener data]
                      (handle-frame self listener data))))

  self)


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(def- proto
  @{:destroy destroy})


(defn create [server]
  (init (table/setproto @{} proto) server))
