const std = @import("std");
const expect = std.testing.expect;
const eql = std.mem.eql;

const NREG = 32;
const PAGESIZE_WIDTH = 2; // was 2
const PAGESIZE = 1 << PAGESIZE_WIDTH;
const NPAGES = 2048;
const RAM_PAGES = 8;
const RAM_SIZE = RAM_PAGES * PAGESIZE;
const SWAP_PAGES = 128;
const SWAP_SIZE = SWAP_PAGES * PAGESIZE;

const cpu_t = struct {
    pc: u32 = 0,
    reg: [NREG]u32 = undefined,
    fn print_regs(self: cpu_t) void {
        for (self.reg, 0..) |r, i| {
            std.debug.print("R{d:<2} = {d:<12} | ", .{ i, r });
            if ((i + 1) % 4 == 0)
                std.debug.print("\n", .{});
        }
    }
};

const PageWidth = u27;

const page_table_entry_t = struct {
    page: PageWidth, // Swap or RAM page
    inmemory: bool, // Page is in memory
    ondisk: bool, // Page is on disk
    modified: bool, // Page was modified while in memory
    referenced: bool, // Page was referenced recently
    readonly: bool, // Error if written to (not checked)
};

const coremap_entry_t = struct {
    owner: ?*page_table_entry_t, // Owner of this phys page
    page: PageWidth, // Swap page of page if assigned
};

const Instr = u32;

const Isa = enum {
    add,
    addi,
    sub,
    subi,
    sge,
    sgt,
    seq,
    bt,
    bf,
    ba,
    st,
    ld,
    call,
    jmp,
    mul,
    seqi,
    halt,
    const mnemonics = std.ComptimeStringMap(Isa, .{
        .{ "add", .add },
        .{ "addi", .addi },
        .{ "sub", .sub },
        .{ "subi", .subi },
        .{ "sge", .sge },
        .{ "sgt", .sgt },
        .{ "seq", .seq },
        .{ "bt", .bt },
        .{ "bf", .bf },
        .{ "ba", .ba },
        .{ "st", .st },
        .{ "ld", .ld },
        .{ "call", .call },
        .{ "jmp", .jmp },
        .{ "mul", .mul },
        .{ "seqi", .seqi },
        .{ "halt", .halt },
    });
    fn fromStr(str: []const u8) ?Isa {
        return mnemonics.get(str);
    }
    fn toStr(self: Isa) []const u8 {
        return @tagName(self);
    }

    fn mkInstr(self: Isa, dest: u5, s1: u5, s2: i16) Instr {
        const src2 = @as(u32, @as(u16, @bitCast(s2)));
        return (@as(Instr, @intFromEnum(self)) << 26) | (@as(Instr, dest) << 21) | (@as(Instr, s1) << 16) | src2;
    }

    fn extract_opcode(instr: Instr) Isa {
        return @as(Isa, @enumFromInt(instr >> 26));
    }

    fn extract_dest(instr: Instr) u5 {
        return @as(u5, @truncate(instr >> 21));
    }

    fn extract_source1(instr: Instr) u5 {
        return @as(u5, @truncate(instr >> 16));
    }

    fn extract_constant(instr: Instr) i16 {
        return @as(i16, @bitCast(@as(u16, @truncate(instr))));
    }
};

