(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- handle-request-set-cursor [seat listener data]
  (def event (get-abstract-listener-data data 'wlr/wlr-seat-pointer-request-set-cursor-event))
  (def focused-client (>: seat :base :pointer-state :focused-client))
  (when (= focused-client (event :seat-client))
    (wlr-cursor-set-surface (>: seat :server :cursor :base)
                            (event :surface)
                            (event :hotspot-x)
                            (event :hotspot-y))))


(defn- handle-request-set-selection [seat listener data]
  (def event (get-abstract-listener-data data 'wlr/wlr-seat-request-set-selection-event))
  (wlr-seat-set-selection (seat :base) (event :source) (event :serial)))


(defn- init [self server]
  # TODO: seat config?
  (put self :base (wlr-seat-create (>: server :display :base) "seat0"))
  (put self :server server)
  (put self :listeners @{})

  (put (self :listeners) :request_set_cursor
     (wl-signal-add (>: self :base :events.request_set_cursor)
                    (fn [listener data]
                      (handle-request-set-cursor self listener data))))
  (put (self :listeners) :request_set_selection
     (wl-signal-add (>: self :base :events.request_set_selection)
                    (fn [listener data]
                      (handle-request-set-selection self listener data))))

  self)


(defn- pointer-button-event [self time button state]
  (wlr-seat-pointer-notify-button (self :base) time button state))


(defn- pointer-frame-event [self]
  (wlr-seat-pointer-notify-frame (self :base)))


(defn- pointer-enter-event [self surface sx sy]
  (wlr-seat-pointer-notify-enter (self :base) surface sx sy))

(defn- pointer-motion-event [self time surface sx sy]
  (:pointer-enter-event self surface sx sy)
  (wlr-seat-pointer-notify-motion (self :base) time sx sy))


(defn- pointer-clear-focus [self]
  (wlr-seat-pointer-clear-focus (self :base)))


(defn- get-keyboard [self]
  (wlr-seat-get-keyboard (self :base)))


(defn- set-keyboard [self keyboard]
  (wlr-seat-set-keyboard (self :base) keyboard))


(defn- keyboard-enter-event [self surface]
  (def wlr-keyboard (:get-keyboard self))
  (if-not (nil? wlr-keyboard)
    (wlr-seat-keyboard-notify-enter (self :base)
                                    surface
                                    (wlr-keyboard :keycodes)
                                    (wlr-keyboard :modifiers))))


(defn- keyboard-modifiers-event [self keyboard]
  (:set-keyboard self keyboard)
  (wlr-seat-keyboard-notify-modifiers (self :base) (keyboard :modifiers)))


(defn- keyboard-key-event [self keyboard time keycode state]
  (:set-keyboard self keyboard)
  (wlr-seat-keyboard-notify-key (self :base) time keycode state))


(defn- set-capabilities [self caps]
  (wlr-seat-set-capabilities (self :base) caps))


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(def- proto
  @{:pointer-button-event pointer-button-event
    :pointer-frame-event pointer-frame-event
    :pointer-enter-event pointer-enter-event
    :pointer-motion-event pointer-motion-event
    :pointer-clear-focus pointer-clear-focus
    :get-keyboard get-keyboard
    :set-keyboard set-keyboard
    :keyboard-enter-event keyboard-enter-event
    :keyboard-modifiers-event keyboard-modifiers-event
    :keyboard-key-event keyboard-key-event
    :set-capabilities set-capabilities
    :destroy destroy})


(defn create [server]
  (init (table/setproto @{} proto) server))
