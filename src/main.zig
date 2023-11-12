const std = @import("std");
const spell_corrector = @import("spell_corrector");

pub fn main() !void {
    // // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // // stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(stdout_file);
    // const stdout = bw.writer();

    // try stdout.print("Run `zig build test` to run the tests.\n", .{});

    // try bw.flush(); // don't forget to flush!
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const allocator = gpa.allocator();

    var sc = spell_corrector.SpellCorrector.init(allocator);
    sc.useDictionary("notsobig.txt");

    var output = sc.suggestSimilarWord("speling", 8) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        return;
    };

    if (output != null) {
        std.debug.print("The word is: {s}\n", .{output.?});
    } else {
        std.debug.print("No matching word found", .{});
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
