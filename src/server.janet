(use janetland/wl)
(use janetland/wlr)

(import ./backend)
(import ./renderer)
(import ./scene)
(import ./xdg-shell)
(import ./xwayland)

(use ./util)


(defn- init [self]
  (put self :listeners @{})

  (put self :display (wl-display-create))
  (put self :backend (backend/create self))
  (put self :renderer (renderer/create self))
  (put self :allocator (wlr-allocator-autocreate (>: self :backend :base) (>: self :renderer :base)))
  (put self :compositor (wlr-compositor-create (self :display) (>: self :renderer :base)))
  (put self :subcompositor (wlr-subcompositor-create (self :display)))
  (put self :data-device-manager (wlr-data-device-manager-create (self :display)))
  (put self :output-layout (wlr-output-layout-create))
  (put self :scene (scene/create self))
  (put self :xdg-shell (xdg-shell/create self))
  (put self :xwayland (xwayland/create self))

  # TODO

  (put self :event-loop (wl-display-get-event-loop (self :display)))
  (def loop-fd (wl-event-loop-get-fd (self :event-loop)))
  (put self :event-loop-stream (wl-event-loop-fd-to-stream loop-fd))
  (put self :running false)

  self)


(defn- run [self]
  (put self :running true)
  (while (self :running)
    (wl-display-flush-clients (self :display))
    (:dispatch (self :event-loop-stream) (self :event-loop))))


(defn stop [self]
  (put self :running false))


(defn- destroy [self]
  (wl-display-destroy-clients (self :display))
  (:destroy (self :xwayland))
  (wl-display-destroy (self :display)))


(def- proto
  @{:run run
    :destroy destroy})

(defn create []
  (init (table/setproto @{} proto)))
