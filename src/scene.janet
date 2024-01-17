(use janetland/wl)
(use janetland/wlr)

(use ./util)


(defn- init [self server]
  (def wlr-scene (wlr-scene-create))

  (put self :base wlr-scene)
  (put self :server server)

  (if-not (wlr-scene-attach-output-layout (self :base)
                                          (>: server :output-layout :base))
    (error "wlr-scene-attach-output-layout failed"))

  self)


(defn- get-node-at [self x y]
  (wlr-scene-node-at (>: self :base :tree :node) x y))


(defn- get-surface-at [self x y]
  (def [node sx sy] (wlr-scene-node-at (>: self :base :tree :node) x y))
  (when (or (nil? node) (not (= (node :type) :buffer)))
    (break [nil 0 0]))
  (def scene-buffer (wlr-scene-buffer-from-node node))
  (def scene-surface (wlr-scene-surface-from-buffer scene-buffer))
  (when (nil? scene-surface)
    (break [nil 0 0]))
  [(scene-surface :surface) sx sy])


(def- proto
  @{:get-node-at get-node-at
    :get-surface-at get-surface-at})


(defn create [server]
  (init (table/setproto @{} proto) server))
