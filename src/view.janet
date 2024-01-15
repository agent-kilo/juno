(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)

#
# Data fields used here:
#   wlr-scene-node (tree) data  -> juno view object
#   wlr-surface data -> juno surface object
#


#
# Views use layout coordinates, this function converts view
# coordinates to scene node local coordinates (relative to parent-tree).
#
(defn to-local-coords [x y parent-tree]
  (var local-x x)
  (var local-y y)
  (var ptree parent-tree)
  (while (not (nil? ptree))
    (-= local-x (>: ptree :node :x))
    (-= local-y (>: ptree :node :y))
    (set ptree (>: ptree :node :parent)))
  [local-x local-y])


(defn- grab [self mode edges]
  (def server (self :server))
  (def cursor (server :cursor))
  (def focused-surface (:get-pointer-focused-surface (server :seat)))
  (def view-surface (>: self :surface :wlr-surface))
  (if (= view-surface (wlr-surface-get-root-surface focused-surface))
    (:grab cursor self mode edges)))


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
  (when (:request-move (self :surface) data)
    (:grab self :move-view [])))


(defn- request-resize [self data]
  (when-let [edges (:request-resize (self :surface) data)]
    (:grab self :resize-view edges)))


(defn- get-geometry [self]
  (def geo-box (:get-geometry (self :surface)))
  # Coordinates from the surface may be offsetted from the scene node
  # We always set the coordinates to the same as scene node coordinates
  # since that's where our view is, conceptually.
  (set (geo-box :x) (self :x))
  (set (geo-box :y) (self :y))
  geo-box)


(defn- move [self x y &opt width height]
  (put self :x x)
  (put self :y y)
  (def [local-x local-y] (to-local-coords x y (>: self :scene-tree :node :parent)))
  (wlr-scene-node-set-position (>: self :scene-tree :node) local-x local-y)
  (:move (self :surface) x y width height))


(defn- set-activated [self activated]
  (when activated
    (wlr-scene-node-raise-to-top (>: self :scene-tree :node)))
  (:set-activated (self :surface) activated))


(defn- set-maximized [self maximized]
  (:set-maximized (self :surface) maximized))


(defn- set-fullscreen [self fullscreen]
  (:set-fullscreen (self :surface) fullscreen))


(defn- focus [self]
  (def server (self :server))
  (def surface (self :surface))
  (def seat (server :seat))
  (def prev-surface (>: seat :base :keyboard-state :focused-surface))

  (when (= prev-surface (surface :wlr-surface))
    (break))

  (if-not (nil? prev-surface)
    (do (def prev-view ((pointer-to-table (prev-surface :data)) :view))
        (:set-activated prev-view false)))
  (:set-activated self true)

  (:keyboard-enter-event seat (surface :wlr-surface))

  # Move the view to the front of the list, if it's focusable
  (when (contains? (server :views) self)
    (remove-element (server :views) self)
    (array/push (server :views) self)))


(defn- init [self surface scene-tree server]
  (put self :surface surface)
  (put self :scene-tree scene-tree)
  (set ((scene-tree :node) :data) self)
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
    :set-maximized set-maximized
    :set-fullscreen set-fullscreen
    :focus focus
    :grab grab})


(defn create [surface scene-tree server]
  (init (table/setproto @{} proto) surface scene-tree server))


(defn at [scene x y]
  (def [node sx sy] (:get-node-at scene x y))
  (when (nil? node)
    (break [nil 0 0]))

  (var tree (node :parent))
  (while (and (not (nil? tree)) (nil? (>: tree :node :data)))
    (set tree (>: tree :node :parent)))
  (when (nil? tree)
    (break [nil 0 0]))

  (def view (pointer-to-table (>: tree :node :data)))
  [view sx sy])
