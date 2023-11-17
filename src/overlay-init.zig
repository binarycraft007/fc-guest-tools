const std = @import("std");
const os = std.os;
const debug = std.debug;
const log = std.log.scoped(.init);
const FileLogger = @import("FileLogger.zig");
const osx = @import("osx.zig");

var file_logger: FileLogger = undefined;
const overlay_root = "/dev/vdb";
const overlay_upper = "/overlay/root";
const overlay_work = "/overlay/work";

pub fn main() !void {
    file_logger = try FileLogger.init("/dev/kmsg");
    defer file_logger.deinit();
    doOverlay() catch |err| {
        log.err("do overlay: {}", .{err});
    };
    try execOrignalInit("/usr/sbin/init");
}

fn doOverlay() !void {
    // Overlay is configured under /overlay
    // Global variable overlay_root is expected to be set to a
    // block device name, relative to /dev, in which case it is assumed
    // to contain an ext4 filesystem suitable for use as a rw overlay
    // layer. e.g. "vdb"
    try osx.mount(overlay_root, "/overlay", "ext4", 0, 0);
    std.fs.makeDirAbsolute(overlay_upper) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => |e| return e,
    };
    std.fs.makeDirAbsolute(overlay_work) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => |e| return e,
    };
    try pivot(.{
        .rw_root = overlay_upper,
        .work_dir = overlay_work,
    });
}

fn execOrignalInit(init: [*:0]const u8) !void {
    var buffer: [256]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const argv_buf = try allocator.allocSentinel(
        ?[*:0]const u8,
        os.argv.len,
        null,
    );
    argv_buf[0] = init;
    for (os.argv[1..], 0..) |arg, i| argv_buf[i + 1] = arg;

    const envp: [*:null]const ?[*:0]const u8 = @ptrCast(os.environ.ptr);
    const res: os.ExecveError!void = os.execveZ(init, argv_buf, envp);
    try res;
}

const PivotOptions = struct {
    rw_root: []const u8,
    work_dir: []const u8,
};

/// Parameters:
/// 1. rw_root -- path where the read/write root is mounted
/// 2. work_dir -- path to the overlay workdir (must be on same filesystem as rw_root)
/// Overlay will be set up on /mnt, original root on /mnt/rom
fn pivot(options: PivotOptions) !void {
    var buffer: [256]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    const data = try std.fmt.allocPrintZ(
        allocator,
        "lowerdir=/,upperdir={s},workdir={s}",
        .{ options.rw_root, options.work_dir },
    );
    try osx.mount(
        try std.fmt.allocPrintZ(
            allocator,
            "overlay:{s}",
            .{options.rw_root},
        ),
        "/mnt",
        "overlay",
        os.linux.MS.NOATIME,
        @intFromPtr(data.ptr),
    );
    try osx.pivortRoot("/mnt", "/mnt/rom");
}

pub const std_options = struct {
    pub const log_level = .info;
    pub const logFn = kmsgLogFn;
};

pub fn kmsgLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    file_logger.mutex.lock();
    defer file_logger.mutex.unlock();

    file_logger.file.writer().print(prefix ++ format ++ "\n", args) catch {
        return;
    };
}
