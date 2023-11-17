/// Init wrapper for boot timing. It points at /sbin/init.
const std = @import("std");
const os = std.os;
const mem = std.mem;
const builtin = @import("builtin");

/// Base address values are defined in arch/src/lib.rs as arch::MMIO_MEM_START.
/// Values are computed in arch/src/<arch>/mod.rs from the architecture layouts.
/// Position on the bus is defined by MMIO_LEN increments, where MMIO_LEN is
/// defined as 0x1000 in vmm/src/device_manager/mmio.rs.
const magic_mmio_signal_guest_boot_complete: usize = switch (builtin.cpu.arch) {
    .x86_64 => 0xd0000000,
    .aarch64 => 0x40000000,
    else => 0x0,
};

const magic_value_signal_guest_boot_complete: usize = 123;

pub fn main() !void {
    var buffer: [256]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    var fd = try os.open("/dev/mem", (os.O.RDWR | os.O.SYNC | os.O.CLOEXEC), 0);
    _ = try os.mmap(
        null,
        mem.page_size,
        os.PROT.WRITE,
        os.MAP.SHARED,
        fd,
        magic_mmio_signal_guest_boot_complete,
    );
    var ptr_unaligned: [*]u8 = @ptrFromInt(magic_value_signal_guest_boot_complete);
    var base_ptr: [*]align(mem.page_size) u8 = @alignCast(ptr_unaligned);
    try os.msync(base_ptr[0..mem.page_size], os.MSF.ASYNC);

    const init = "/sbin/init";
    const argv: []const []const u8 = &.{"/sbin/init"};
    const argv_buf = try allocator.allocSentinel(?[*:0]const u8, argv.len, null);
    for (argv, 0..) |arg, i| argv_buf[i] = (try allocator.dupeZ(u8, arg)).ptr;

    const envp: [*:null]const ?[*:0]const u8 = @ptrCast(os.environ.ptr);
    const res: os.ExecveError!void = os.execveZ(init, argv_buf, envp);
    try res;
}
