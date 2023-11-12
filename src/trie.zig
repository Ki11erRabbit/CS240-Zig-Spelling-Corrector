const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

pub const Node = struct {
    data: u8,
    freq: u32,
    children: [26]?*Node,
    pub fn init(allocator: Allocator, data: u8) Allocator.Error!*Node {
        var node: *Node = allocator.create(Node) catch |err| {
            return err;
        };
        node.* = Node{
            .data = data,
            .freq = 0,
            .children = [_]?*Node{ null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null, null },
        };
        return node;
    }
    pub fn getValue(self: *Node) u8 {
        return self.data;
    }
    pub fn getFreq(self: *Node) u32 {
        return self.freq;
    }
    pub fn getChildren(self: *Node) *[26]?*Node {
        return &self.children;
    }
    pub fn incrementFreq(self: *Node) void {
        self.freq += 1;
    }
};

pub const Trie = struct {
    root: *Node,
    num_nodes: u32,
    num_words: u32,
    allocator: Allocator,
    pub fn init(allocator: Allocator) Allocator.Error!Trie {
        var root = Node.init(allocator, 0) catch |err| {
            return err;
        };

        return Trie{
            .root = root,
            .num_nodes = 1,
            .num_words = 0,
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *Trie) void {
        self.allocator.destroy(self.root);
        //self.allocator.free(self.root);
    }
    pub fn add(self: *Trie, word: []const u8, size: usize) Allocator.Error!void {
        var lower_word = try self.allocator.alloc(u8, size);
        for (0..(size - 1)) |i| {
            lower_word[i] = std.ascii.toLower(word[i]);
        }
        lower_word[size - 1] = 0;
        var curr_node: *Node = self.root;

        var i: u32 = 0;
        for (lower_word) |c| {
            if (c == 0) {
                break;
            }
            //std.debug.print("{c}\n", .{c});
            var index = c - 'a';
            //std.debug.print("{d}\n", .{index});

            if (curr_node.getChildren()[index] != null) {
                curr_node = curr_node.getChildren()[index].?;
            } else {
                curr_node.getChildren()[index] = try Node.init(self.allocator, c);
                curr_node = curr_node.getChildren()[index].?;
                self.num_nodes += 1;
            }
            if ((curr_node.getFreq() < 1) and (i == size - 2)) {
                self.num_words += 1;
                curr_node.incrementFreq();
            } else if (curr_node.getFreq() > 0 and i == size - 2) {
                curr_node.incrementFreq();
            }
            i += 1;
        }
        self.allocator.free(lower_word);
    }
    pub fn find(self: *Trie, word: []const u8, size: usize) Allocator.Error!?*Node {
        var lower_word = try self.allocator.alloc(u8, size);
        for (0..(size - 1)) |i| {
            lower_word[i] = std.ascii.toLower(word[i]);
        }
        lower_word[size - 1] = 0;

        var curr_node = self.root;

        for (lower_word) |c| {
            if (c == 0) {
                break;
            }
            var index = c - 'a';

            if (curr_node.getChildren()[index] != null) {
                curr_node = curr_node.getChildren()[index].?;
            } else {
                return null;
            }
        }
        self.allocator.free(lower_word);
        return curr_node;
    }
    pub fn getNumNodes(self: *Trie) u32 {
        return self.num_nodes;
    }
    pub fn getNumWords(self: *Trie) u32 {
        return self.num_words;
    }
    fn toStringHelper(alloc: Allocator, curr_node: *Node, holder: *std.ArrayList(u8), out: *std.ArrayList(u8)) Allocator.Error!void {
        //std.debug.print("Out: {s}\n", .{out.items});
        for (0..25) |i| {
            //std.debug.print("{d}\n", .{i});
            if (curr_node.getChildren()[i] == null) {
                continue;
            }
            var next_node = curr_node.getChildren()[i].?;
            try holder.append(next_node.getValue());
            //std.debug.print("Value: {c}\n", .{next_node.getValue()});
            if (next_node.getFreq() > 0) {
                //std.debug.print("Holder1: \n", .{});
                var holder_clone = try holder.clone();
                try out.appendSlice(try holder_clone.toOwnedSlice());
                try out.append('\n');
                //std.debug.print("Out: {s}\n", .{out.items});
                holder_clone.deinit();
            }
            try toStringHelper(alloc, next_node, holder, out);
            //new_holder.deinit();
            //std.debug.print("popping\n", .{});
            _ = holder.pop();
        }
    }
    pub fn toString(self: *Trie) Allocator.Error![]u8 {
        //std.debug.print("Number of nodes: {d}\n", .{self.getNumNodes()});

        var holder = std.ArrayList(u8).init(self.allocator);
        //std.debug.print("Number of nodes: {d}\n", .{self.getNumNodes()});
        var out = std.ArrayList(u8).init(self.allocator);
        //std.debug.print("Number of nodes: {d}\n", .{self.getNumNodes()});

        try toStringHelper(self.allocator, self.root, &holder, &out);
        //std.debug.print("Number of nodes: {d}\n", .{self.getNumNodes()});
        try out.append(0);
        return out.toOwnedSlice();
    }
};

// pub fn main() void {
//     var gpa = std.heap.GeneralPurposeAllocator(.{}){};

//     const allocator = gpa.allocator();

//     var trie = Trie.init(allocator) catch |err| {
//         if (err == Allocator.Error.OutOfMemory) {
//             std.debug.print("Error: {!}\n", .{err});
//         } else {
//             std.debug.print("Error: {!}\n", .{err});
//         }
//         return;
//     };

//     trie.add("hello", 6) catch |err| {
//         std.debug.print("Error: {!}\n", .{err});
//     };

//     trie.add("world", 6) catch |err| {
//         std.debug.print("Error: {!}\n", .{err});
//     };

//     trie.add("hello", 6) catch |err| {
//         std.debug.print("Error: {!}\n", .{err});
//     };
//     trie.add("happiness", 10) catch |err| {
//         std.debug.print("Error: {!}\n", .{err});
//     };

//     //std.debug.print("Number of nodes: {d}\n", .{trie.getNumNodes()});

//     const contents = trie.toString() catch |err| {
//         std.debug.print("Error: {!}\n", .{err});
//         return;
//     };

//     std.debug.print("{s}\n", .{contents});

//     var node = trie.find("hello", 6) catch |err| {
//         std.debug.print("Error: {!}\n", .{err});
//         return;
//     };

//     std.debug.print("Freq: {d}\n", .{node.?.getFreq()});
// }
