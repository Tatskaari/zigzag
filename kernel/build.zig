const std = @import("std");

pub fn target() std.Target.Query {
    // Define a freestanding x86_64 cross-compilation target.
    var t: std.zig.CrossTarget = .{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    };

    // Disable CPU features that require additional initialization
    // like MMX, SSE/2 and AVX. That requires us to enable the soft-float feature.
    const Features = std.Target.x86.Feature;
    t.cpu_features_sub.addFeature(@intFromEnum(Features.mmx));
    t.cpu_features_sub.addFeature(@intFromEnum(Features.sse));
    t.cpu_features_sub.addFeature(@intFromEnum(Features.sse2));
    t.cpu_features_sub.addFeature(@intFromEnum(Features.avx));
    t.cpu_features_sub.addFeature(@intFromEnum(Features.avx2));
    t.cpu_features_add.addFeature(@intFromEnum(Features.soft_float));
    return t;
}



pub fn build(b: *std.Build) void {
    const limine = b.dependency("limine", .{});

    const arch = b.addModule("arch", .{
        .root_source_file = .{.cwd_relative = "src/arch/index.zig"},
    });

    arch.addImport("limine", limine.module("limine"));

    const assets = b.addModule("assets", .{
        .root_source_file = .{.cwd_relative = "src/assets/assets.zig"},
    });

    const kernel = b.addModule("kernel", .{
        .root_source_file = .{.cwd_relative = "src/kernel/index.zig"},
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "limine", .module = limine.module("limine") },
        }
    });

    arch.addImport("kernel", kernel);

    const drivers = b.addModule("drivers", .{
        .root_source_file = .{.cwd_relative = "src/drivers/index.zig"},
        .imports = &[_]std.Build.Module.Import{
            .{ .name = "limine", .module = limine.module("limine") },
            .{ .name = "assets", .module = assets },
            .{ .name = "arch", .module = arch },
            .{ .name = "kernel", .module = kernel },
        },
    });

    arch.addImport("drivers", drivers);


    // Build the kernel itself.
    const optimize = b.standardOptimizeOption(.{});
    const root = b.addExecutable(.{
        .name = "kernel",
        .root_source_file = b.path("src/main.zig"),
        .target = b.resolveTargetQuery(target()),
        .optimize = optimize,
        .code_model = .kernel,
        .pic = true,
    });

    root.root_module.addImport("limine", limine.module("limine"));
    root.root_module.addImport("drivers", drivers);
    root.root_module.addImport("arch", arch);
    root.root_module.addImport("kernel", kernel);

    root.setLinkerScriptPath(b.path("linker.ld"));

    // Disable LTO. This prevents issues with limine requests
    root.want_lto = false;

    b.installArtifact(root);
}
