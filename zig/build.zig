// zig@0.6.0
// Build:
// $ zig build-lib --release-fast --output-dir ./pkg/ -target wasm32-freestanding-none lib.zig
const fs = @import("std").fs;
const CrossTarget = @import("std").zig.CrossTarget;
const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) !void {

    //const exe = b.addExecutable("zig-tracer", "lib.zig");
    const lib = b.addStaticLibrary("lib", "lib.zig");
    try fs.cwd().makePath("../public/build/");
    lib.setOutputDir("../public/build/");
    const cross_target = try CrossTarget.parse(.{
        .arch_os_abi = "wasm32-freestanding-none",
//        .cpu_features = "generic+v8a",
    });

    lib.setTarget(cross_target);
    lib.setBuildMode(b.standardReleaseOptions());
    lib.install();

    const tst = b.addTest("test");
}
