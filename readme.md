## DOOM Fire

A POSIX terminal implementation of (more or less) the PSX Doom fire,
[as described by Fabien Sanglard](http://fabiensanglard.net/doom_fire_psx/).

![Animated demo](demo.gif)

It should handle resizes just fine. Simulation speed is easy to vary,
rendering is the bottleneck. Still, don't trust the GIF, it's a lot
smoother in person.

### Usage

Compile: `dmd main.d escapes.d -of=doom-fire`

Get help: `./doom-fire --help`

Run: `./doom-fire` in a terminal with 256 colors.

Compiling with LDC and GDC doesn't work, but there shouldn't be big problems
against them either, I just didn't take the time to solve them.
