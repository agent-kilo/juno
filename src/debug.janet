(use janetland/wlr)
(use janetland/util)

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
  "Show info about the specified wlroots scene node and all its descendants.\n"
  (dump-scene-tree-impl node "" "  "))


(defn dump-scene-tree [tree]
  "Show info about the specified wlroots scene tree and all its descendants.\n"
  (dump-scene-node (tree :node)))


(defn node-at-cursor [server]
  (def x (>: server :cursor :base :x))
  (def y (>: server :cursor :base :y))
  (:get-node-at (>: server :scene) x y))


(defn surface-at-cursor [server]
  (def x (>: server :cursor :base :x))
  (def y (>: server :cursor :base :y))
  (:get-surface-at (>: server :scene) x y))
