const std = @import("std");
const os = std.os;
const fmt = std.fmt;
const mem = std.mem;

const MB = 1024 * 1024;

fn fill_mem(mb_count: usize) !void {
    var buf: []align(mem.page_size) u8 = undefined;
    for (0..mb_count) |_| {
        // We can't map the whole chunk of memory at once because
        // in case the system is already in a memory pressured
        // state and we are trying to achieve a process death by
        // OOM killer, a large allocation is far less likely to
        // succeed than more granular ones.
        retry: while (true) {
            buf = os.mmap(
                null,
                MB * @sizeOf(u8),
                os.PROT.READ | os.PROT.WRITE,
                os.MAP.ANONYMOUS | os.MAP.PRIVATE,
                -1,
                0,
            ) catch continue :retry;
            break :retry;
        }
        @memset(buf, 1);
    }
}

pub inline fn WIFSIGNALED(s: os.WaitPidResult) bool {
    return (s.status & @as(u32, 0xffff) - @as(u32, 1)) < @as(u32, 0xff);
}

pub inline fn WEXITSTATUS(s: os.WaitPidResult) u32 {
    return (s.status & @as(u32, 0xff00)) >> 8;
}

pub inline fn WTERMSIG(s: os.WaitPidResult) u32 {
    return s.status & @as(u32, 0x7f);
}

pub fn main() !void {
    var argv = os.argv;
    if (argv.len != 2) {
        std.debug.print("Usage: {s} mb_count\n", .{argv[0]});
        os.exit(1);
    }

    var mb_count = try fmt.parseInt(usize, mem.span(argv[1]), 10);

    var pid = try os.fork();
    if (pid == 0) {
        return try fill_mem(mb_count);
    } else {
        var wait_result = os.waitpid(-1, 0);
        var fd = try os.open(
            "/tmp/fillmem_output.txt",
            os.O.WRONLY | os.O.CREAT | os.O.TRUNC,
            os.S.IRUSR | os.S.IWUSR | os.S.IXUSR,
        );
        defer os.close(fd);
        if (WIFSIGNALED(wait_result)) {
            var buf: [200]u8 = undefined;
            var msg = try fmt.bufPrint(
                &buf,
                "OOM Killer stopped the program with signal {d}, exit code {d}\n",
                .{
                    WTERMSIG(wait_result),
                    WEXITSTATUS(wait_result),
                },
            );
            _ = try os.write(fd, msg);
        } else {
            _ = try os.write(fd, "Memory filling was successful\n"[0..]);
        }
    }
}