const vmem_t = struct {
    num_pagefault: u64 = 0, // Statistics
    page_table: [NPAGES]page_table_entry_t = undefined, // OS data structure
    coremap: [RAM_PAGES]coremap_entry_t = undefined, // OS data structure
    memory: [RAM_SIZE]u32 = undefined, // Hardware: RAM
    swap: [SWAP_SIZE]u32 = undefined, // Hardware: disk
    replace: *const fn (*vmem_t) PageWidth, // Page repl. alg.
    count: PageWidth = 0, // used for swap

    // EXTRA
    fifo_page: PageWidth = 0,
    // -----

    fn read_page(self: *vmem_t, phys_page: PageWidth, swap_page: PageWidth) void {
        std.debug.print("Swap IN page: {d} <- disk:{d}\n", .{ phys_page, swap_page });
        std.mem.copy(u32, self.memory[phys_page * PAGESIZE .. (phys_page + 1) * PAGESIZE], self.swap[swap_page * PAGESIZE .. (swap_page + 1) * PAGESIZE]);
    }

    fn write_page(self: *vmem_t, phys_page: PageWidth, swap_page: PageWidth) void {
        std.debug.print("Swap OUT page: {d} -> disk:{d}\n", .{ phys_page, swap_page });
        std.mem.copy(u32, self.swap[swap_page * PAGESIZE .. (swap_page + 1) * PAGESIZE], self.memory[phys_page * PAGESIZE .. (phys_page + 1) * PAGESIZE]);
    }

    fn new_swap_page(self: *vmem_t) PageWidth {
        std.debug.assert(self.count < SWAP_PAGES);
        self.count += 1;
        return self.count;
    }

    // TO COMPLETE
    fn fifo_page_replace(self: *vmem_t) PageWidth {
        var page: PageWidth = std.math.maxInt(PageWidth);
        std.debug.assert(page < RAM_PAGES);
        _ = self;
        return page;
    }

    // TO COMPLETE
    fn second_chance_replace(self: *vmem_t) PageWidth {
        var page: PageWidth = std.math.maxInt(PageWidth);
        std.debug.assert(page < RAM_PAGES);
        _ = self;
        return page;
    }

    fn take_phys_page(self: *vmem_t) PageWidth {
        const page = self.replace(self);
        // TO COMPLETE
        return page;
    }

    fn pagefault(self: *vmem_t, virt_page: PageWidth) void {
        var page = self.take_phys_page();

        self.num_pagefault += 1;
        // TO COMPLETE
        _ = page;
        _ = virt_page;
    }

    fn translate(self: *vmem_t, virt_addr: u32, write: bool) u32 {
        const virt_page: PageWidth = @as(PageWidth, @truncate(virt_addr / PAGESIZE));
        const offset: u32 = virt_addr & (PAGESIZE - 1);

        if (!self.page_table[virt_page].inmemory)
            self.pagefault(virt_page);

        self.page_table[virt_page].referenced = true;

        if (write)
            self.page_table[virt_page].modified = true;

        return self.page_table[virt_page].page * PAGESIZE + offset;
    }

    fn read_memory(self: *vmem_t, addr: u32) u32 {
        const phys_addr = self.translate(addr, false);
        return self.memory[phys_addr];
    }

    fn write_memory(self: *vmem_t, addr: u32, data: u32) void {
        const phys_addr = self.translate(addr, true);
        self.memory[phys_addr] = data;
    }
};

// reads a file, assembles it to memory and return the number of instructions read
fn read_program(mem: *vmem_t, file: []const u8) !u32 {
    var inf = try std.fs.cwd().openFile(file, .{});
    defer inf.close();

    var buf_reader = std.io.bufferedReader(inf.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var count: u32 = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var halfi = std.mem.split(u8, line, ";");
        const half = halfi.first();
        // do something with line...
        if (half.len == 0) // comment line only
            continue;
        // split the instruction
        var asmiter = std.mem.tokenize(u8, half, " ,");
        const op = asmiter.next() orelse "???";
        //        const mn = Isa.mnemonics.get(op) orelse return error.BadOpcode;
        const mn = Isa.fromStr(op) orelse return error.BadOpcode;
        const sa = asmiter.next() orelse return error.BadDestination;
        const a = try std.fmt.parseInt(u5, sa, 10);
        const sb = asmiter.next() orelse return error.BadSource;
        const b = try std.fmt.parseInt(u5, sb, 10);
        const sc = asmiter.next() orelse return error.BadConstant;
        const c = try std.fmt.parseInt(i16, sc, 10);
        const instr = Isa.mkInstr(mn, a, b, c);
        std.debug.print("{s}: {any} {d},{d},{d} -> {x}\n", .{ op, mn, a, b, c, instr });
        mem.write_memory(count, instr);
        count += 1;
    }
    return count;
}

