(use janetland/wlr)
(use janetland/util)

(import ./view)

(use ./util)


(defn- show-surface [surface]
  (if (nil? surface)
    ""
    (do
      (def data-table
        (if-let [data (surface :data)]
          (pointer-to-table data)
          nil))
      (def [surface-type geo]
        (cond
          (wlr-surface-is-xdg-surface surface)
          (do
            (def xdg-surface (wlr-xdg-surface-from-wlr-surface surface))
            [:xdg (wlr-xdg-surface-get-geometry xdg-surface)])

          (wlr-surface-is-xwayland-surface surface)
          (do
            [:xwayland (box :width (>: surface :current :width)
                            :height (>: surface :current :height))])
          [:none nil]))
      (def dim-desc
        (string/format "(%d,%d,%d,%d)"
                       (>: surface :current :dx)
                       (>: surface :current :dy)
                       (>: surface :current :width)
                       (>: surface :current :height)))
      (def geo-desc
        (if geo
          (string/format "(%d,%d,%d,%d) " (geo :x) (geo :y) (geo :width) (geo :height))
          ""))
      (string/format "(%v %s %v %s%v)" surface dim-desc surface-type geo-desc data-table))))


(defn- show-node [node]
  (def node-data
    (if-let [data (node :data)]
      (pointer-to-table data)
      nil))

  (string/format "[%v %v (%d, %d) %s %v]"
                 (node :type)
                 node
                 (node :x)
                 (node :y)
                 (if (node :enabled) "+" "-")
                 node-data))


(defn- dump-scene-tree-impl [node indent indent-char]
  (def wlr-surface
    (if (= (node :type) :buffer)
      (do (def scene-buffer (wlr-scene-buffer-from-node node))
          (def scene-surface (wlr-scene-surface-from-buffer scene-buffer))
          (if (nil? scene-surface)
            nil
            (scene-surface :surface)))
      nil))

  (def surface-desc (show-surface wlr-surface))

  (printf "%s%s%s%s"
          indent
          (show-node node)
          (if (> (length surface-desc) 0) " => " "")
          surface-desc)

  (case (node :type)
    :tree (do
            (def tree (wlr-scene-tree-from-node node))
            (each n (wl-list-to-array (tree :children) 'wlr/wlr-scene-node :link)
              (dump-scene-tree-impl n (string indent indent-char) indent-char)))))


(defn dump-scene-node [node]
  "Shows info about the specified wlroots scene node and all its descendants.\n"
  (dump-scene-tree-impl node "" "  "))


(defn dump-scene-tree [tree]
  "Shows info about the specified wlroots scene tree and all its descendants.\n"
  (dump-scene-node (tree :node)))


(defn node-at-cursor [server]
  "Retrieves the wlroots scene node at current cursor position.\n"
  (def x (>: server :cursor :base :x))
  (def y (>: server :cursor :base :y))
  (:get-node-at (>: server :scene) x y))


(defn surface-at-cursor [server]
  "Retrieves the wlroots surface at current cursor position.\n"
  (def x (>: server :cursor :base :x))
  (def y (>: server :cursor :base :y))
  (:get-surface-at (>: server :scene) x y))


(defn view-at-cursor [server]
  "Retrieves the view object at current cursor position.\n"
  (def x (>: server :cursor :base :x))
  (def y (>: server :cursor :base :y))
  (view/at (server :scene) x y))


(defn dump-scene-node-at-cursor [server]
  "Shows info about the wlroots scene node and all its descendants at current cursor position.\n"
  (def [node _x _y] (node-at-cursor server))
  (if (nil? node)
    (printf "No scene node at (%v, %v)"
            (>: server :cursor :base :x)
            (>: server :cursor :base :y))
    (dump-scene-node node)))


(defn dump-scene-tree-at-cursor [server]
  "Shows info about the wlroots scene tree and all its descendants at current cursor position.\n"
  (def [view _x _y] (view-at-cursor server))
  (if (nil? view)
    (printf "No view at (%v, %v)"
            (>: server :cursor :base :x)
            (>: server :cursor :base :y))
    (dump-scene-tree (view :scene-tree))))
