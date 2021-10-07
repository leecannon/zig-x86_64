# zig-x86_64

[![CI](https://github.com/leecannon/zig-x86_64/actions/workflows/main.yml/badge.svg?branch=master)](https://github.com/leecannon/zig-x86_64/actions/workflows/main.yml)

This repo contains various functionality required to make an x86_64 kernel (following [Writing an OS in Rust](https://os.phil-opp.com/))

It is mainly a zig reimplementation of the rust crate [x86_64](https://github.com/rust-osdev/x86_64).

It includes a few additonal types in the `x86_64.additional` namespace:

- `SerialPort` - Serial port type, mainly for debug output
- `SimplePic` - Reimplementation of [pic8259_simple](https://docs.rs/pic8259_simple)

## How to get

### Gyro

`gyro add leecannon/x86_64`

### Zigmod

`zigmod aq add 1/leecannon/x86_64`

### Git

#### Submodule

`git submodule add https://github.com/leecannon/zig-x86_64 zig-x86_64`

#### Clone

`git clone https://github.com/leecannon/zig-x86_64`