fn run(cpu: *cpu_t, mem: *vmem_t, dbg: bool) void {
    var proceed: bool = true;
    var icnt: u32 = 0;
    while (proceed) {
        // Fetch next instruction to execute
        const instr = mem.read_memory(cpu.pc);

        // Decode the instruction
        const opcode = Isa.extract_opcode(instr);
        const source_reg1 = Isa.extract_source1(instr);
        const constant = Isa.extract_constant(instr);
        var dest_reg: u5 = Isa.extract_dest(instr);

        // Fetch operands
        const source1: i32 = @as(i32, @bitCast(cpu.reg[source_reg1]));
        const source2: i32 = @as(i32, @bitCast(cpu.reg[@as(u5, @truncate(@as(u16, @bitCast(constant))))]));
        var dest: i32 = 0;

        var increment_pc: bool = true;
        var writeback: bool = true;
        var ovfl: u1 = 0;

        std.debug.print("pc = {d}: {s} {d} <- {d},{d}   ", .{ cpu.pc, Isa.toStr(opcode), dest_reg, source_reg1, constant });

        switch (opcode) {
            .add => {
                var res = @addWithOverflow(source1, source2);
                ovfl = res[1];
                dest = res[0];
            },
            .addi => {
                const cnv2 = @as(i32, @intCast(constant));
                var res = @addWithOverflow(source1, cnv2);
                ovfl = res[1];
                dest = res[0];
            },
            .sub => {
                const cnv2 = @as(i32, @intCast(source2));
                var res = @subWithOverflow(source1, cnv2);
                ovfl = res[1];
                dest = res[0];
            },
            .subi => {
                const cnv2 = @as(i32, @intCast(constant));
                var res = @subWithOverflow(source1, cnv2);
                ovfl = res[1];
                dest = res[0];
            },
            .mul => {
                var res = @mulWithOverflow(source1, source2);
                ovfl = res[1];
                dest = res[0];
            },
            .sge => {
                dest = if (source1 >= source2) 1 else 0;
            },
            .sgt => {
                dest = if (source1 > source2) 1 else 0;
            },
            .seq => {
                dest = if (source1 == source2) 1 else 0;
            },
            .seqi => {
                dest = if (@as(i16, @intCast(source1)) == constant) 1 else 0;
            },
            .bt => {
                writeback = false;
                if (source1 != 0) {
                    cpu.pc = @as(u32, @intCast(constant));
                    increment_pc = false;
                }
            },
            .bf => {
                writeback = false;
                if (source1 == 0) {
                    cpu.pc = @as(u32, @intCast(constant));
                    increment_pc = false;
                }
            },
            .ba => {
                writeback = false;
                increment_pc = false;
                cpu.pc = @as(u32, @intCast(constant));
            },
            .ld => {
                const addr = @as(i32, @intCast(source1)) + constant;
                dest = @as(i32, @bitCast(mem.read_memory(@as(u32, @bitCast(addr)))));
            },
            .st => {
                const data = cpu.reg[dest_reg];
                const addr = @as(i32, @intCast(source1)) + constant;
                mem.write_memory(@as(u32, @bitCast(addr)), data);
                writeback = false;
            },
            .call => {
                increment_pc = false;
                dest = @as(i32, @bitCast(cpu.pc)) + 1;
                dest_reg = 31;
                cpu.pc = @as(u32, @intCast(constant));
            },
            .jmp => {
                increment_pc = false;
                writeback = false;
                cpu.pc = @as(u32, @bitCast(source1));
            },
            .halt => {
                std.debug.print(" ----- HALTING ----- \n", .{});
                increment_pc = false;
                writeback = false;
                proceed = false;
            },
        }

        if (writeback and dest_reg != 0)
            cpu.reg[dest_reg] = @as(u32, @bitCast(dest));

        if (increment_pc)
            cpu.pc += 1;

        icnt += 1;
        if (ovfl == 1) std.debug.print("[Overflow]", .{});
        std.debug.print("\n", .{});
        if (dbg) cpu.print_regs();
    }
    cpu.print_regs();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // process arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var fifo_flag: bool = false;
    var sc_flag: bool = false;
    var dbg_flag: bool = false;
    var infile: []const u8 = "fac.s";

    for (args[1..]) |a| {
        if (std.mem.eql(u8, a, "--fifo")) {
            fifo_flag = true;
        } else {
            if (std.mem.eql(u8, a, "--second-chance")) {
                sc_flag = true;
            } else {
                if (std.mem.eql(u8, a, "--debug")) {
                    dbg_flag = true;
                } else {
                    infile = a;
                }
            }
        }
    }

    if (fifo_flag == sc_flag) {
        std.debug.print("Options are: \n\t--fifo or --second-chance\n\toptionally --debug\n", .{});
        return error.ChooseOneReplacement;
    }

    // create memory and read program
    var mem = if (fifo_flag) vmem_t{ .replace = vmem_t.fifo_page_replace } else vmem_t{ .replace = vmem_t.second_chance_replace };
    _ = try read_program(&mem, infile);

    // create cpu and run the program
    var cpu = cpu_t{};
    run(&cpu, &mem, dbg_flag);

    // stdout is for the actual output of your application
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Page faults = {d}\n", .{mem.num_pagefault});

    try bw.flush(); // don't forget to flush!
}

