(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(import ./output)
(import ./keyboard)
(import ./pointer)
(use ./util)


(defn- handle-new-output [backend listener data]
  (def wlr-output (get-abstract-listener-data data 'wlr/wlr-output))
  (def output (output/create (backend :server) wlr-output))
  (:add-output backend output))


(defn- handle-new-input [backend listener data]
  (def server (backend :server))
  (def device (get-abstract-listener-data data 'wlr/wlr-input-device))

  (case (device :type)
    :keyboard
    (do
      (def keyboard (keyboard/create backend device))
      (:add-input backend keyboard))

    :pointer
    (do
      (def pointer (pointer/create backend device))
      (:add-input backend pointer)))

  # XXX: We always provide pointers
  (def caps @[:pointer])
  (if-not (empty? (filter |(= (>: $ :device :type) :keyboard) (backend :inputs)))
    (array/push caps :keyboard))
  (:set-capabilities (server :seat) caps))


(defn- init [self server]
  (put self :base (wlr-backend-autocreate (>: server :display :base)))
  (put self :server server)
  (put self :listeners @{})
  (put self :outputs @[])
  (put self :inputs @[])

  (put (self :listeners) :new_output
     (wl-signal-add (>: self :base :events.new_output)
                    (fn [listener data]
                      (handle-new-output self listener data))))
  (put (self :listeners) :new_input
     (wl-signal-add (>: self :base :events.new_input)
                    (fn [listener data]
                      (handle-new-input self listener data))))
  (put (self :listeners) :destroy
     (wl-signal-add (>: self :base :events.destroy)
                    (fn [listener data]
                      (remove-listeners (self :listeners)))))

  self)


(defn- destroy [self]
  (wlr-backend-destroy (self :base)))


(defn- start [self]
  (if-not (wlr-backend-start (self :base))
    (error "wlr-backend-start failed")))


(defn- add-input [self input]
  (array/push (self :inputs) input))


(defn- remove-input [self input]
  (remove-element (self :inputs) input))


(defn- add-output [self output]
  # TODO: output layout config
  (:add-output-auto (>: self :server :output-layout) output)
  (array/push (self :outputs) output))


(defn- remove-output [self output]
  (remove-element (self :outputs) output))


(def- proto
  @{:destroy destroy
    :start start
    :add-input add-input
    :remove-input remove-input
    :add-output add-output
    :remove-output remove-output})


(defn create [server]
  (init (table/setproto @{} proto) server))
