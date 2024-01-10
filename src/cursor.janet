(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(import ./view)

(use ./util)


(defn- handle-motion [cursor listener data]
  (def event (get-abstract-listener-data data 'wlr/wlr-pointer-motion-event))
  (:move cursor :relative
     (>: event :pointer :base)
     (event :delta-x)
     (event :delta-y)
     (event :time-msec)))

(defn- handle-motion-absolute [cursor listener data]
  (def event (get-abstract-listener-data data 'wlr/wlr-pointer-motion-absolute-event))
  (:move cursor :absolute
     (>: event :pointer :base)
     (event :x)
     (event :y)
     (event :time-msec)))

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

  (put self :mode :passthrough)
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


(defn- move [self mode device x y time]
  (case mode
    :relative (wlr-cursor-move (self :base) device x y)
    :absolute (wlr-cursor-warp-absolute (self :base) device x y))

  (case (self :mode)

    :move-view
    (do (def view (self :grabbed-view))
        (:move view
               (math/round (- (>: self :base :x) (self :grab-x)))
               (math/round (- (>: self :base :y) (self :grab-y)))))

    :resize-view
    (do  (def view (self :grabbed-view))
         (def border-x (- (>: self :base :x) (self :grab-x)))
         (def border-y (- (>: self :base :y) (self :grab-y)))
         (var new-left (>: self :grab-box :x))
         (var new-right (+ (>: self :grab-box :x) (>: self :grab-box :width)))
         (var new-top (>: self :grab-box :y))
         (var new-bottom (+ (>: self :grab-box :y) (>: self :grab-box :height)))
         (def edges (self :resize-edges))

         (cond
           (contains? edges :top)
           (do
             (set new-top border-y)
             (when (>= new-top new-bottom)
               (set new-top (- new-bottom 1))))

           (contains? edges :bottom)
           (do
             (set new-bottom border-y)
             (when (<= new-bottom new-top)
               (set new-bottom (+ new-top 1)))))

         (cond
           (contains? edges :left)
           (do
             (set new-left border-x)
             (when (>= new-left new-right)
               (set new-left (- new-right 1))))

           (contains? edges :right)
           (do
             (set new-right border-x)
             (when (<= new-right new-left)
               (set new-right (+ new-left 1)))))

         (def geo-box (:get-geometry view))
         (:move view
                (math/round (- new-left (geo-box :x)))
                (math/round (- new-top (geo-box :y)))
                (math/round (- new-right new-left))
                (math/round (- new-bottom new-top))))

    :passthrough
    (do (def wlr-seat (>: self :server :seat :base))
        (def [view sx sy] (view/at (self :server) (>: self :base :x) (>: self :base :y)))
        (if (nil? view)
          (do (wlr-xcursor-manager-set-cursor-image (self :xcursor-manager) "left_ptr" (self :base))
              (wlr-seat-pointer-clear-focus wlr-seat))
          (do (wlr-seat-pointer-notify-enter wlr-seat (>: view :surface :wlr-surface) sx sy)
              (wlr-seat-pointer-notify-motion wlr-seat time sx sy))))))


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(def- proto
  @{:move move
    :destroy destroy})


(defn create [server]
  (init (table/setproto @{} proto) server))
