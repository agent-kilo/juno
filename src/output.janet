(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- handle-output-frame [output listener data]
  (def scene-output (wlr-scene-get-scene-output (>: output :server :scene :base) (output :base)))
  (wlr-scene-output-commit scene-output)
  (wlr-scene-output-send-frame-done scene-output (clock-gettime :monotonic)))


(defn- handle-output-destroy [output listener data]
  (remove-listeners (output :listeners))
  (:remove-output (>: output :server :backend) output))


(defn- init [self server wlr-output]
  (put self :base wlr-output)
  (put self :server server)
  (put self :listeners @{})

  (if-not (wlr-output-init-render wlr-output (server :allocator) (>: server :renderer :base))
    (error "wlr-output-init-render failed"))

  (if-not (wl-list-empty (wlr-output :modes))
    (do
      # TODO: set mode from config?
      (def mode (wlr-output-preferred-mode wlr-output))
      (wlr-output-set-mode wlr-output mode)
      (wlr-output-enable wlr-output true)
      (if-not (wlr-output-commit wlr-output)
        (error "wlr-output-commit failed"))))

  (put (self :listeners) :frame
     (wl-signal-add (>: self :base :events.frame)
                    (fn [listener data]
                      (handle-output-frame self listener data))))
  (put (self :listeners) :destroy
     (wl-signal-add (>: self :base :events.destroy)
                    (fn [listener data]
                      (handle-output-destroy self listener data))))

  (set (wlr-output :data) self)

  self)


(defn- get-geometry [self]
  (wlr-output-layout-get-box (>: self :server :output-layout :base)
                             (self :base)))


(defn- destroy [self]
  (wlr-output-destroy (self :base)))


(def- proto
  @{:get-geometry get-geometry
    :destroy destroy})


(defn create [server wlr-output]
  (init (table/setproto @{} proto) server wlr-output))
