# Snowmac

Snow for your Mac desktop. A small menu-bar app that draws falling snow (or rain) over everything, lets it pile up, and fills the screen with tiny scenes: snowploughs, police escorts, kids having a snowball fight.

Early prototype, written in Swift with AppKit and Core Animation. macOS 13 or later.

## What it does

- **Falling snow** made of real six-sided crystals, drawn sharp at their exact pixel size. Rain is also included.
- **Snow stays behind your windows.** Flakes, the pile and the snowploughs never draw over an open window, tab or widget. Maximised windows hide snow too.
- **Snow piles up** at the bottom of the screen (or on the Dock), capped at 0.5 cm. Caps of snow build on the top edge of windows and widgets. Both build slowly, over about five minutes.
- **Density slider** in the menu: more flakes, a faster build-up and a deeper pile. Raising or lowering it eases in slowly.
- **Physics.** The pointer presses a dent into the pile. Dragging a window shakes the snow off its top edge, opposite to the drag.
- **Snowploughs.** A truck rides the humps of the snow and clears the pile; in heavy snow a second truck follows with a police SUV behind each, all 2 cm apart. Vehicles can be picked up and dropped on a window or widget, where they drive along the top edge, tip over the end and fall.
- **Kids.** One kid pops out of the snow, throws a snowball and slips. In heavy snow, three or four kids have a snowball fight. They can be picked up and dropped too.
- **Menu controls:** snow density, rain density and rain speed.

## Build

    ./build_app.sh        # builds dist/Snowmac.app and installs it to ~/Applications

or, to run it straight from the build folder:

    swift build -c release
    .build/release/flurry

The app is signed ad hoc. If macOS refuses to open it, right-click it, choose Open, then Open again.

## Notes

- All artwork (flakes, trucks, police SUV, kids, icon) is drawn in code. There are no image files except the app icon.
- The debug build has some development hooks (environment variables starting with `FLURRY_`) used for testing. They are compiled out of the release build.

## License

MIT. See LICENSE.
