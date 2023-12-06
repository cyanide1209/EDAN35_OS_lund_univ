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

pub fn expectGE(lhs: usize, rhs: usize) !void {
    if(!(lhs >= rhs)){
        std.debug.print("Expected lhs >= rhs. Instead got lhs = {any} and rhs = {any}.\n", .{lhs, rhs});
        return error.TestUnexpectedError;
    }
}

pub fn expectNotNull(ptr: anytype) !void {
    if(!(ptr != null)){
        std.debug.print("Pointer is null, expected to have an address\n", .{});
        return error.TestUnexpectedError;
    }
}


const expect = std.testing.expect;
const expectEq = std.testing.expectEqual;
const dbg = std.debug;

// not used, but just in case
// const cmem = std.heap.c_allocator; // real C malloc, realloc, free are here

// Check that we can perform a simple malloc and free.
test "simple malloc free" {
    defer own.reset();
    const aptr1 = own.malloc(100);
    try expect(aptr1 != null);
    try expectGE(own.used_size(), 100);
    own.free(aptr1);
    try expectEq(@as(usize,0), own.used_size());
}

// Check that we can malloc and free multiple times
test "multiple mallocs" {
    defer own.reset();
    const aptr1 = own.malloc(100);
    try expect(aptr1 != null);
    try expectGE(own.used_size(),100);
    const aptr2 = own.malloc(100);
    try expectNotNull(aptr2);
    try expectGE(own.used_size(),200);
    const aptr3 = own.malloc(100);
    try expectNotNull(aptr3);
    try expectGE(own.used_size(), 300);
    own.free(aptr1);
    try expectGE(own.used_size(), 200);
    own.free(aptr2);
    try expectGE(own.used_size(), 100);
    own.free(aptr3);
    try expectEq(@as(usize,0), own.used_size());
}

// A test that checks if we can handle segmented data by deallocating a block
// in the middle of a number of blocks and trying to reallocate data that
// should fit into that block
// 1. Allocate 3 blocks of data, then free the middle one.
// 2. Then allocate a 4th block of data that we expect will be able to fit
//    into the gap released by the middle block
test "malloc in gap" {
    defer own.reset();
    const aptr1 = own.malloc(100);
    try expect(aptr1 != null);
    try expectGE(own.used_size(),100);
    const aptr2 = own.malloc(100);
    try expectNotNull(aptr2);
    try expectGE(own.used_size(),200);
    const aptr3 = own.malloc(100);
    try expectNotNull(aptr3);
    try expectGE(own.used_size(), 300);

    // Free the middle block (aptr2) and allocate a 4th pointer (aptr4) that
    // can fit into the empty space left by aptr2.
    own.free(aptr2);
    try expectGE(own.used_size(),200);
    const aptr4 = own.malloc(50);
    try expectNotNull(aptr4);
    try expectGE(own.used_size(), 250);
    own.free(aptr1);
    own.free(aptr3);
    try expectGE(own.used_size(),50);
    own.free(aptr4);
    try expectEq(@as(usize,0), own.used_size());
}


test "malloc 0 bytes" {
    defer own.reset();
    // test for corner cases
    const aptr = own.malloc(0);
    try expectNotNull(aptr);
    try expectEq(@as(usize,0), own.used_size());
    own.free(aptr);
}

test "realloc NULL and 0 bytes" {
    defer own.reset();
    const aptr1 = own.realloc(null, 0); // same as malloc 0
    try expectNotNull(aptr1);
    const aptr2 = own.realloc(null, 100); // same as malloc 100
    try expectNotNull(aptr2);
    try expectGE(own.used_size(), 100); // could be > because of alignment
    _ = own.realloc(aptr2, 0); // same as free aptr2
    try expectEq(@as(usize,0), own.used_size());
}

test "free bad addr" {
    defer own.reset();
    var aptr = own.malloc(10);
    try expectNotNull(aptr);
    const bptr = own.malloc(10);
    own.free(bptr);
    aptr = own.realloc(aptr, 100);
    _ = c.memset(aptr, 128, 100);
    //    own.display_list();
    try expectNotNull(aptr);
    own.free(aptr);
    //    own.display_list();
}

