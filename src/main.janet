(use janetland/wlr)

(import ./server)

(defn main [& argv]
  # TODO: log level config
  (wlr-log-init :debug)

  (def server (server/create))
  (def server-sup (:start server))

  (os/sigaction :int (fn [&] (:stop server)))
  (os/sigaction :term (fn [&] (:stop server)))

  (when (> (length argv) 1)
    (def cmd (slice argv 1))
    (os/spawn ["/bin/sh" "-c" ;cmd] :pd))

  (def [stat fiber val] (ev/take server-sup))
  (if-not (= stat :ok)
    (do (wlr-log :error "server exited abnormally: (%p, %p)" stat val)
        (debug/stacktrace fiber val)))
  (:destroy server))
