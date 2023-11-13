/// This is a balloon device helper tool, which allocates an amount of
/// memory, given as the first starting parameter, and then tries to find
/// 4 consecutive occurences of an integer, given as the second starting
/// parameter, in that memory chunk. The program returns 1 if it succeeds
/// in finding these occurences, 0 otherwise. After performing a deflate
/// operation on the balloon device, we run this program with the second
/// starting parameter equal to `1`, which is the value we are using to
/// write in memory when dirtying it with `fillmem`. If the memory is
/// indeed scrubbed, we won't be able to find any 4 consecutive occurences
/// of the integer `1` in newly allocated memory.
const std = @import("std");
const os = std.os;
const fmt = std.fmt;
const mem = std.mem;

const MB = 1024 * 1024;

fn read_mem(mb_count: usize, value: c_int) u8 {
    var ptr: []align(mem.page_size) u8 = undefined;
    var buf: [4]c_int = [1]c_int{value} ** 4;

    while (true) {
        ptr = os.mmap(
            null,
            mb_count * MB * @sizeOf(u8),
            os.PROT.READ | os.PROT.WRITE,
            os.MAP.ANONYMOUS | os.MAP.PRIVATE,
            -1,
            0,
        ) catch continue;
        break;
    }
    var cur = mem.bytesAsSlice(c_int, ptr);
    // We will go through all the memory allocated with an `int` pointer,
    // so we have to divide the amount of bytes available by the size of
    // `int`. Furthermore, we compare 4 `int`s at a time, so we will
    // divide the upper limit of the loop by 4 and also increment the index
    // by 4.
    var i: usize = 0;
    while (i < cur.len) : (i += 4) {
        if (mem.eql(c_int, cur[i .. i + 4], &buf)) return 1;
    }
    return 0;
}

pub fn main() !u8 {
    var argv = os.argv;
    if (argv.len != 3) {
        std.debug.print("Usage: {s} mb_count value\n", .{argv[0]});
        std.os.exit(1);
    }
    var mb_count = try fmt.parseInt(usize, mem.span(argv[1]), 10);
    var value = try fmt.parseInt(c_int, mem.span(argv[2]), 10);
    return read_mem(mb_count, value);
}
