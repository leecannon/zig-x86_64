# zig-x86_64

This repo contains various functionality required to make an x86_64 kernel (following [Writing an OS in Rust](https://os.phil-opp.com/))

It is mainly a zig reimplementation of the rust crate [x86_64](https://github.com/rust-osdev/x86_64).
 
It includes a few additonal types in the `x86_64.additional` namespace:
 - `SerialPort` - Serial port type, mainly for debug output
 - `SimplePic` - Reimplementation of [pic8259_simple](https://docs.rs/pic8259_simple)
 
### Contributions are welcome!

## How to use

### Use a package manager

Currently [gyro](https://github.com/mattnite/gyro) is what this package supports.

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
