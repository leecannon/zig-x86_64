# zig-x86_64

This repo is a [zig](https://github.com/ziglang) reimplementation of rust's [x86_64](https://github.com/rust-osdev/x86_64) crate.

## Page Size change from Rust crate

The original rust crate uses a generic PageSize over 4KiB, 2MiB and 1 GiB heavily, in this package there are seperate versions of structs for each with the page size appended to the struct name. However as a page size of 4KiB is the defacto standard, it's structs have no postfix e.g. PageIterator (4KiB), PageIterator2MiB and PageIterator1GiB.

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