test "malloc simple test 1 byte" {
    defer own.reset();
    const k = 13; // bytes
    const r = own.malloc(k);
    if (r == null)
        return error.MallocReturnsNull;
    try expectGE(own.used_size(), k);
    try expectEq(@as(usize,0), own.unused_size());
    // own.display_list();
    own.free(r);
    // own.display_list();
    try expectEq(@as(usize,0), own.used_size());
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
    try expectGE(own.used_size(), 64 + 2 * 64 + 3 * 64);
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
    try expectGE(own.used_size(), 63 + 2 * 61 + 3 * 65);
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
    try expectGE(own.used_size(), 300);
    r = own.realloc(r, 200);
    //    own.display_list();
    try expectGE(own.used_size(), 200);
    r = own.realloc(r, 100);
    //    own.display_list();
    try expectGE(own.used_size(), 100);
    own.free(r);
    //    own.display_list();
}

test "realloc last grow test" {
    defer own.reset();
    var r = own.malloc(100);
    //    own.display_list();
    try expectGE(own.used_size(), 100);
    r = own.realloc(r, 200);
    //    own.display_list();
    try expectGE(own.used_size(), 200);
    r = own.realloc(r, 300);
    //    own.display_list();
    try expectGE(own.used_size(), 300);
    own.free(r);
    //    own.display_list();
}

test "realloc middle grow test" {
    defer own.reset();
    const sa = 400;
    var r = own.malloc(100);
    const q = own.malloc(sa);
    //    own.display_list();
    try expectGE(own.used_size(), 100 + sa);
    r = own.realloc(r, 200);
    //    own.display_list();
    try expectGE(own.used_size(), 200 + sa);
    const j = own.malloc(sa);
    r = own.realloc(r, 400);
    try expectGE(own.used_size(), 300 + 2 * sa);
    own.free(r);
    own.free(q);
    //    own.display_list();
    own.free(j);
}

// A test to check that calls to realloc move the data pointed to the new
// location when a call to realloc results in the data being moved to another
// location in memory. We assume this happens when a block has no room to grow
// in its specific location in the heap and try to recreate these conditions.
// NOTE: Some implementations may not work as we assume here, in which case the
// usefulness of this test is questionable.
test "realloc middle grow data test" {
    const sa = 400;
    // 1. Set up initial block of data
    // 1.1 Malloc 100 bytes and save it in variable r
    var r = own.malloc(100);
    // 1.2 Take this C pointer (zig type *anyopaque) and tell zig to interpret
    // it as a "slice" ([]u8). This explicitly tells the zig compiler that we
    // epect this pointer to point to an array of u8s of a fixed size.
    var rArrayOriginal: []u8 = @as([*]u8, @ptrCast(r))[0..100];

    // 1.3 Assign the values 0 to 99 to the memory pointed to by r
    for (0..100) |i| {
        rArrayOriginal[i] = @truncate(i);
    }

    // 2. Allocate a big block of memory above r
    const q = own.malloc(sa);

    // 3. Try reallocate r to be bigger. As the block q is above r in memory,
    // we expect r to be moved to another location in memory and the memory
    // copied
    r = own.realloc(r, 200);
    const rArrayCopied: []const u8 = @as([*]u8, @ptrCast(r))[0..200];
    // Debugging print message. Commented out for now
    // std.debug.print("R-original: {any} {any}.\n", .{@TypeOf(rArrayOriginal) ,rArrayOriginal});
    // std.debug.print("R-copied: {any}.\n", .{rArrayCopied});
    try expectGE(own.used_size(), 200 + sa);

    // 4. Check that the first 100  elements stored in r have been moved to this
    // copied location.
    for (0..100) |i| {
        try expectEq(@as(u8,@truncate(i)), rArrayCopied[i]);
    }

    // 5. Free unused pointers and check that no memory is still allocated
    own.free(r);
    own.free(q);
    try expectEq(@as(usize,0), own.used_size());
}

// test "fail test" {
//     return error.Fail;
// }
// TO ADD IN FUTURE VERSIONS
// - tests for internal functions
