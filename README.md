# zig-x86_64

This repo is a [zig](https://github.com/ziglang) reimplementation of rust's [x86_64](https://github.com/rust-osdev/x86_64) crate.

## How to use

Download the repo somehow then either:

### Add as package in `build.zig`

* To `build.zig` add:
  
   ```zig
   exe.addPackagePath("x86_64", "zig-x86_64/src/index.zig"); // or whatever the path is
   ```
* Then the package is available within any zig file:
  
   ```zig
   const x86_64 = @import("x86_64");
   ```

### Import directly

In any zig file add:
```zig
const x86_64 = @import("../zig-x86_64/src/index.zig"); // or whatever the path is from *that* file
```
