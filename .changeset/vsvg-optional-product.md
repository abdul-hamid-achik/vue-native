---
'@thelacanians/vue-native-cli': patch
---

Scaffolded apps now link the optional SVG product and bootstrap it at launch.

`<VSVG>` is the framework's only SVGKit consumer, so on iOS and macOS it moved
out of the core package into optional add-on products (`VueNativeCoreSVG` /
`VueNativeMacOSSVG`) — an app that never renders an SVG no longer resolves
SVGKit or the CocoaLumberjack version pin SVGKit's stale platform floors forced
on every consumer. `vue-native create` keeps `<VSVG>` working out of the box:
the generated `project.yml` links the add-on product and the generated
`AppDelegate` calls `VueNativeCoreSVG.register()` (macOS: before `super` in
`applicationDidFinishLaunching`). Hosts integrated by hand must add the product
and the call themselves; without it `<VSVG>` renders nothing and the framework
logs an error naming the product and the fix. `vue-native upgrade` re-vendors
the new sibling package like the rest of `native/`.
