const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const guest_tool_src: GuestToolSrc = .{
    .x86_64 = &.{
        "src/fillmem.zig",
        "src/init.zig",
        "src/readmem.zig",
        "src/overlay-init.zig",
    },
    .aarch64 = &.{
        "src/fillmem.zig",
        "src/init.zig",
        "src/readmem.zig",
        "src/overlay-init.zig",
        "src/devmemread.zig",
    },
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const target_info = try std.zig.system.NativeTargetInfo.detect(target);

    switch (target_info.target.cpu.arch) {
        inline .x86_64, .aarch64 => |tag| {
            inline for (@field(guest_tool_src, @tagName(tag))) |src| {
                var buf: [256]u8 = undefined;
                const index = mem.lastIndexOfScalar(u8, src, '.') orelse
                    @panic("file has no extension");
                var mode = std.ArrayList(u8).init(b.allocator);
                for (@tagName(optimize)) |c| {
                    try mode.append(std.ascii.toLower(c));
                }
                defer mode.deinit();
                const name = try std.fmt.bufPrint(
                    &buf,
                    "{s}-{s}-{s}",
                    .{
                        fs.path.basename(src[0..index]),
                        @tagName(tag),
                        mode.items,
                    },
                );
                const exe = b.addExecutable(.{
                    .name = name,
                    .root_source_file = .{ .path = src },
                    .target = target,
                    .optimize = optimize,
                });
                b.installArtifact(exe);
            }
        },
        inline else => |tag| @panic("unsupported arch: " ++ @tagName(tag)),
    }
}

const GuestToolSrc = struct {
    x86_64: []const []const u8,
    aarch64: []const []const u8,
};
