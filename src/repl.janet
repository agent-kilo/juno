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
                       (def new-env (make-env))
                       (put new-env 'juno-server @{:value (self :server)})
                       (put new-env 'juno-client-name @{:value name})
                       (put new-env 'juno-client-stream @{:value stream})
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
