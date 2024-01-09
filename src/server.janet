(use janetland/wl)
(use janetland/wlr)

(import ./display)
(import ./backend)
(import ./renderer)
(import ./scene)
(import ./xdg-shell)
(import ./xwayland)
(import ./cursor)
(import ./seat)
(import ./repl)

(use ./util)


(defn- init [self]
  (put self :listeners @{})

  (put self :display (display/create self))
  (put self :backend (backend/create self))
  (put self :renderer (renderer/create self))
  (put self :allocator (wlr-allocator-autocreate (>: self :backend :base) (>: self :renderer :base)))
  (put self :compositor (wlr-compositor-create (>: self :display :base) (>: self :renderer :base)))
  (put self :subcompositor (wlr-subcompositor-create (>: self :display :base)))
  (put self :data-device-manager (wlr-data-device-manager-create (>: self :display :base)))
  (put self :output-layout (wlr-output-layout-create))
  (put self :scene (scene/create self))

  (put self :views @[])
  (put self :xdg-shell (xdg-shell/create self))
  (put self :xwayland (xwayland/create self))

  (put self :cursor (cursor/create self))
  (put self :seat (seat/create self))

  (put self :repl (repl/create self))

  (put self :running false)

  self)


(defn- run [self]
  (:start (self :repl))
  (:start (self :backend))

  (os/setenv "WAYLAND_DISPLAY" (>: self :display :socket))
  (os/setenv "DISPLAY" (>: self :xwayland :base :display-name))

  (def wl-display (>: self :display :base))
  (def event-loop (>: self :display :event-loop))
  (def stream (>: self :display :event-loop-stream))

  (put self :running true)
  (while (self :running)
    (wl-display-flush-clients wl-display)
    (:dispatch stream event-loop)))


(defn- start [self]
  (ev/spawn
   (:run self)
   (:destroy self)))


(defn stop [self]
  (put self :running false))


(defn- destroy [self]
  (:destroy (self :xwayland))
  (wl-display-destroy-clients (>: self :display :base))
  (:destroy (self :display))
  (:stop (self :repl)))


(def- proto
  @{:run run
    :start start
    :stop stop
    :destroy destroy})

(defn create []
  (init (table/setproto @{} proto)))
