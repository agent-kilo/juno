(use janetland/wl)
(use janetland/wlr)
(use janetland/util)

(use ./util)


(defn- init [self server]
  (put self :base (wlr-output-layout-create))
  (put self :server server)
  self)


(defn- add-output-auto [self output]
  (wlr-output-layout-add-auto (self :base) (output :base)))


(defn- get-output-at [self x y]
  (def wlr-output (wlr-output-layout-output-at (self :base) x y))
  (if-not (nil? wlr-output)
    (pointer-to-table (wlr-output :data))))


(def- proto
  @{:add-output-auto add-output-auto
    :get-output-at get-output-at})


(defn create [server]
  (init (table/setproto @{} proto) server))
