const std = @import("std");
pub const pkgs = struct {
    pub fn addAllTo(artifact: *std.build.LibExeObjStep) void {
        @setEvalBranchQuota(1_000_000);
        inline for (std.meta.declarations(pkgs)) |decl| {
            if (decl.is_pub and decl.data == .Var) {
                artifact.addPackage(@field(pkgs, decl.name));
            }
        }
    }
};

pub const exports = struct {
    pub const x86_64 = std.build.Pkg{
        .name = "x86_64",
        .path = .{ .path = "src/index.zig" },
        .dependencies = &.{
        },
    };
};
pub const base_dirs = struct {
};
