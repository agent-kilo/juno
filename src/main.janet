(use janetland/wlr)

(import ./server)

(defn main [&]
  # TODO: log level config
  (wlr-log-init :debug)

  (def server (server/create))
  (printf "%p" server)
  (:start server)

  (os/sigaction :int (fn [&] (:stop server)))
  (os/sigaction :term (fn [&] (:stop server))))
