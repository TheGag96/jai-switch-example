# Switch homebrew example, written in Jai

This repo serves as an example project for writing Nintendo Switch homebrew in Jai. The LLVM backend is used to target the machine, and a few hacks to Jai's built-in modules are needed to get basic support working somewhat decently since ARM64 is not yet a first-class target.

Included also are bindings for the following libraries:

* [libnx](https://github.com/switchbrew/libnx)

## Setup

Ensure you have [devkitPro installed](https://devkitpro.org/wiki/Getting_Started). This should set the `DEVKITPRO` environment variable to its install location.

I recommend storing Jon's Jai beta releases in a Git repo. You can then make a new branch just for working with the module hacks you'll need to install. From there, in the root of the Jai release folder, do:

```sh
git apply --ignore-whitespace /path/to/this/repo/jai-module-hacks.patch
```

These hacks in this repo are up to date for **Jai version 0.1.083**.

## Building

```sh
jai first.jai - target
```

If you leave off `- target`, it will build the program for your host machine. The idea is that perhaps you want your project to be able to target Switch primarily but also your host PC during development.

## To do

* Complete bindings for inline functions / macros in libnx and deko3d

## Thanks to...

* @ctp and @ctpeepee in the Discord server for helping with the module hacks
* [DevkitPro](https://devkitpro.org/)
* The developers of [libnx](https://github.com/switchbrew/libnx)
* [Jonathan Blow](https://thekla.com) and the rest of the Jai language team