/// We try to trigger ENOSYS by mapping a file into memory and then tries to
/// load the content from an offset in the file bigger than its length into a
/// register asm volatile ("ldr %0, [%1], 4" : "=r" (ret), "+r" (buf));
const std = @import("std");
const os = std.os;
const mem = std.mem;

pub fn main() !void {
    // Assume /dev is mounted
    std.debug.print("open /dev/mem\n", .{});
    var fd = try os.open("/dev/mem", os.O.RDWR, 0);
    var buf = try os.mmap(
        null,
        65536,
        os.PROT.READ | os.PROT.WRITE,
        os.MAP.SHARED,
        fd,
        0xf0000,
    );
    std.debug.print("try to ldr\n", .{});
    _ = asm volatile ("ldr %[ret], [%[buf_ptr], 4]"
        : [ret] "=r" (-> usize),
        : [buf_ptr] "+r" (buf.ptr),
    );
    std.debug.print("success\n", .{});
}
