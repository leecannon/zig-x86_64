const std = @import("std");
const Builder = std.build.Builder;
const pkgs = @import("deps.zig").pkgs;

pub fn build(b: *Builder) !void {
    b.use_stage1 = true;

    const mode = b.standardReleaseOptions();

    var tests = b.addTest("src/index.zig");
    tests.setBuildMode(mode);
    pkgs.addAllTo(tests);

    const tests_step = b.step("test", "Run library tests");
    tests_step.dependOn(&tests.step);

    b.default_step = tests_step;
}
