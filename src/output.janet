(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- handle-output-frame [output listener data]
  (def scene-output (wlr-scene-get-scene-output (>: output :server :scene) (output :base)))
  (wlr-scene-output-commit scene-output)
  (wlr-scene-output-send-frame-done scene-output (clock-gettime :monotonic)))


(defn- handle-output-destroy [output listener data]
  (:destroy output)
  (:remove-output (>: output :server :backend) output))


(defn- init [self backend wlr-output]
  (def server (backend :server))

  (put self :base wlr-output)
  (put self :server server)
  (put self :listeners @{})

  (if-not (wlr-output-init-render wlr-output (server :allocator) (server :renderer))
    (error "wlr-output-init-render failed"))

  (if (wl-list-empty (wlr-output :modes))
    (error "empty mode list for output"))

  # TODO: set mode from config?
  (def mode (wlr-output-preferred-mode wlr-output))
  (wlr-output-set-mode wlr-output mode)
  (wlr-output-enable wlr-output true)

  (if-not (wlr-output-commit wlr-output)
    (error "wlr-output-commit failed"))

  (put (self :listeners) :frame
     (wl-signal-add (>: self :base :events.frame)
                    (fn [listener data]
                      (handle-output-frame self listener data))))

  (put (self :listeners) :destroy
     (wl-signal-add (>: self :base :events.destroy)
                    (fn [listener data]
                      (handle-output-destroy self listener data))))

  # TODO: output layout config
  (wlr-output-layout-add-auto (server :output-layout) wlr-output)

  self)


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(def- proto
  @{:destroy destroy})


(defn create [backend wlr-output]
  (init (table/setproto @{} proto) backend wlr-output))
