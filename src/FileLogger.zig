const std = @import("std");
const FileLogger = @This();

file: std.fs.File,
mutex: std.Thread.Mutex = .{},

pub fn init(name: []const u8) !FileLogger {
    return .{
        .file = try std.fs.openFileAbsolute(name, .{}),
    };
}

pub fn deinit(self: *FileLogger) void {
    self.file.close();
}
