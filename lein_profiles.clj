{:user {:plugins [
                  [lein-cljfmt "0.3.0" :exclusions [org.clojure/clojure]]
                  [lein-ancient "0.6.8" :exclusions [org.clojure/clojure]]
                  [lein-ring "0.9.7"]
                  [lein-ancient "0.6.8"]
                  [jonase/eastwood "0.2.3"]
                  [cider/cider-nrepl "0.10.1"]
                  ]}}
{:dev {:dependencies
       [[com.cemerick/pomegranate "0.3.0"]]
       }}
