(import spork/netrepl)

(use ./util)


# All the modules that should be available in the REPL environment.
(def- repl-env (make-env))
(merge-module repl-env (require "janetland/wl"))
(merge-module repl-env (require "janetland/wlr"))
(merge-module repl-env (require "janetland/util"))
(merge-module repl-env (require "./util"))
(merge-module repl-env (require "./debug"))


(defn- init [self server]
  (put self :server server)
  (put self :path (string "/tmp/" (>: server :display :socket) "-juno-repl.socket"))
  (put self :repl-server nil)
  self)


(defn- start [self]
  (put self :repl-server
     (netrepl/server :unix (self :path)
                     (fn [name stream]
                       (def server-def
                         @{:value (self :server)
                           :doc "The global Juno server object.\n"})
                       (def client-name-def
                         @{:value name
                           :doc "The name for the current REPL client.\n"})
                       (def client-stream-def
                         @{:value stream
                           :doc "The socket stream for the current REPL client.\n"})

                       (def new-env (make-env repl-env))
                       (put new-env 'juno-server server-def)
                       (put new-env 'juno-client-name client-name-def)
                       (put new-env 'juno-client-stream client-stream-def)

                       (make-env new-env))
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
