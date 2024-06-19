# Juno #

A Wayland compositor built with [Janet](https://janet-lang.org/) and wlroots.

It's basically [TinyWL](https://gitlab.freedesktop.org/wlroots/wlroots/-/tree/master/tinywl) ported to Janet, with additional XWayland and REPL support.

**Note** that it depends on Janetland, which in turn depends on wlroots v0.16.2, and cannot be built with the latest wlroots.

## Dependencies ##

* Janetland
* pkg-config
* [JPM](https://janet-lang.org/docs/jpm.html)

## Compiling ##

1. Build Janetland and install it into Juno's local `jpm_tree`.
2. Run `jpm -l build`.
3. Check out the executable in `build/`
