(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- grab [view mode edges]
  (def server (view :server))
  (def cursor (server :cursor))
  (def focused-surface (>: server :seat :base :pointer-state :focused-surface))

  (def view-surface (>: view :surface :wlr-surface))
  (if-not (= view-surface (wlr-surface-get-root-surface focused-surface))
    (break))

  (put cursor :grabbed-view view)
  (put cursor :mode mode)

  (case mode
    :move
    (do
      (put cursor :grab-x (- (>: cursor :base :x) (view :x)))
      (put cursor :grab-y (- (>: cursor :base :y) (view :y))))

    :resize
    (do
      (def geo-box (:get-box view))
      (def border-x (+ (view :x) (geo-box :x)
                       (if (contains? edges :right) (geo-box :width) 0)))
      (def border-y (+ (view :y) (geo-box :y)
                       (if (contains? edges :bottom) (geo-box :height) 0)))
      (put cursor :grab-x (- (>: cursor :base :x) border-x))
      (put server :grab-y (- (>: cursor :base :y) border-y))
      (+= (geo-box :x) (view :x))
      (+= (geo-box :y) (view :y))
      (put cursor :grab-box geo-box)
      (put cursor :resize-edges edges))))


(defn- map [self]
  (array/push (>: self :server :views) self)
  (:map (self :surface))
  (when (:wants-focus (self :surface))
    (:focus self)))


(defn- unmap [self]
  (:unmap (self :surface))
  (def views (>: self :server :views))
  (remove-element views self)
  (when (> (length views) 0)
    (def next-view (views (- (length views) 1)))
    (:focus next-view)))


(defn- destroy [self]
  (:destroy (self :surface)))


(defn- request-move [view data]
  (when (:request-move (view :surface))
    (:grab view :move [])))


(defn- request-resize [view data]
  (when-let [edges (:request-resize (view :surface data))]
    (:grab view :resize edges)))


(defn- set-activated [view activated]
  (when activated
    (wlr-scene-node-raise-to-top (>: view :scene-tree :node)))
  (:set-activated (view :surface) activated))


(defn- focus [view]
  (def server (view :server))
  (def surface (view :surface))
  (def seat (server :seat))
  (def prev-surface (>: seat :base :keyboard-state :focused-surface))

  (when (= prev-surface (surface :wlr-surface))
    (break))

  (if-not (nil? prev-surface)
    (do (def prev-view (in (pointer-to-table (prev-surface :data)) :view))
        (:set-activated prev-view false)))

  (:set-activated view true)

  (def keyboard (wlr-seat-get-keyboard (seat :base)))
  (if-not (nil? keyboard)
    (wlr-seat-keyboard-notify-enter (seat :base)
                                    (surface :wlr-surface)
                                    (keyboard :keycodes)
                                    (keyboard :modifiers)))

  # Move the view to the front of the list, if it's focusable
  (when (contains? (server :views) view)
    (remove-element (server :views) view)
    (array/push (server :views) view)))


(defn- init [self surface scene-tree server]
  (put self :surface surface)
  (put self :scene-tree scene-tree)
  (put self :server server)
  (put self :x 0)
  (put self :y 0)
  (put surface :view self)
  self)


(def- proto
  @{:map map
    :unmap unmap
    :destroy destroy
    :request-move request-move
    :request-resize request-resize
    :set-activated set-activated
    :focus focus
    :grab grab})


(defn create [surface scene-tree server]
  (init (table/setproto @{} proto) surface scene-tree server))
