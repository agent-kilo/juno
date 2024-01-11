(import spork/netrepl)

(use ./util)


(defn- init [self server]
  (put self :server server)
  (put self :path (string "/tmp/" (>: server :display :socket) "-juno-repl.socket"))
  (put self :repl-server nil)
  self)


(defn- start [self]
  (put self :repl-server
     (netrepl/server :unix (self :path)
                     (fn [name stream]
                       (def server-def @{:value (self :server)
                                         :doc "The global Juno server object.\n"})
                       (def client-name-def @{:value name
                                              :doc "The name for the current REPL client.\n"})
                       (def client-stream-def @{:value stream
                                                :doc "The socket stream for the current REPL client.\n"})
                       (def new-env (make-env))
                       (put new-env 'juno-server server-def)
                       (put new-env 'juno-client-name client-name-def)
                       (put new-env 'juno-client-stream client-stream-def)
                       (table/setproto @{} new-env))
                     nil
                     "Welcome to Juno REPL!\n")))


(defn- stop [self]
  (:close (self :repl-server))
  (os/rm (self :path)))


(def- proto
  @{:start start
    :stop stop})


(defn create [server]
  (init (table/setproto @{} proto) server))
