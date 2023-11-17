const std = @import("std");
const os = std.os;

pub const LOOP_SET_FD = 0x4C00;
pub const LOOP_CLR_FD = 0x4C01;
pub const LOOP_SET_STATUS64 = 0x4C04;
pub const LOOP_CTL_GET_FREE = 0x4C82;
pub const loop_name_size = 64;
pub const LoopInfo = extern struct {
    lo_device: u64, // ioctl r/o
    lo_inode: u64, // ioctl r/o
    lo_rdevice: u64, // ioctl r/o
    lo_offset: u64,
    lo_sizelimit: u64, // bytes, 0 == max available
    lo_number: u32, // ioctl r/o
    lo_encrypt_type: u32, // obsolete, ignored
    lo_encrypt_key_size: u32, // ioctl w/o
    lo_flags: u32,
    lo_file_name: [loop_name_size]u8,
    lo_crypt_name: [loop_name_size]u8,
    lo_encrypt_key: [loop_name_size]u8, // ioctl w/o
    lo_init: [2]u64,
};

pub const IoCtl_LOOP_CTL_GET_FREE_Error = error{
    FileSystem,
    InterfaceNotFound,
} || os.UnexpectedError;

pub fn ioctl_LOOP_CTL_GET_FREE(fd: os.fd_t) IoCtl_LOOP_CTL_GET_FREE_Error!usize {
    while (true) {
        const res = os.system.ioctl(fd, LOOP_CTL_GET_FREE, 0);
        switch (os.errno(res)) {
            .SUCCESS => return res,
            .INVAL => unreachable, // Bad parameters.
            .NOTTY => unreachable,
            .NXIO => unreachable,
            .BADF => unreachable, // Always a race condition.
            .FAULT => unreachable, // Bad pointer parameter.
            .INTR => continue,
            .IO => return error.FileSystem,
            .NODEV => return error.InterfaceNotFound,
            else => |err| return os.unexpectedErrno(err),
        }
    }
}

pub const IoCtl_LOOP_SET_FD_Error = error{
    FileSystem,
    InterfaceNotFound,
} || os.UnexpectedError;

pub fn ioctl_LOOP_SET_FD(fd: os.fd_t, target: os.fd_t) IoCtl_LOOP_SET_FD_Error!void {
    while (true) {
        switch (os.errno(os.system.ioctl(fd, LOOP_SET_FD, @intCast(target)))) {
            .SUCCESS => return,
            .INVAL => unreachable, // Bad parameters.
            .NOTTY => unreachable,
            .NXIO => unreachable,
            .BADF => unreachable, // Always a race condition.
            .FAULT => unreachable, // Bad pointer parameter.
            .INTR => continue,
            .IO => return error.FileSystem,
            .NODEV => return error.InterfaceNotFound,
            else => |err| return os.unexpectedErrno(err),
        }
    }
}

pub const IoCtl_LOOP_CLR_FD_Error = error{
    FileSystem,
    InterfaceNotFound,
} || os.UnexpectedError;

pub fn ioctl_LOOP_CLR_FD(fd: os.fd_t) IoCtl_LOOP_CLR_FD_Error!void {
    while (true) {
        switch (os.errno(os.system.ioctl(fd, LOOP_CLR_FD, 0))) {
            .SUCCESS => return,
            .INVAL => unreachable, // Bad parameters.
            .NOTTY => unreachable,
            .NXIO => unreachable,
            .BADF => unreachable, // Always a race condition.
            .FAULT => unreachable, // Bad pointer parameter.
            .INTR => continue,
            .IO => return error.FileSystem,
            .NODEV => return error.InterfaceNotFound,
            else => |err| return os.unexpectedErrno(err),
        }
    }
}

pub const IoCtl_LOOP_SET_STATUS64_Error = error{
    FileSystem,
    InterfaceNotFound,
} || os.UnexpectedError;

pub fn ioctl_LOOP_SET_STATUS64(fd: os.fd_t, info: *LoopInfo) IoCtl_LOOP_SET_STATUS64_Error!void {
    while (true) {
        switch (os.errno(os.system.ioctl(fd, LOOP_SET_STATUS64, @intFromPtr(info)))) {
            .SUCCESS => return,
            .INVAL => unreachable, // Bad parameters.
            .NOTTY => unreachable,
            .NXIO => unreachable,
            .BADF => unreachable, // Always a race condition.
            .FAULT => unreachable, // Bad pointer parameter.
            .INTR => continue,
            .IO => return error.FileSystem,
            .NODEV => return error.InterfaceNotFound,
            else => |err| return os.unexpectedErrno(err),
        }
    }
}

pub const MountError = error{
    AccessDenied,
    DeviceBusy,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    NameTooLong,
    NoDevice,
    FileNotFound,
    SystemResources,
    NotBlockDevice,
    NotDir,
    Unseekable,
    ReadOnlyFileSystem,
} || os.UnexpectedError;

pub fn mount(
    source: [*:0]const u8,
    target: [*:0]const u8,
    fstype: ?[*:0]const u8,
    flags: u32,
    data: usize,
) MountError!void {
    switch (os.errno(os.system.mount(source, target, fstype, flags, data))) {
        .SUCCESS => return,
        .ACCES => return error.AccessDenied,
        .BUSY => return error.DeviceBusy,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .LOOP => return error.SymLinkLoop,
        .MFILE => return error.ProcessFdQuotaExceeded,
        .NAMETOOLONG => return error.NameTooLong,
        .NODEV => return error.NoDevice,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .NOTBLK => return error.NotBlockDevice,
        .NOTDIR => return error.NotDir,
        .NXIO => return error.Unseekable,
        .PERM => return error.AccessDenied,
        .ROFS => return error.ReadOnlyFileSystem,
        else => |err| return os.unexpectedErrno(err),
    }
}

pub const UmountError = error{
    WouldBlock,
    DeviceBusy,
    NameTooLong,
    FileNotFound,
    SystemResources,
    AccessDenied,
} || os.UnexpectedError;

pub fn umount(special: [*:0]const u8, flags: u32) UmountError!void {
    switch (os.errno(os.system.umount2(special, flags))) {
        .SUCCESS => return,
        .AGAIN => return error.WouldBlock,
        .BUSY => return error.DeviceBusy,
        .FAULT => unreachable,
        .INVAL => unreachable,
        .NAMETOOLONG => return error.NameTooLong,
        .NOENT => return error.FileNotFound,
        .NOMEM => return error.SystemResources,
        .PERM => return error.AccessDenied,
        else => |err| return os.unexpectedErrno(err),
    }
}

const PivotRootError = error{
    DeviceBusy,
    FileNotFound,
    AccessDenied,
} || os.UnexpectedError;

pub fn pivortRoot(new: [*:0]const u8, old: [*:0]const u8) PivotRootError!void {
    switch (os.errno(linux.pivot_root(new, old))) {
        .SUCCESS => return,
        .BUSY => return error.DeviceBusy,
        .INVAL => unreachable,
        .NOTDIR => return error.FileNotFound,
        .PERM => return error.AccessDenied,
        else => |err| return os.unexpectedErrno(err),
    }
}

pub const linux = struct {
    pub fn pivot_root(new: [*:0]const u8, old: [*:0]const u8) usize {
        return os.linux.syscall2(.pivot_root, @intFromPtr(new), @intFromPtr(old));
    }
};
