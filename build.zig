const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    var tests = b.addTest("src/index.zig");
    tests.setBuildMode(mode);

    const tests_step = b.step("test", "Run library tests");
    tests_step.dependOn(&tests.step);

    b.default_step = tests_step;
}
