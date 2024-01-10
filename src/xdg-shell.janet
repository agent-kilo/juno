(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(import ./view)

(use ./util)

#
# Data fields used here:
#   xdg-surface data -> wlr-scene-tree object
#   wlr-surface data -> juno surface object
#


# Placeholders. Xdg surfaces don't really need these.
(defn- surface-map [self])
(defn- surface-unmap [self])


(defn- surface-destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(defn- surface-request-move [self event]
  (def last-btn-event (>: self :xdg-shell :last-pointer-button-event))
  (if (nil? last-btn-event)
    false
    (do
      (def [last-serial last-state _] last-btn-event)
      (and (= last-serial (event :serial)) (= last-state :pressed)))))


(defn- surface-request-resize [self event]
  (def last-btn-event (>: self :xdg-shell :last-pointer-button-event))
  (if (nil? last-btn-event)
    nil
    (do
      (def [last-serial last-state _] last-btn-event)
      (when (and (= last-serial (event :serial)) (= last-state :pressed))
        (event :edges)))))


(defn- surface-get-geometry [self]
  (wlr-xdg-surface-get-geometry (self :base)))


(defn- surface-move [self x y &opt width height]
  # x & y should be handled by views
  (if-not (or (nil? width) (nil? height))
    (wlr-xdg-toplevel-set-size (>: self :base :toplevel) width height)))


(defn- surface-wants-focus [self]
  true)


(defn- surface-set-activated [self activated]
  (wlr-xdg-toplevel-set-activated (>: self :base :toplevel) activated))


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


(defn- new-popup [xdg-shell xdg-surface]
  (def xdg-parent (wlr-xdg-surface-from-wlr-surface (>: xdg-surface :popup :parent)))
  (def parent-tree (pointer-to-abstract-object (xdg-parent :data) 'wlr/wlr-scene-tree))
  (def scene-tree (wlr-scene-xdg-surface-create parent-tree xdg-surface))
  (set (xdg-surface :data) scene-tree))


(defn- new-toplevel [xdg-shell xdg-surface]
  (def parent-tree (>: xdg-shell :server :scene :base :tree))
  (def scene-tree (wlr-scene-xdg-surface-create parent-tree xdg-surface))
  (set (xdg-surface :data) scene-tree)

  (def surface
    @{:xdg-shell xdg-shell
      :base xdg-surface
      :wlr-surface (xdg-surface :surface)
      :listeners @{}})
  (set ((surface :wlr-surface) :data) surface)
  (table/setproto surface surface-proto)

  (def view (view/create surface scene-tree (xdg-shell :server)))

  (put (surface :listeners) :map
     (wl-signal-add (>: surface :base :events.map)
                    (fn [listener data]
                      (:map view))))
  (put (surface :listeners) :unmap
     (wl-signal-add (>: surface :base :events.unmap)
                    (fn [listener data]
                      (:unmap view))))
  (put (surface :listeners) :destroy
     (wl-signal-add (>: surface :base :events.destroy)
                    (fn [listener data]
                      (:destroy view))))

  (put (surface :listeners) :request_move
     (wl-signal-add (>: surface :base :toplevel :events.request_move)
                    (fn [listener data]
                      (def event (get-abstract-listener-data data 'wlr/wlr-xdg-toplevel-move-event))
                      (:request-move view event))))
  (put (surface :listeners) :request_resize
     (wl-signal-add (>: surface :base :toplevel :events.request_resize)
                    (fn [listener data]
                      (def event (get-abstract-listener-data data 'wlr/wlr-xdg-toplevel-resize-event))
                      (:request-resize view event)))))


(defn- handle-new-surface [xdg-shell listener data]
  (def xdg-surface (get-abstract-listener-data data 'wlr/wlr-xdg-surface))

  (case (xdg-surface :role)
    :popup (new-popup xdg-shell xdg-surface)
    :toplevel (new-toplevel xdg-shell xdg-surface)
    # default
    (error (string/format "unknown xdg surface role: %v" (xdg-surface :role)))))


(defn- init [self server]
  (def wlr-xdg-shell (wlr-xdg-shell-create (>: server :display :base) 3)) # version = 3

  (put self :base wlr-xdg-shell)
  (put self :server server)
  (put self :listeners @{})

  (put (self :listeners) :new_surface
     (wl-signal-add (>: self :base :events.new_surface)
                    (fn [listener data]
                      (handle-new-surface self listener data))))

  self)


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(def- proto
  @{:destroy destroy})


(defn create [server]
  (init (table/setproto @{} proto) server))
