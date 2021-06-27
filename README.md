# zig-x86_64

[![CI](https://github.com/leecannon/zig-x86_64/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/leecannon/zig-x86_64/actions/workflows/main.yml)

This repo contains various functionality required to make an x86_64 kernel (following [Writing an OS in Rust](https://os.phil-opp.com/))

It is mainly a zig reimplementation of the rust crate [x86_64](https://github.com/rust-osdev/x86_64).
 
It includes a few additonal types in the `x86_64.additional` namespace:
 - `SerialPort` - Serial port type, mainly for debug output
 - `SimplePic` - Reimplementation of [pic8259_simple](https://docs.rs/pic8259_simple)
 
### Contributions are welcome!

## How to get

Currently [gyro](https://github.com/mattnite/gyro) is the only supported way of acquiring this package.

Just setup gyro as explained in it's documentation then `gyro add leecannon/x86_64`
