const std = @import("std");
const ziro = @import("ziro");
const aio = ziro.asyncio;
const myzql = @import("myzql");

pub fn main() !void {
    var dbg = std.heap.DebugAllocator(.{}){};
    defer _ = dbg.deinit();
    const allocator = dbg.allocator();

    // init async io executor and env
    var executor = try aio.Executor.init(allocator);
    defer executor.deinit(allocator);
    aio.initEnv(.{
        .executor = &executor,
        .stack_allocator = allocator,
        .default_stack_size = 1024 * 256,
    });

    // run main coroutine
    try aio.run(&executor, mainco, .{allocator}, null);
}

fn mainco(allocator: std.mem.Allocator) !void {
    var wg = ziro.sync.WaitGroup.init();

    const num_tasks: usize = 10;

    const tasks = try allocator.alloc(ziro.Frame, num_tasks);
    defer {
        for (tasks) |t| t.deinit();
        allocator.free(tasks);
    }

    for (0..num_tasks) |i| {
        wg.start();

        const t = try ziro.xasync(task, .{ &wg, allocator }, null);
        tasks[i] = t.frame();
    }

    wg.wait();
}

fn task(wg: *ziro.sync.WaitGroup, allocator: std.mem.Allocator) !void {
    defer wg.finish();

    try batch_insert(allocator);
}

fn batch_insert(allocator: std.mem.Allocator) !void {
    var client = try myzql.conn.Conn.init(allocator, &.{
        .username = "root", // your username and password
        .password = "root",
        .database = "demo",
        .address = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 3306),
    });
    defer client.deinit();

    var i: u32 = 100 * 1000;
    const prepare_result = try client.prepare(allocator,
        \\INSERT INTO `user`
        \\ (name, email, age)
        \\ values
        \\ ('Dacheng', 'user@example.com', 0)
    );
    defer prepare_result.deinit(allocator);
    const prepare_stmt = try prepare_result.expect(.stmt);
    while (i > 0) {
        _ = try client.execute(&prepare_stmt, .{});

        i -= 1;
    }
}
