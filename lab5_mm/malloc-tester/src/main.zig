const std = @import("std");

const own = @cImport({
    @cInclude("ll-mm.c");
});

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("string.h");
});

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test --summary all` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;
const dbg = std.debug;

// not used, but just in case
// const cmem = std.heap.c_allocator; // real C malloc, realloc, free are here

test "malloc 0 bytes" {
    defer own.reset();
    // test for corner cases
    var aptr = own.malloc(0);
    try expect(aptr != null);
    try expect(own.used_size() == 0);
    own.free(aptr);
}

test "realloc NULL and 0 bytes" {
    defer own.reset();
    var aptr1 = own.realloc(null, 0); // same as malloc 0
    try expect(aptr1 != null);
    var aptr2 = own.realloc(null, 100); // same as malloc 100
    try expect(aptr2 != null);
    try expect(own.used_size() >= 100); // could be > because of alignment
    _ = own.realloc(aptr2, 0); // same as free aptr2
    try expect(own.used_size() == 0);
}

test "free bad addr" {
    defer own.reset();
    var aptr = own.malloc(10);
    try expect(aptr != null);
    var bptr = own.malloc(10);
    own.free(bptr);
    aptr = own.realloc(aptr, 100);
    _ = c.memset(aptr, 128, 100);
    //    own.display_list();
    try expect(aptr != null);
    own.free(aptr);
    //    own.display_list();
}

test "malloc simple test 1 byte" {
    defer own.reset();
    const k = 13; // bytes
    var r = own.malloc(k);
    if (r == null)
        return error.MallocReturnsNull;
    try expect(own.used_size() >= k);
    try expectEq(own.unused_size(), 0);
    // own.display_list();
    own.free(r);
    // own.display_list();
    try expectEq(own.used_size(), 0);
}

test "malloc test" {
    defer own.reset();
    const r = own.malloc(64);
    if (r == null)
        return error.MallocReturnsNull;
    defer own.free(r);
    const a = own.malloc(2 * 64);
    if (a == null)
        return error.MallocReturnsNull;
    const b = own.malloc(3 * 64);
    if (b == null)
        return error.MallocReturnsNull;
    try expect(own.used_size() >= 64 + 2 * 64 + 3 * 64);
    //    own.display_list();
    own.free(a);
    own.free(b);
}

test "malloc test non-aligned" {
    defer own.reset();
    const r = own.malloc(63);
    if (r == null)
        return error.MallocReturnsNull;
    defer own.free(r);

    const a = own.malloc(2 * 61);
    if (a == null)
        return error.MallocReturnsNull;
    const b = own.malloc(3 * 65);
    if (b == null)
        return error.MallocReturnsNull;
    try expect(own.used_size() >= 63 + 2 * 61 + 3 * 65);
    //    own.display_list();
    own.free(a);
    own.free(b);
}

// TODO: add some tests for calloc here
// test "calloc test 1" {
//
// }
// test "calloc test 2" {
//
// }

test "realloc shrink test" {
    defer own.reset();
    var r = own.malloc(300);
    //    own.display_list();
    try expect(own.used_size() >= 300);
    r = own.realloc(r, 200);
    //    own.display_list();
    try expect(own.used_size() >= 200);
    r = own.realloc(r, 100);
    //    own.display_list();
    try expect(own.used_size() >= 100);
    own.free(r);
    //    own.display_list();
}

test "realloc last grow test" {
    defer own.reset();
    var r = own.malloc(100);
    //    own.display_list();
    try expect(own.used_size() >= 100);
    r = own.realloc(r, 200);
    //    own.display_list();
    try expect(own.used_size() >= 200);
    r = own.realloc(r, 300);
    //    own.display_list();
    try expect(own.used_size() >= 300);
    own.free(r);
    //    own.display_list();
}

test "realloc middle grow test" {
    defer own.reset();
    const sa = 400;
    var r = own.malloc(100);
    _ = own.malloc(sa);
    //    own.display_list();
    try expect(own.used_size() >= 100 + sa);
    r = own.realloc(r, 200);
    //    own.display_list();
    try expect(own.used_size() >= 200 + sa);
    _ = own.malloc(sa);
    r = own.realloc(r, 300);
    //    own.display_list();
    try expect(own.used_size() >= 300 + 2 * sa);
    own.free(r);
    //    own.display_list();
}

// test "fail test" {
//     return error.Fail;
// }
// TO ADD IN FUTURE VERSIONS
// - tests for internal functions
