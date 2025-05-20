const c = @cImport({
    @cInclude("Zycore/Status.h");
});

pub fn zyanMakeStatus(err: u32, module: u32, code: u32) c.ZyanStatus {
    return ((err & 1) << 31) | ((module & 0x7FF) << 20) | (code & 0xFFFFF);
}