// ------------ TESTS START HERE -----------------------

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
    try expect(eql(u8, Isa.add.toStr(), "add"));
}

test "ISA test" {
    try expect(eql(u8, Isa.add.toStr(), "add"));
    const i = Isa.add.mkInstr(1, 2, -1);
    try expect(i == 0x0022ffff);
    try expect(Isa.extract_opcode(i) == Isa.add);
    try expect(Isa.extract_dest(i) == 1);
    try expect(Isa.extract_source1(i) == 2);
    try expect(Isa.extract_constant(i) == -1);
}

test "read file test" {
    // allocate a large enough buffer to store the cwd
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    // getcwd writes the path of the cwd into buf and returns a slice of buf with the len of cwd
    const cwd = try std.os.getcwd(&buf);

    // print out the cwd
    std.debug.print("Working in {s}\n", .{cwd});
    var mem = vmem_t{ .replace = vmem_t.fifo_page_replace };
    const ni = try read_program(&mem, "fac.s");
    try expect(ni == 26);
}

test "run simple test" {
    var cpu = cpu_t{};
    var mem = vmem_t{ .replace = vmem_t.fifo_page_replace };
    const ins1 = Isa.add.mkInstr(1, 1, 0);
    mem.write_memory(0, ins1);
    const ins2 = Isa.halt.mkInstr(0, 0, 0);
    mem.write_memory(1, ins2);
    run(&cpu, &mem, false);
    try expect(cpu.pc == 1);
}

test "run file test" {
    // allocate a large enough buffer to store the cwd
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    // getcwd writes the path of the cwd into buf and returns a slice of buf with the len of cwd
    const cwd = try std.os.getcwd(&buf);

    // print out the cwd
    std.debug.print("Working in {s}\n", .{cwd});
    var mem = vmem_t{ .replace = vmem_t.fifo_page_replace };
    const ni = try read_program(&mem, "fac.s");
    try expect(ni == 26);
    var cpu = cpu_t{};
    run(&cpu, &mem, true);
}

test "fifo replace test" {
    var mem = vmem_t{ .replace = vmem_t.fifo_page_replace };
    var past = mem.fifo_page;
    var i: u32 = 0;
    while (i < RAM_PAGES * 2) : (i += 1) {
        try expect(mem.fifo_page_replace() == (past + i + 1) % RAM_PAGES);
    }
}
