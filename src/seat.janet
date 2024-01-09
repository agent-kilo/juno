(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- handle-request-set-cursor [seat listener data]
  (def event (get-abstract-listener-data data 'wlr/wlr-seat-pointer-request-set-cursor-event))
  (def focused-client (>: seat :base :pointer-state :focused-client))
  (when (= focused-client (event :seat-client))
    (wlr-cursor-set-surface (>: seat :server :cursor)
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


(defn- destroy [self]
  (eachp [_ listener] (self :listeners)
    (wl-signal-remove listener)))


(def- proto
  @{:destroy destroy})


(defn create [server]
  (init (table/setproto @{} proto) server))
