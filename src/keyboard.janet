(use janetland/wl)
(use janetland/wlr)
(use janetland/xkb)
(use janetland/keysyms)
(use janetland/util)

(use ./util)


(defn- handle-keyboard-modifiers [keyboard listener data]
  (def seat (>: keyboard :server :seat))
  (def wlr-keyboard (keyboard :base))
  (wlr-seat-set-keyboard seat wlr-keyboard)
  (wlr-seat-keyboard-notify-modifiers seat (wlr-keyboard :modifiers)))


(defn- do-keybinding [server sym]
  (case sym
    (xkb-key :Escape)
    (do
      (:stop server)
      true)

    (xkb-key :Return)
    (do
      (os/spawn ["/bin/sh" "-c" "kitty"] :pd)
      true)

    # default
    false))


(defn- handle-keyboard-key [keyboard listener data]
  (def event (get-abstract-listener-data data 'wlr/wlr-keyboard-key-event))
  (def server (keyboard :server))
  (def wlr-seat (>: server :seat :base))
  (def wlr-keyboard (keyboard :base))

  # XXX: Difference from Wayland key codes & xkb key codes
  (def keycode (+ (event :keycode) 8))
  (def syms (xkb-state-key-get-syms (wlr-keyboard :xkb-state) keycode))
  (def modifiers (wlr-keyboard-get-modifiers wlr-keyboard))

  # TODO: keybinding overhaul
  (def handled-syms
    (if (and (contains? modifiers :alt) (= (event :state) :pressed))
      (map (fn [sym] (do-keybinding server sym)) syms)
      (map (fn [_] false) syms)))

  (if-not (any? handled-syms)
    (do
      (wlr-seat-set-keyboard wlr-seat wlr-keyboard)
      (wlr-seat-keyboard-notify-key wlr-seat
                                    (event :time-msec)
                                    (event :keycode)
                                    (event :state)))))


(defn- handle-keyboard-destroy [keyboard listener data]
  (:destroy keyboard)
  (:remove-input (>: keyboard :server :backend) keyboard))


(defn- init [self backend device]
  (def wlr-keyboard (wlr-keyboard-from-input-device device))

  (put self :base wlr-keyboard)
  (put self :device device)
  (put self :server (backend :server))
  (put self :listeners @{})

  (def context (xkb-context-new :no-flags))
  (def keymap (xkb-keymap-new-from-names context nil :no-flags))
  # TODO: keymap config
  (wlr-keyboard-set-keymap wlr-keyboard keymap)
  (xkb-keymap-unref keymap)
  (xkb-context-unref context)
  # TODO: key repeat config
  (wlr-keyboard-set-repeat-info wlr-keyboard 25 600)

  (put (self :listeners) :modifiers
     (wl-signal-add (>: self :base :events.modifiers)
                    (fn [listener data]
                      (handle-keyboard-modifiers self listener data))))
  (put (self :listeners) :key
     (wl-signal-add (>: self :base :events.key)
                    (fn [listener data]
                      (handle-keyboard-key self listener data))))
  (put (self :listeners) :destroy
     (wl-signal-add (>: self :device :events.destroy)
                    (fn [listener data]
                      (handle-keyboard-destroy self listener data))))

  (wlr-seat-set-keyboard (>: backend :server :seat :base) wlr-keyboard)

  self)


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(def- proto
  @{:destroy destroy})


(defn create [backend device]
  (init (table/setproto @{} proto) backend device))
