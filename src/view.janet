(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- grab [self mode edges]
  (def server (self :server))
  (def cursor (server :cursor))
  (def focused-surface (>: server :seat :base :pointer-state :focused-surface))

  (def view-surface (>: self :surface :wlr-surface))
  (if-not (= view-surface (wlr-surface-get-root-surface focused-surface))
    (break))

  (put cursor :grabbed-view self)
  (put cursor :mode mode)

  (case mode
    :move-view
    (do
      (put cursor :grab-x (- (>: cursor :base :x) (self :x)))
      (put cursor :grab-y (- (>: cursor :base :y) (self :y))))

    :resize-view
    (do
      (def geo-box (:get-geometry self))
      (def border-x (+ (self :x) (geo-box :x)
                       (if (contains? edges :right) (geo-box :width) 0)))
      (def border-y (+ (self :y) (geo-box :y)
                       (if (contains? edges :bottom) (geo-box :height) 0)))
      (put cursor :grab-x (- (>: cursor :base :x) border-x))
      (put server :grab-y (- (>: cursor :base :y) border-y))
      (+= (geo-box :x) (self :x))
      (+= (geo-box :y) (self :y))
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


(defn- request-move [self data]
  (when (:request-move (self :surface))
    (:grab self :move-view [])))


(defn- request-resize [self data]
  (when-let [edges (:request-resize (self :surface) data)]
    (:grab self :resize-view edges)))


(defn- get-geometry [self]
  (:get-geometry (self :surface)))


(defn- move [self x y &opt width height]
  (put self :x x)
  (put self :y y)
  (wlr-scene-node-set-position (>: self :scene-tree :node) x y)
  (:move (self :surface) x y width height))


(defn- set-activated [self activated]
  (when activated
    (wlr-scene-node-raise-to-top (>: self :scene-tree :node)))
  (:set-activated (self :surface) activated))


(defn- focus [self]
  (def server (self :server))
  (def surface (self :surface))
  (def seat (server :seat))
  (def prev-surface (>: seat :base :keyboard-state :focused-surface))

  (when (= prev-surface (surface :wlr-surface))
    (break))

  (if-not (nil? prev-surface)
    (do (def prev-view (in (pointer-to-table (prev-surface :data)) :view))
        (:set-activated prev-view false)))

  (:set-activated self true)

  (def keyboard (wlr-seat-get-keyboard (seat :base)))
  (if-not (nil? keyboard)
    (wlr-seat-keyboard-notify-enter (seat :base)
                                    (surface :wlr-surface)
                                    (keyboard :keycodes)
                                    (keyboard :modifiers)))

  # Move the view to the front of the list, if it's focusable
  (when (contains? (server :views) self)
    (remove-element (server :views) self)
    (array/push (server :views) self)))


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
    :get-geometry get-geometry
    :move move
    :set-activated set-activated
    :focus focus
    :grab grab})


(defn create [surface scene-tree server]
  (init (table/setproto @{} proto) surface scene-tree server))


(defn at [server x y]
  (def [node sx sy] (wlr-scene-node-at (>: server :scene :base :tree :node) x y))
  (when (or (nil? node) (not (= (node :type) :buffer)))
    (break [nil 0 0]))

  (def scene-buffer (wlr-scene-buffer-from-node node))
  (def scene-surface (wlr-scene-surface-from-buffer scene-buffer))
  (when (nil? scene-surface)
    (break [nil 0 0]))

  (def wlr-surface (scene-surface :surface))
  (when (or (nil? wlr-surface) (nil? (wlr-surface :data)))
    (break [nil 0 0]))

  (def surface (pointer-to-table (wlr-surface :data)))
  [(surface :view) sx sy])
