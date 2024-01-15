(use janetland/wl)
(use janetland/wlr)
(use janetland/xcb)
(use janetland/util)

(import ./view)

(use ./util)


(defn- surface-map [self])
(defn- surface-unmap [self])


(defn- surface-destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(defn- surface-request-move [self event]
  (>: self :base :mapped))


(defn- surface-request-resize [self event]
  (when (>: self :base :mapped)
    (event :edges)))


(defn- surface-get-geometry [self]
  (box :width (>: self :wlr-surface :current :width)
       :height (>: self :wlr-surface :current :height)))


(defn- surface-move [self x y &opt width height]
  (if (or (nil? width) (nil? height))
    (wlr-xwayland-surface-configure (self :base) x y
                                    (>: self :wlr-surface :current :width)
                                    (>: self :wlr-surface :current :height))
    (wlr-xwayland-surface-configure (self :base) x y width height)))


(defn- surface-wants-focus [self]
  (wlr-xwayland-or-surface-wants-focus (self :base)))


(defn- surface-set-activated [self activated]
  (def xw-surface (self :base))
  (if activated
    (wlr-xwayland-surface-restack xw-surface nil :above))
  (wlr-xwayland-surface-activate xw-surface activated))


(def- surface-proto
  @{:map surface-map
    :unmap surface-unmap
    :destroy surface-destroy
    :request-move surface-request-move
    :request-resize surface-request-resize
    :get-geometry surface-get-geometry
    :move surface-move
    :wants-focus surface-wants-focus
    :set-activated surface-set-activated})


(defn- scene-surface-create [parent xw-surface]
  (def [tree parent-tree]
    (if-let [data (xw-surface :data)]
      (do
        # Reuse the tree we created when this surface got mapped for the first time.
        (def old-tree (pointer-to-abstract-object data 'wlr/wlr-scene-tree))
        [old-tree (>: old-tree :node :parent)])
      [(wlr-scene-tree-create parent) parent]))

  # The subsurface tree will be destroyed when the surface is unmapped,
  # need to create it again, event if this surface had been mapped before.
  (def surface-tree (wlr-scene-subsurface-tree-create tree (xw-surface :surface)))

  # Only bind the events when we created a new tree node.
  (when (nil? (xw-surface :data))
    (def scene-xw-surface
      @{:xw-surface xw-surface
        :tree tree
        :listeners @{}})

    (put (scene-xw-surface :listeners) :tree-destroy
       (wl-signal-add (>: tree :node :events.destroy)
                      (fn [listener data]
                        (eachp [_ listener] (scene-xw-surface :listeners)
                          (wl-signal-remove listener)))))
    (put (scene-xw-surface :listeners) :surface-destroy
       (wl-signal-add (xw-surface :events.destroy)
                      (fn [listener data]
                        (wlr-scene-node-destroy (>: scene-xw-surface :tree :node)))))
    (put (scene-xw-surface :listeners) :surface-map
       (wl-signal-add (xw-surface :events.map)
                      (fn [listener data]
                        (wlr-scene-node-set-enabled (>: scene-xw-surface :tree :node) true))))
    (put (scene-xw-surface :listeners) :surface-unmap
       (wl-signal-add (xw-surface :events.unmap)
                      (fn [listener data]
                        (wlr-scene-node-set-enabled (>: scene-xw-surface :tree :node) false)))))

  (wlr-scene-node-set-enabled (tree :node) (xw-surface :mapped))
  (def [local-x local-y] (view/to-local-coords (xw-surface :x) (xw-surface :y) parent-tree))
  (wlr-scene-node-set-position (tree :node) local-x local-y)

  tree)


(defn- handle-surface-map [surface listener data]
  (put surface :wlr-surface (>: surface :base :surface))
  (set ((surface :wlr-surface) :data) surface)

  (def xw-surface (surface :base))
  (def xw-parent (xw-surface :parent))
  (def parent-tree
    (if (nil? xw-parent)
      (>: surface :xwayland :server :scene :base :tree)
      (pointer-to-abstract-object (xw-parent :data) 'wlr/wlr-scene-tree)))
  (def scene-tree (scene-surface-create parent-tree xw-surface))
  (set (xw-surface :data) scene-tree)

  (if-not (:wants-focus surface)
    (break))

  (def view (view/create surface scene-tree (>: surface :xwayland :server)))
  (put surface :view view)

  (put (surface :listeners) :unmap
     (wl-signal-add (>: surface :base :events.unmap)
                    (fn [listener data]
                      (:unmap view))))
  (put (surface :listeners) :request_move
     (wl-signal-add (>: surface :base :events.request_move)
                    (fn [listener data]
                      (:request-move view nil))))
  (put (surface :listeners) :request_resize
     (wl-signal-add (>: surface :base :events.request_resize)
                    (fn [listener data]
                      (def event (get-abstract-listener-data data 'wlr/wlr-xwayland-resize-event))
                      (:request-resize view event))))

  (:map view))


(defn- handle-surface-request-configure [surface listener data]
  (def event (get-abstract-listener-data data 'wlr/wlr-xwayland-surface-configure-event))
  (def xw-surface (surface :base))
  (def view (surface :view))
  # The surface may not be mapped yet, skip the view API in that case
  (if-let [view (surface :view)]
    (:move view (event :x) (event :y) (event :width) (event :height))
    (:move surface (event :x) (event :y) (event :width) (event :height))))


(defn- handle-new-surface [xwayland listener data]
  (def xw-surface (get-abstract-listener-data data 'wlr/wlr-xwayland-surface))
  (def surface
    @{:xwayland xwayland
      :base xw-surface
      :wlr-surface nil # unknown at this stage, set in the mapping event
      :listeners @{}})
  (table/setproto surface surface-proto)

  # This event may happen before mapping
  (put (surface :listeners) :request_configure
     (wl-signal-add (>: surface :base :events.request_configure)
                    (fn [listener data]
                      (handle-surface-request-configure surface listener data))))
  # We don't know anything about the X window at this stage, so delay
  # all other initialization til mapping.
  (put (surface :listeners) :map
     (wl-signal-add (>: surface :base :events.map)
                    (fn [listener data]
                      (handle-surface-map surface listener data))))
  # In case the surface is destroyed before mapping
  (put (surface :listeners) :destroy
     (wl-signal-add (>: surface :base :events.destroy)
                    (fn [listener data]
                      (if-let [view (surface :view)]
                        (:destroy view)
                        (:destroy surface))))))


(defn- handle-ready [xwayland listener data]
  (def [xcb-conn _screen-num] (xcb-connect (>: xwayland :base :display-name)))
  (def err (xcb-connection-has-error xcb-conn))
  (when (not (= err :none))
    (error (string/format "xcb-connect failed: %v" err)))

  (def atom-names ["_NET_WM_WINDOW_TYPE"
                   "_NET_WM_WINDOW_TYPE_NORMAL"
                   "_NET_WM_WINDOW_TYPE_DOCK"
                   "_NET_WM_WINDOW_TYPE_DIALOG"
                   "_NET_WM_WINDOW_TYPE_UTILITY"
                   "_NET_WM_WINDOW_TYPE_TOOLBAR"
                   "_NET_WM_WINDOW_TYPE_SPLASH"
                   "_NET_WM_WINDOW_TYPE_MENU"
                   "_NET_WM_WINDOW_TYPE_DROPDOWN_MENU"
                   "_NET_WM_WINDOW_TYPE_POPUP_MENU"
                   "_NET_WM_WINDOW_TYPE_TOOLTIP"
                   "_NET_WM_WINDOW_TYPE_NOTIFICATION"
                   "_NET_WM_STATE_MODAL"])
  (def atom-cookies
    (map (fn [atom-name]
           [atom-name (xcb-intern-atom xcb-conn false atom-name)])
         atom-names))
  (put xwayland :atoms @{})
  (each [atom-name cookie] atom-cookies
    (def [reply rep-err] (xcb-intern-atom-reply xcb-conn cookie))
    (if (nil? reply)
      (wlr-log :error "failed to intern atom %p: %p"
               atom-name (if (nil? rep-err) nil (rep-err :error-code)))
      (put (xwayland :atoms) atom-name (reply :atom))))

  (xcb-disconnect xcb-conn)

  (wlr-xwayland-set-seat (xwayland :base)
                         (>: xwayland :server :seat :base))
  (def xcursor
    (wlr-xcursor-manager-get-xcursor (>: xwayland :server :cursor :xcursor-manager)
                                     "left_ptr"
                                     1))
  (wlr-xwayland-set-cursor (xwayland :base)
                           (>: xcursor :images 0 :buffer)
                           (* 4 (>: xcursor :images 0 :width))
                           (>: xcursor :images 0 :width)
                           (>: xcursor :images 0 :height)
                           (>: xcursor :images 0 :hotspot-x)
                           (>: xcursor :images 0 :hotspot-y)))


(defn- init [self server]
  # TODO: lazy-load config
  (def wlr-xwayland (wlr-xwayland-create (>: server :display :base) (server :compositor) true))

  (put self :base wlr-xwayland)
  (put self :server server)
  (put self :listeners @{})

  (put (self :listeners) :ready
     (wl-signal-add (>: self :base :events.ready)
                    (fn [listener data]
                      (handle-ready self listener data))))
  (put (self :listeners) :new_surface
     (wl-signal-add (>: self :base :events.new_surface)
                    (fn [listener data]
                      (handle-new-surface self listener data))))

  self)


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener))
  (wlr-xwayland-destroy (self :base)))


(def- proto
  @{:destroy destroy})


(defn create [server]
  (init (table/setproto @{} proto) server))
