const c = @cImport({
    @cInclude("Zycore/Status.h");
});

pub fn ZYAN_MAKE_STATUS(comptime err: u32, comptime module: u32, comptime code: u32) c.ZyanStatus {
    return ((err & 1) << 31) | ((module & 0x7FF) << 20) | (code & 0xFFFFF);
}
