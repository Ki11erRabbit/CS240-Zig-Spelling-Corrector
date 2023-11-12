const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const trie = @import("trie.zig");
const io = std.io;

pub const SpellCorrector = struct {
    dictionary: trie.Trie,
    allocator: Allocator,
    pub fn init(alloc: Allocator) SpellCorrector {
        return SpellCorrector{
            .dictionary = trie.Trie.init(alloc) catch unreachable,
            .allocator = alloc,
        };
    }
    pub fn useDictionary(self: *SpellCorrector, file_name: []const u8) void {
        self.dictionary.deinit();
        self.dictionary = trie.Trie.init(self.allocator) catch return;

        const file = std.fs.cwd().openFile(file_name, .{}) catch return;
        defer file.close();

        var accumulator = std.ArrayList(u8).init(self.allocator);
        defer accumulator.deinit();
        {
            var buffer: [100]u8 = undefined;
            var bytes_read: usize = undefined;

            while (true) {
                bytes_read = file.read(&buffer) catch return;
                if (bytes_read == 0) {
                    break;
                }
                accumulator.appendSlice(buffer[0..bytes_read]) catch return;
            }
        }
        var word = std.ArrayList(u8).init(self.allocator);
        defer word.deinit();

        var i: usize = 0;
        while (i < accumulator.items.len) : (i += 1) {
            if (accumulator.items[i] == ' ' or accumulator.items[i] == '\n') {
                if (word.items.len > 0) {
                    self.dictionary.add(word.items, word.items.len + 1) catch return;
                    word.clearAndFree();
                }
            } else {
                word.append(accumulator.items[i]) catch return;
            }
        }
    }
    pub fn suggestSimilarWord(self: *SpellCorrector, input_word: []const u8, size: usize) Allocator.Error!?[]u8 {
        var lower_word = try self.allocator.alloc(u8, size);
        for (0..(size - 1)) |i| {
            lower_word[i] = std.ascii.toLower(input_word[i]);
        }
        lower_word[size - 1] = 0;
        if (try self.dictionary.find(lower_word, size) != null) {
            return lower_word;
        }
        var edit_dist1 = std.StringHashMap([]u8).init(self.allocator);
        defer edit_dist1.deinit();
        self.genEditDist1(&edit_dist1, lower_word, size);
        {
            var matches = std.ArrayList([]u8).init(self.allocator);
            defer matches.deinit();
            var iterator = edit_dist1.iterator();
            var word = iterator.next();
            while (word != null) {
                var node = try self.dictionary.find(word.?.value_ptr.*, word.?.value_ptr.*.len);
                if (node != null) {
                    try matches.append(word.?.value_ptr.*);
                }
                word = iterator.next();
            }

            var out_str = makeOptionalString();
            var out_freq: usize = 0;
            for (matches.items) |match| {
                var node = try self.dictionary.find(match, match.len);
                if (node != null and out_freq < node.?.getFreq()) {
                    out_str = match;
                    out_freq = node.?.getFreq();
                }
            }
            if (out_str != null) {
                return out_str;
            }
        }
        var edit_dist2 = std.StringHashMap([]u8).init(self.allocator);
        defer edit_dist2.deinit();
        self.genEditDist2(&edit_dist2, edit_dist1);

        var matches = std.ArrayList([]u8).init(self.allocator);
        defer matches.deinit();
        var iterator = edit_dist1.iterator();
        var word = iterator.next();
        while (word != null) {
            var node = try self.dictionary.find(word.?.value_ptr.*, word.?.value_ptr.*.len);
            if (node != null) {
                try matches.append(word.?.value_ptr.*);
            }
            word = iterator.next();
        }

        var out_str = makeOptionalString();
        var out_freq: usize = 0;

        for (matches.items) |match| {
            var node = try self.dictionary.find(match, match.len);
            if (node != null and out_freq < node.?.getFreq()) {
                out_str = match;
                out_freq = node.?.getFreq();
            }
        }

        if (out_str != null) {
            return out_str;
        } else {
            return null;
        }
    }
    fn deleteChar(self: *SpellCorrector, words: *std.StringHashMap([]u8), word: []u8, size: usize) void {
        for (0..size) |i| {
            var new_word = self.allocator.alloc(u8, size - 1) catch return;
            var j: usize = 0;
            for (0..size) |k| {
                if (k != i) {
                    new_word[j] = word[k];
                    j += 1;
                }
            }
            new_word[size - 2] = 0;
            words.put(new_word, new_word) catch return;
        }
    }
    fn transposeChar(self: *SpellCorrector, words: *std.StringHashMap([]u8), word: []u8, size: usize) void {
        for (0..(size)) |i| {
            var c1 = word[i];
            for (1..size) |j| {
                var c2 = word[j];
                if (c1 == c2) {
                    continue;
                }
                var new_word = self.allocator.alloc(u8, size) catch return;
                new_word[i] = c2;
                new_word[j] = c1;
                var k: usize = 0;
                for (0..size) |l| {
                    if (l != i and l != j) {
                        new_word[k] = word[l];
                        k += 1;
                    }
                }
                new_word[size - 1] = 0;

                words.put(new_word, new_word) catch return;
            }
        }
    }
    fn alternateChar(self: *SpellCorrector, words: *std.StringHashMap([]u8), word: []u8, size: usize) void {
        var alphabet = [_]u8{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' };
        for (0..(size)) |i| {
            for (alphabet) |c| {
                if (word[i] == c) {
                    continue;
                }
                var new_word = self.allocator.alloc(u8, size) catch return;

                for (0..size) |j| {
                    if (j == i) {
                        new_word[j] = c;
                    } else {
                        new_word[j] = word[j];
                    }
                }
                new_word[size - 1] = 0;
                words.put(new_word, new_word) catch return;
            }
        }
    }
    fn insertChar(self: *SpellCorrector, words: *std.StringHashMap([]u8), word: []u8, size: usize) void {
        var alphabet = [_]u8{ 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' };
        for (0..(size + 1)) |i| {
            for (alphabet) |c| {
                var new_word = self.allocator.alloc(u8, size + 1) catch return;
                var j: usize = 0;
                for (0..(size + 1)) |k| {
                    if (k == i) {
                        new_word[k] = c;
                    } else {
                        new_word[k] = word[j];
                        j += 1;
                    }
                }
                new_word[size] = 0;
                words.put(new_word, new_word) catch return;
            }
        }
    }
    fn genEditDist1(self: *SpellCorrector, words: *std.StringHashMap([]u8), word: []u8, size: usize) void {
        self.deleteChar(words, word, size);
        self.transposeChar(words, word, size);
        self.alternateChar(words, word, size);
        self.insertChar(words, word, size);
    }
    fn genEditDist2(self: *SpellCorrector, words: *std.StringHashMap([]u8), edit_dist1: std.StringHashMap([]u8)) void {
        var iterator = edit_dist1.iterator();
        var word = iterator.next();
        while (word != null) {
            self.genEditDist1(words, word.?.value_ptr.*, word.?.value_ptr.len);
            word = iterator.next();
        }
    }
    pub fn toString(self: *SpellCorrector) []const u8 {
        return self.dictionary.toString() catch return "failed to convert dictionary to string";
    }
};

fn makeOptionalString() ?[]u8 {
    return null;
}
