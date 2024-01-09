(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- begin-interactive [view mode edges]
  # TODO
  )


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
    (begin-interactive view :move [])))


(defn- request-resize [view data]
  (when-let [edges (:request-resize (view :surface data))]
    (begin-interactive view :resize edges)))


(defn- focus [view]
  # TODO
  )


(defn- init [self surface scene-tree server]
  (put self :surface surface)
  (put self :scene-tree scene-tree)
  (put self :server server)
  (put self :x 0)
  (put self :y 0)
  self)


(def- proto
  @{:map map
    :unmap unmap
    :destroy destroy
    :request-move request-move
    :request-resize request-resize
    :focus focus})


(defn create [surface scene-tree server]
  (init (table/setproto @{} proto) surface scene-tree server))
