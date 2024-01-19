(use janetland/wl)


(defmacro >: [root & branches]
  (defn wrap [last b]
    (tuple last b))
  (reduce wrap root branches))


(defn remove-element [arr e]
  (for idx 0 (length arr)
    (when (= (in arr idx) e)
      (array/remove arr idx)
      (break))))


(defn contains? [arr e]
  (any? (map (fn [ee] (= e ee)) arr)))


(defn remove-listeners [listeners]
  (eachp [_ listener] listeners
    (wl-signal-remove listener))
  (table/clear listeners))
