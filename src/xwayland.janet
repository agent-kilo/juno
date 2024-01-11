(use janetland/wl)
(use janetland/wlr)
(use janetland/xcb)
(use janetland/util)

(use ./util)


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


(defn- handle-new-surface [xwayland listener data]
  # TODO
  )


(defn- init [self server]
  # TODO: lazy-load config
  (def wlr-xwayland (wlr-xwayland-create (>: server :display :base) (server :compositor) false))

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
