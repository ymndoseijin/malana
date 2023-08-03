const BoxState = packed struct {
    expand: Direction,
    layout: Direction,
};

const Box = struct {
    width: f32,
    height: f32,

    state: BoxState,
    children: std.ArrayList(*Box),

    pub fn update(self: *Box) {

        var offset: f32 = 0;
        for (self.children) |child| {
            try child.update();
            offset += child.getSize(self.state.layout);
        }
    }
};
