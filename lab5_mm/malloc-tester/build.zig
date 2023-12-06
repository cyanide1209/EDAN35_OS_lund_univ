const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    //const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const exe = b.addExecutable(.{
        .name = "gawk",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        //        .root_source_file = .{ .path = "" },
        .target = target,
        .optimize = .ReleaseSmall, //optimize,
    });

    const stepChk = b.step("check", "Runs the gawk check tests via 'make check'");
    stepChk.makeFn = makeCheck;

    const step = b.step("setup", "Downloads and configures gawk sources");
    step.makeFn = setupGawk;

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    // CHANGED install gawk in the gawk-3.1.8 dir, to make it work with make check!
    var exe_dir = [_][]const u8{ b.install_path, "../gawk-3.1.8" };
    b.exe_dir = b.pathJoin(&exe_dir);
    // update info!
    b.install_tls.description = "Builds if necessary and installs gawk in gawk-3.1.8 directory";

    b.installArtifact(exe);

    exe.linkLibC();
    exe.linkSystemLibrary("m");
    exe.addIncludePath(.{ .path = "gawk-3.1.8" });
    exe.addCSourceFiles(.{
        .files = &.{
            "gawk-3.1.8/main.c",
            "../ll-mm.c",
            "gawk-3.1.8/array.c",
            "gawk-3.1.8/builtin.c",
            "gawk-3.1.8/eval.c",
            "gawk-3.1.8/ext.c",
            "gawk-3.1.8/floatcomp.c",
            "gawk-3.1.8/getopt.c",
            "gawk-3.1.8/io.c",
            "gawk-3.1.8/msg.c",
            "gawk-3.1.8/profile.c",
            "gawk-3.1.8/random.c",
            "gawk-3.1.8/replace.c",
            "gawk-3.1.8/awkgram.c",
            "gawk-3.1.8/dfa.c",
            "gawk-3.1.8/field.c",
            "gawk-3.1.8/gawkmisc.c",
            "gawk-3.1.8/getopt1.c",
            "gawk-3.1.8/node.c",
            "gawk-3.1.8/re.c",
            "gawk-3.1.8/regex.c",
            "gawk-3.1.8/version.c",
        },
        .flags = &.{
            "-std=c11",
            "-Wall",
            "-D_DEFAULT_SOURCE",
            "-O2", // needs this and ReleasSmall to work properly for now!
            //        "-g",
            "-pedantic",
            // MUST RUN CONFIGURE to generate CONFIG.H -> these are in there!
            "-DHAVE_CONFIG_H",
            "-DGAWK",
            "-DDEFPATH=\".:/usr/local/share/awk\"",
            "-DLOCALEDIR=\"/usr/local/share/locale\"",
        },
    });

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = .Debug,
    });

    unit_tests.linkLibC();
    unit_tests.linkSystemLibrary("m");
    unit_tests.addIncludePath(std.Build.LazyPath{ .path = ".." });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    //    run_unit_tests.addArg("--summary all");
    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}

fn setupGawk(self: *std.build.Step, progress: *std.Progress.Node) !void {
    const b = self.owner;
    const pgawk = b.pathFromRoot("gawk-3.1.8");

    if (std.fs.cwd().access(pgawk, .{})) {
        // directory already created!
        std.debug.print("Gawk directory already created - delete to rerun step!\n", .{});
        return error.PathAlreadyExists;
    } else |err| {
        std.debug.print("Setting up gawk [{any}]...\n", .{err});
    }
    // download gawk
    const cmd_wget = b.addSystemCommand(&[_][]const u8{
        "wget",
        "https://ftp.gnu.org/gnu/gawk/gawk-3.1.8.tar.gz",
    });
    try cmd_wget.step.make(progress);

    const cmd_unpack = b.addSystemCommand(&[_][]const u8{
        "tar",
        "-xzf",
        "gawk-3.1.8.tar.gz",
    });
    try cmd_unpack.step.make(progress);

    const cmd_remove = b.addSystemCommand(&[_][]const u8{
        "rm",
        "gawk-3.1.8.tar.gz",
    });
    try cmd_remove.step.make(progress);

    try std.os.chdir(pgawk);
    {
        const args = [_][]const u8{"./configure"};

        var process = std.process.Child.init(&args, b.allocator);
        std.debug.print("Running command: {s}\n", .{args});
        const code = try process.spawnAndWait();
        std.debug.print("Configure returned: {any}\n", .{code});
    }
    // PATCH for ioctl()
    // need to append sys/ioctl.h to awk.h - for clang/mac os x
    // also needs to undefine HAVE_SOCKETS to work propely on Linux
    {
        const awkhfile = try std.fs.cwd().openFile(
            "awk.h",
            .{ .mode = .read_write },
        );
        defer awkhfile.close();

        // get to the end
        try awkhfile.seekTo(try awkhfile.getEndPos());
        try awkhfile.writeAll("\n#include <sys/ioctl.h>\n#undef HAVE_SOCKETS\n");

        std.debug.print("Appended #include to awk.h\n", .{});
    }
}

// runs make check in the test directory
fn makeCheck(self: *std.build.Step, progress: *std.Progress.Node) !void {
    const b = self.owner;
    const pgawk = b.pathFromRoot("gawk-3.1.8/test");

    try std.os.chdir(pgawk);
    {
        const args = [_][]const u8{ "make", "check" };

        var process = std.process.Child.init(&args, b.allocator);
        std.debug.print("Running command: {s}\n", .{args});
        const code = try process.spawnAndWait();
        std.debug.print("Make check : {any}\n", .{code});
    }
    _ = progress;
}
