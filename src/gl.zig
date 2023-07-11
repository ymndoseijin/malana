// NOTICE
//
// This work uses definitions from the OpenGL XML API Registry
// <https://github.com/KhronosGroup/OpenGL-Registry>.
// Copyright 2013-2020 The Khronos Group Inc.
// Licensed under Apache-2.0.
//
// END OF NOTICE

const std = @import("std");
const root = @import("root");

/// Static information about this source file and when/how it was generated.
pub const about = struct {
    pub const api_name = "OpenGL 4.1 (Core Profile)";
    pub const api_version_major = 4;
    pub const api_version_minor = 1;

    pub const generated_at = "2023-07-08T18:56:08Z";

    pub const generator_name = "zigglgen v0.4.1";
    pub const generator_url = "https://castholm.github.io/zigglgen/";
};

/// Makes the specified dispatch table current on the calling thread. This function must be called
/// with a valid dispatch table before calling `extensionSupported()` or any OpenGL command
/// functions on that same thread.
pub fn makeDispatchTableCurrent(dispatch_table: ?*const DispatchTable) void {
    DispatchTable.current = dispatch_table;
}

/// Returns the dispatch table that is current on the calling thread, or `null` if no dispatch table
/// is current.
pub fn getCurrentDispatchTable() ?*const DispatchTable {
    return DispatchTable.current;
}

//#region Types
pub const Byte = i8;
pub const Ubyte = u8;
pub const Short = c_short;
pub const Ushort = c_ushort;
pub const Int = c_int;
pub const Uint = c_uint;
pub const Int64 = i64;
pub const Uint64 = u64;
pub const Intptr = isize;
pub const Half = c_ushort;
pub const Float = f32;
pub const Double = f64;
pub const Boolean = u8;
pub const Char = u8;
pub const Bitfield = c_uint;
pub const Enum = c_uint;
pub const Sizei = c_int;
pub const Sizeiptr = isize;
pub const Clampf = f32;
pub const Clampd = f64;
pub const Sync = ?*opaque {};
//#endregion Types

//#region Constants
pub const ZERO = 0x0;
pub const ONE = 0x1;
pub const FALSE = 0x0;
pub const TRUE = 0x1;
pub const NONE = 0x0;
pub const NO_ERROR = 0x0;
pub const INVALID_INDEX = 0xFFFFFFFF;
pub const TIMEOUT_IGNORED = 0xFFFFFFFFFFFFFFFF;
pub const DEPTH_BUFFER_BIT = 0x100;
pub const STENCIL_BUFFER_BIT = 0x400;
pub const COLOR_BUFFER_BIT = 0x4000;
pub const CONTEXT_FLAG_FORWARD_COMPATIBLE_BIT = 0x1;
pub const CONTEXT_CORE_PROFILE_BIT = 0x1;
pub const CONTEXT_COMPATIBILITY_PROFILE_BIT = 0x2;
pub const MAP_READ_BIT = 0x1;
pub const MAP_WRITE_BIT = 0x2;
pub const MAP_INVALIDATE_RANGE_BIT = 0x4;
pub const MAP_INVALIDATE_BUFFER_BIT = 0x8;
pub const MAP_FLUSH_EXPLICIT_BIT = 0x10;
pub const MAP_UNSYNCHRONIZED_BIT = 0x20;
pub const SYNC_FLUSH_COMMANDS_BIT = 0x1;
pub const VERTEX_SHADER_BIT = 0x1;
pub const FRAGMENT_SHADER_BIT = 0x2;
pub const GEOMETRY_SHADER_BIT = 0x4;
pub const TESS_CONTROL_SHADER_BIT = 0x8;
pub const TESS_EVALUATION_SHADER_BIT = 0x10;
pub const ALL_SHADER_BITS = 0xFFFFFFFF;
pub const POINTS = 0x0;
pub const LINES = 0x1;
pub const LINE_LOOP = 0x2;
pub const LINE_STRIP = 0x3;
pub const TRIANGLES = 0x4;
pub const TRIANGLE_STRIP = 0x5;
pub const TRIANGLE_FAN = 0x6;
pub const QUADS = 0x7;
pub const LINES_ADJACENCY = 0xA;
pub const LINE_STRIP_ADJACENCY = 0xB;
pub const TRIANGLES_ADJACENCY = 0xC;
pub const TRIANGLE_STRIP_ADJACENCY = 0xD;
pub const PATCHES = 0xE;
pub const NEVER = 0x200;
pub const LESS = 0x201;
pub const EQUAL = 0x202;
pub const LEQUAL = 0x203;
pub const GREATER = 0x204;
pub const NOTEQUAL = 0x205;
pub const GEQUAL = 0x206;
pub const ALWAYS = 0x207;
pub const SRC_COLOR = 0x300;
pub const ONE_MINUS_SRC_COLOR = 0x301;
pub const SRC_ALPHA = 0x302;
pub const ONE_MINUS_SRC_ALPHA = 0x303;
pub const DST_ALPHA = 0x304;
pub const ONE_MINUS_DST_ALPHA = 0x305;
pub const DST_COLOR = 0x306;
pub const ONE_MINUS_DST_COLOR = 0x307;
pub const SRC_ALPHA_SATURATE = 0x308;
pub const FRONT_LEFT = 0x400;
pub const FRONT_RIGHT = 0x401;
pub const BACK_LEFT = 0x402;
pub const BACK_RIGHT = 0x403;
pub const FRONT = 0x404;
pub const BACK = 0x405;
pub const LEFT = 0x406;
pub const RIGHT = 0x407;
pub const FRONT_AND_BACK = 0x408;
pub const INVALID_ENUM = 0x500;
pub const INVALID_VALUE = 0x501;
pub const INVALID_OPERATION = 0x502;
pub const OUT_OF_MEMORY = 0x505;
pub const INVALID_FRAMEBUFFER_OPERATION = 0x506;
pub const CW = 0x900;
pub const CCW = 0x901;
pub const POINT_SIZE = 0xB11;
pub const POINT_SIZE_RANGE = 0xB12;
pub const SMOOTH_POINT_SIZE_RANGE = 0xB12;
pub const POINT_SIZE_GRANULARITY = 0xB13;
pub const SMOOTH_POINT_SIZE_GRANULARITY = 0xB13;
pub const LINE_SMOOTH = 0xB20;
pub const LINE_WIDTH = 0xB21;
pub const LINE_WIDTH_RANGE = 0xB22;
pub const SMOOTH_LINE_WIDTH_RANGE = 0xB22;
pub const LINE_WIDTH_GRANULARITY = 0xB23;
pub const SMOOTH_LINE_WIDTH_GRANULARITY = 0xB23;
pub const POLYGON_MODE = 0xB40;
pub const POLYGON_SMOOTH = 0xB41;
pub const CULL_FACE = 0xB44;
pub const CULL_FACE_MODE = 0xB45;
pub const FRONT_FACE = 0xB46;
pub const DEPTH_RANGE = 0xB70;
pub const DEPTH_TEST = 0xB71;
pub const DEPTH_WRITEMASK = 0xB72;
pub const DEPTH_CLEAR_VALUE = 0xB73;
pub const DEPTH_FUNC = 0xB74;
pub const STENCIL_TEST = 0xB90;
pub const STENCIL_CLEAR_VALUE = 0xB91;
pub const STENCIL_FUNC = 0xB92;
pub const STENCIL_VALUE_MASK = 0xB93;
pub const STENCIL_FAIL = 0xB94;
pub const STENCIL_PASS_DEPTH_FAIL = 0xB95;
pub const STENCIL_PASS_DEPTH_PASS = 0xB96;
pub const STENCIL_REF = 0xB97;
pub const STENCIL_WRITEMASK = 0xB98;
pub const VIEWPORT = 0xBA2;
pub const DITHER = 0xBD0;
pub const BLEND_DST = 0xBE0;
pub const BLEND_SRC = 0xBE1;
pub const BLEND = 0xBE2;
pub const LOGIC_OP_MODE = 0xBF0;
pub const COLOR_LOGIC_OP = 0xBF2;
pub const DRAW_BUFFER = 0xC01;
pub const READ_BUFFER = 0xC02;
pub const SCISSOR_BOX = 0xC10;
pub const SCISSOR_TEST = 0xC11;
pub const COLOR_CLEAR_VALUE = 0xC22;
pub const COLOR_WRITEMASK = 0xC23;
pub const DOUBLEBUFFER = 0xC32;
pub const STEREO = 0xC33;
pub const LINE_SMOOTH_HINT = 0xC52;
pub const POLYGON_SMOOTH_HINT = 0xC53;
pub const UNPACK_SWAP_BYTES = 0xCF0;
pub const UNPACK_LSB_FIRST = 0xCF1;
pub const UNPACK_ROW_LENGTH = 0xCF2;
pub const UNPACK_SKIP_ROWS = 0xCF3;
pub const UNPACK_SKIP_PIXELS = 0xCF4;
pub const UNPACK_ALIGNMENT = 0xCF5;
pub const PACK_SWAP_BYTES = 0xD00;
pub const PACK_LSB_FIRST = 0xD01;
pub const PACK_ROW_LENGTH = 0xD02;
pub const PACK_SKIP_ROWS = 0xD03;
pub const PACK_SKIP_PIXELS = 0xD04;
pub const PACK_ALIGNMENT = 0xD05;
pub const MAX_CLIP_DISTANCES = 0xD32;
pub const MAX_TEXTURE_SIZE = 0xD33;
pub const MAX_VIEWPORT_DIMS = 0xD3A;
pub const SUBPIXEL_BITS = 0xD50;
pub const TEXTURE_1D = 0xDE0;
pub const TEXTURE_2D = 0xDE1;
pub const TEXTURE_WIDTH = 0x1000;
pub const TEXTURE_HEIGHT = 0x1001;
pub const TEXTURE_INTERNAL_FORMAT = 0x1003;
pub const TEXTURE_BORDER_COLOR = 0x1004;
pub const DONT_CARE = 0x1100;
pub const FASTEST = 0x1101;
pub const NICEST = 0x1102;
pub const BYTE = 0x1400;
pub const UNSIGNED_BYTE = 0x1401;
pub const SHORT = 0x1402;
pub const UNSIGNED_SHORT = 0x1403;
pub const INT = 0x1404;
pub const UNSIGNED_INT = 0x1405;
pub const FLOAT = 0x1406;
pub const DOUBLE = 0x140A;
pub const HALF_FLOAT = 0x140B;
pub const FIXED = 0x140C;
pub const CLEAR = 0x1500;
pub const AND = 0x1501;
pub const AND_REVERSE = 0x1502;
pub const COPY = 0x1503;
pub const AND_INVERTED = 0x1504;
pub const NOOP = 0x1505;
pub const XOR = 0x1506;
pub const OR = 0x1507;
pub const NOR = 0x1508;
pub const EQUIV = 0x1509;
pub const INVERT = 0x150A;
pub const OR_REVERSE = 0x150B;
pub const COPY_INVERTED = 0x150C;
pub const OR_INVERTED = 0x150D;
pub const NAND = 0x150E;
pub const SET = 0x150F;
pub const TEXTURE = 0x1702;
pub const COLOR = 0x1800;
pub const DEPTH = 0x1801;
pub const STENCIL = 0x1802;
pub const STENCIL_INDEX = 0x1901;
pub const DEPTH_COMPONENT = 0x1902;
pub const RED = 0x1903;
pub const GREEN = 0x1904;
pub const BLUE = 0x1905;
pub const ALPHA = 0x1906;
pub const RGB = 0x1907;
pub const RGBA = 0x1908;
pub const POINT = 0x1B00;
pub const LINE = 0x1B01;
pub const FILL = 0x1B02;
pub const KEEP = 0x1E00;
pub const REPLACE = 0x1E01;
pub const INCR = 0x1E02;
pub const DECR = 0x1E03;
pub const VENDOR = 0x1F00;
pub const RENDERER = 0x1F01;
pub const VERSION = 0x1F02;
pub const EXTENSIONS = 0x1F03;
pub const NEAREST = 0x2600;
pub const LINEAR = 0x2601;
pub const NEAREST_MIPMAP_NEAREST = 0x2700;
pub const LINEAR_MIPMAP_NEAREST = 0x2701;
pub const NEAREST_MIPMAP_LINEAR = 0x2702;
pub const LINEAR_MIPMAP_LINEAR = 0x2703;
pub const TEXTURE_MAG_FILTER = 0x2800;
pub const TEXTURE_MIN_FILTER = 0x2801;
pub const TEXTURE_WRAP_S = 0x2802;
pub const TEXTURE_WRAP_T = 0x2803;
pub const REPEAT = 0x2901;
pub const POLYGON_OFFSET_UNITS = 0x2A00;
pub const POLYGON_OFFSET_POINT = 0x2A01;
pub const POLYGON_OFFSET_LINE = 0x2A02;
pub const R3_G3_B2 = 0x2A10;
pub const CLIP_DISTANCE0 = 0x3000;
pub const CLIP_DISTANCE1 = 0x3001;
pub const CLIP_DISTANCE2 = 0x3002;
pub const CLIP_DISTANCE3 = 0x3003;
pub const CLIP_DISTANCE4 = 0x3004;
pub const CLIP_DISTANCE5 = 0x3005;
pub const CLIP_DISTANCE6 = 0x3006;
pub const CLIP_DISTANCE7 = 0x3007;
pub const CONSTANT_COLOR = 0x8001;
pub const ONE_MINUS_CONSTANT_COLOR = 0x8002;
pub const CONSTANT_ALPHA = 0x8003;
pub const ONE_MINUS_CONSTANT_ALPHA = 0x8004;
pub const BLEND_COLOR = 0x8005;
pub const FUNC_ADD = 0x8006;
pub const MIN = 0x8007;
pub const MAX = 0x8008;
pub const BLEND_EQUATION = 0x8009;
pub const BLEND_EQUATION_RGB = 0x8009;
pub const FUNC_SUBTRACT = 0x800A;
pub const FUNC_REVERSE_SUBTRACT = 0x800B;
pub const UNSIGNED_BYTE_3_3_2 = 0x8032;
pub const UNSIGNED_SHORT_4_4_4_4 = 0x8033;
pub const UNSIGNED_SHORT_5_5_5_1 = 0x8034;
pub const UNSIGNED_INT_8_8_8_8 = 0x8035;
pub const UNSIGNED_INT_10_10_10_2 = 0x8036;
pub const POLYGON_OFFSET_FILL = 0x8037;
pub const POLYGON_OFFSET_FACTOR = 0x8038;
pub const RGB4 = 0x804F;
pub const RGB5 = 0x8050;
pub const RGB8 = 0x8051;
pub const RGB10 = 0x8052;
pub const RGB12 = 0x8053;
pub const RGB16 = 0x8054;
pub const RGBA2 = 0x8055;
pub const RGBA4 = 0x8056;
pub const RGB5_A1 = 0x8057;
pub const RGBA8 = 0x8058;
pub const RGB10_A2 = 0x8059;
pub const RGBA12 = 0x805A;
pub const RGBA16 = 0x805B;
pub const TEXTURE_RED_SIZE = 0x805C;
pub const TEXTURE_GREEN_SIZE = 0x805D;
pub const TEXTURE_BLUE_SIZE = 0x805E;
pub const TEXTURE_ALPHA_SIZE = 0x805F;
pub const PROXY_TEXTURE_1D = 0x8063;
pub const PROXY_TEXTURE_2D = 0x8064;
pub const TEXTURE_BINDING_1D = 0x8068;
pub const TEXTURE_BINDING_2D = 0x8069;
pub const TEXTURE_BINDING_3D = 0x806A;
pub const PACK_SKIP_IMAGES = 0x806B;
pub const PACK_IMAGE_HEIGHT = 0x806C;
pub const UNPACK_SKIP_IMAGES = 0x806D;
pub const UNPACK_IMAGE_HEIGHT = 0x806E;
pub const TEXTURE_3D = 0x806F;
pub const PROXY_TEXTURE_3D = 0x8070;
pub const TEXTURE_DEPTH = 0x8071;
pub const TEXTURE_WRAP_R = 0x8072;
pub const MAX_3D_TEXTURE_SIZE = 0x8073;
pub const MULTISAMPLE = 0x809D;
pub const SAMPLE_ALPHA_TO_COVERAGE = 0x809E;
pub const SAMPLE_ALPHA_TO_ONE = 0x809F;
pub const SAMPLE_COVERAGE = 0x80A0;
pub const SAMPLE_BUFFERS = 0x80A8;
pub const SAMPLES = 0x80A9;
pub const SAMPLE_COVERAGE_VALUE = 0x80AA;
pub const SAMPLE_COVERAGE_INVERT = 0x80AB;
pub const BLEND_DST_RGB = 0x80C8;
pub const BLEND_SRC_RGB = 0x80C9;
pub const BLEND_DST_ALPHA = 0x80CA;
pub const BLEND_SRC_ALPHA = 0x80CB;
pub const BGR = 0x80E0;
pub const BGRA = 0x80E1;
pub const MAX_ELEMENTS_VERTICES = 0x80E8;
pub const MAX_ELEMENTS_INDICES = 0x80E9;
pub const POINT_FADE_THRESHOLD_SIZE = 0x8128;
pub const CLAMP_TO_BORDER = 0x812D;
pub const CLAMP_TO_EDGE = 0x812F;
pub const TEXTURE_MIN_LOD = 0x813A;
pub const TEXTURE_MAX_LOD = 0x813B;
pub const TEXTURE_BASE_LEVEL = 0x813C;
pub const TEXTURE_MAX_LEVEL = 0x813D;
pub const DEPTH_COMPONENT16 = 0x81A5;
pub const DEPTH_COMPONENT24 = 0x81A6;
pub const DEPTH_COMPONENT32 = 0x81A7;
pub const FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING = 0x8210;
pub const FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE = 0x8211;
pub const FRAMEBUFFER_ATTACHMENT_RED_SIZE = 0x8212;
pub const FRAMEBUFFER_ATTACHMENT_GREEN_SIZE = 0x8213;
pub const FRAMEBUFFER_ATTACHMENT_BLUE_SIZE = 0x8214;
pub const FRAMEBUFFER_ATTACHMENT_ALPHA_SIZE = 0x8215;
pub const FRAMEBUFFER_ATTACHMENT_DEPTH_SIZE = 0x8216;
pub const FRAMEBUFFER_ATTACHMENT_STENCIL_SIZE = 0x8217;
pub const FRAMEBUFFER_DEFAULT = 0x8218;
pub const FRAMEBUFFER_UNDEFINED = 0x8219;
pub const DEPTH_STENCIL_ATTACHMENT = 0x821A;
pub const MAJOR_VERSION = 0x821B;
pub const MINOR_VERSION = 0x821C;
pub const NUM_EXTENSIONS = 0x821D;
pub const CONTEXT_FLAGS = 0x821E;
pub const COMPRESSED_RED = 0x8225;
pub const COMPRESSED_RG = 0x8226;
pub const RG = 0x8227;
pub const RG_INTEGER = 0x8228;
pub const R8 = 0x8229;
pub const R16 = 0x822A;
pub const RG8 = 0x822B;
pub const RG16 = 0x822C;
pub const R16F = 0x822D;
pub const R32F = 0x822E;
pub const RG16F = 0x822F;
pub const RG32F = 0x8230;
pub const R8I = 0x8231;
pub const R8UI = 0x8232;
pub const R16I = 0x8233;
pub const R16UI = 0x8234;
pub const R32I = 0x8235;
pub const R32UI = 0x8236;
pub const RG8I = 0x8237;
pub const RG8UI = 0x8238;
pub const RG16I = 0x8239;
pub const RG16UI = 0x823A;
pub const RG32I = 0x823B;
pub const RG32UI = 0x823C;
pub const PROGRAM_BINARY_RETRIEVABLE_HINT = 0x8257;
pub const PROGRAM_SEPARABLE = 0x8258;
pub const ACTIVE_PROGRAM = 0x8259;
pub const PROGRAM_PIPELINE_BINDING = 0x825A;
pub const MAX_VIEWPORTS = 0x825B;
pub const VIEWPORT_SUBPIXEL_BITS = 0x825C;
pub const VIEWPORT_BOUNDS_RANGE = 0x825D;
pub const LAYER_PROVOKING_VERTEX = 0x825E;
pub const VIEWPORT_INDEX_PROVOKING_VERTEX = 0x825F;
pub const UNDEFINED_VERTEX = 0x8260;
pub const UNSIGNED_BYTE_2_3_3_REV = 0x8362;
pub const UNSIGNED_SHORT_5_6_5 = 0x8363;
pub const UNSIGNED_SHORT_5_6_5_REV = 0x8364;
pub const UNSIGNED_SHORT_4_4_4_4_REV = 0x8365;
pub const UNSIGNED_SHORT_1_5_5_5_REV = 0x8366;
pub const UNSIGNED_INT_8_8_8_8_REV = 0x8367;
pub const UNSIGNED_INT_2_10_10_10_REV = 0x8368;
pub const MIRRORED_REPEAT = 0x8370;
pub const ALIASED_LINE_WIDTH_RANGE = 0x846E;
pub const TEXTURE0 = 0x84C0;
pub const TEXTURE1 = 0x84C1;
pub const TEXTURE2 = 0x84C2;
pub const TEXTURE3 = 0x84C3;
pub const TEXTURE4 = 0x84C4;
pub const TEXTURE5 = 0x84C5;
pub const TEXTURE6 = 0x84C6;
pub const TEXTURE7 = 0x84C7;
pub const TEXTURE8 = 0x84C8;
pub const TEXTURE9 = 0x84C9;
pub const TEXTURE10 = 0x84CA;
pub const TEXTURE11 = 0x84CB;
pub const TEXTURE12 = 0x84CC;
pub const TEXTURE13 = 0x84CD;
pub const TEXTURE14 = 0x84CE;
pub const TEXTURE15 = 0x84CF;
pub const TEXTURE16 = 0x84D0;
pub const TEXTURE17 = 0x84D1;
pub const TEXTURE18 = 0x84D2;
pub const TEXTURE19 = 0x84D3;
pub const TEXTURE20 = 0x84D4;
pub const TEXTURE21 = 0x84D5;
pub const TEXTURE22 = 0x84D6;
pub const TEXTURE23 = 0x84D7;
pub const TEXTURE24 = 0x84D8;
pub const TEXTURE25 = 0x84D9;
pub const TEXTURE26 = 0x84DA;
pub const TEXTURE27 = 0x84DB;
pub const TEXTURE28 = 0x84DC;
pub const TEXTURE29 = 0x84DD;
pub const TEXTURE30 = 0x84DE;
pub const TEXTURE31 = 0x84DF;
pub const ACTIVE_TEXTURE = 0x84E0;
pub const MAX_RENDERBUFFER_SIZE = 0x84E8;
pub const COMPRESSED_RGB = 0x84ED;
pub const COMPRESSED_RGBA = 0x84EE;
pub const TEXTURE_COMPRESSION_HINT = 0x84EF;
pub const UNIFORM_BLOCK_REFERENCED_BY_TESS_CONTROL_SHADER = 0x84F0;
pub const UNIFORM_BLOCK_REFERENCED_BY_TESS_EVALUATION_SHADER = 0x84F1;
pub const TEXTURE_RECTANGLE = 0x84F5;
pub const TEXTURE_BINDING_RECTANGLE = 0x84F6;
pub const PROXY_TEXTURE_RECTANGLE = 0x84F7;
pub const MAX_RECTANGLE_TEXTURE_SIZE = 0x84F8;
pub const DEPTH_STENCIL = 0x84F9;
pub const UNSIGNED_INT_24_8 = 0x84FA;
pub const MAX_TEXTURE_LOD_BIAS = 0x84FD;
pub const TEXTURE_LOD_BIAS = 0x8501;
pub const INCR_WRAP = 0x8507;
pub const DECR_WRAP = 0x8508;
pub const TEXTURE_CUBE_MAP = 0x8513;
pub const TEXTURE_BINDING_CUBE_MAP = 0x8514;
pub const TEXTURE_CUBE_MAP_POSITIVE_X = 0x8515;
pub const TEXTURE_CUBE_MAP_NEGATIVE_X = 0x8516;
pub const TEXTURE_CUBE_MAP_POSITIVE_Y = 0x8517;
pub const TEXTURE_CUBE_MAP_NEGATIVE_Y = 0x8518;
pub const TEXTURE_CUBE_MAP_POSITIVE_Z = 0x8519;
pub const TEXTURE_CUBE_MAP_NEGATIVE_Z = 0x851A;
pub const PROXY_TEXTURE_CUBE_MAP = 0x851B;
pub const MAX_CUBE_MAP_TEXTURE_SIZE = 0x851C;
pub const SRC1_ALPHA = 0x8589;
pub const VERTEX_ARRAY_BINDING = 0x85B5;
pub const VERTEX_ATTRIB_ARRAY_ENABLED = 0x8622;
pub const VERTEX_ATTRIB_ARRAY_SIZE = 0x8623;
pub const VERTEX_ATTRIB_ARRAY_STRIDE = 0x8624;
pub const VERTEX_ATTRIB_ARRAY_TYPE = 0x8625;
pub const CURRENT_VERTEX_ATTRIB = 0x8626;
pub const PROGRAM_POINT_SIZE = 0x8642;
pub const VERTEX_PROGRAM_POINT_SIZE = 0x8642;
pub const VERTEX_ATTRIB_ARRAY_POINTER = 0x8645;
pub const DEPTH_CLAMP = 0x864F;
pub const TEXTURE_COMPRESSED_IMAGE_SIZE = 0x86A0;
pub const TEXTURE_COMPRESSED = 0x86A1;
pub const NUM_COMPRESSED_TEXTURE_FORMATS = 0x86A2;
pub const COMPRESSED_TEXTURE_FORMATS = 0x86A3;
pub const PROGRAM_BINARY_LENGTH = 0x8741;
pub const BUFFER_SIZE = 0x8764;
pub const BUFFER_USAGE = 0x8765;
pub const NUM_PROGRAM_BINARY_FORMATS = 0x87FE;
pub const PROGRAM_BINARY_FORMATS = 0x87FF;
pub const STENCIL_BACK_FUNC = 0x8800;
pub const STENCIL_BACK_FAIL = 0x8801;
pub const STENCIL_BACK_PASS_DEPTH_FAIL = 0x8802;
pub const STENCIL_BACK_PASS_DEPTH_PASS = 0x8803;
pub const RGBA32F = 0x8814;
pub const RGB32F = 0x8815;
pub const RGBA16F = 0x881A;
pub const RGB16F = 0x881B;
pub const MAX_DRAW_BUFFERS = 0x8824;
pub const DRAW_BUFFER0 = 0x8825;
pub const DRAW_BUFFER1 = 0x8826;
pub const DRAW_BUFFER2 = 0x8827;
pub const DRAW_BUFFER3 = 0x8828;
pub const DRAW_BUFFER4 = 0x8829;
pub const DRAW_BUFFER5 = 0x882A;
pub const DRAW_BUFFER6 = 0x882B;
pub const DRAW_BUFFER7 = 0x882C;
pub const DRAW_BUFFER8 = 0x882D;
pub const DRAW_BUFFER9 = 0x882E;
pub const DRAW_BUFFER10 = 0x882F;
pub const DRAW_BUFFER11 = 0x8830;
pub const DRAW_BUFFER12 = 0x8831;
pub const DRAW_BUFFER13 = 0x8832;
pub const DRAW_BUFFER14 = 0x8833;
pub const DRAW_BUFFER15 = 0x8834;
pub const BLEND_EQUATION_ALPHA = 0x883D;
pub const TEXTURE_DEPTH_SIZE = 0x884A;
pub const TEXTURE_COMPARE_MODE = 0x884C;
pub const TEXTURE_COMPARE_FUNC = 0x884D;
pub const COMPARE_REF_TO_TEXTURE = 0x884E;
pub const TEXTURE_CUBE_MAP_SEAMLESS = 0x884F;
pub const QUERY_COUNTER_BITS = 0x8864;
pub const CURRENT_QUERY = 0x8865;
pub const QUERY_RESULT = 0x8866;
pub const QUERY_RESULT_AVAILABLE = 0x8867;
pub const MAX_VERTEX_ATTRIBS = 0x8869;
pub const VERTEX_ATTRIB_ARRAY_NORMALIZED = 0x886A;
pub const MAX_TESS_CONTROL_INPUT_COMPONENTS = 0x886C;
pub const MAX_TESS_EVALUATION_INPUT_COMPONENTS = 0x886D;
pub const MAX_TEXTURE_IMAGE_UNITS = 0x8872;
pub const GEOMETRY_SHADER_INVOCATIONS = 0x887F;
pub const ARRAY_BUFFER = 0x8892;
pub const ELEMENT_ARRAY_BUFFER = 0x8893;
pub const ARRAY_BUFFER_BINDING = 0x8894;
pub const ELEMENT_ARRAY_BUFFER_BINDING = 0x8895;
pub const VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 0x889F;
pub const READ_ONLY = 0x88B8;
pub const WRITE_ONLY = 0x88B9;
pub const READ_WRITE = 0x88BA;
pub const BUFFER_ACCESS = 0x88BB;
pub const BUFFER_MAPPED = 0x88BC;
pub const BUFFER_MAP_POINTER = 0x88BD;
pub const TIME_ELAPSED = 0x88BF;
pub const STREAM_DRAW = 0x88E0;
pub const STREAM_READ = 0x88E1;
pub const STREAM_COPY = 0x88E2;
pub const STATIC_DRAW = 0x88E4;
pub const STATIC_READ = 0x88E5;
pub const STATIC_COPY = 0x88E6;
pub const DYNAMIC_DRAW = 0x88E8;
pub const DYNAMIC_READ = 0x88E9;
pub const DYNAMIC_COPY = 0x88EA;
pub const PIXEL_PACK_BUFFER = 0x88EB;
pub const PIXEL_UNPACK_BUFFER = 0x88EC;
pub const PIXEL_PACK_BUFFER_BINDING = 0x88ED;
pub const PIXEL_UNPACK_BUFFER_BINDING = 0x88EF;
pub const DEPTH24_STENCIL8 = 0x88F0;
pub const TEXTURE_STENCIL_SIZE = 0x88F1;
pub const SRC1_COLOR = 0x88F9;
pub const ONE_MINUS_SRC1_COLOR = 0x88FA;
pub const ONE_MINUS_SRC1_ALPHA = 0x88FB;
pub const MAX_DUAL_SOURCE_DRAW_BUFFERS = 0x88FC;
pub const VERTEX_ATTRIB_ARRAY_INTEGER = 0x88FD;
pub const VERTEX_ATTRIB_ARRAY_DIVISOR = 0x88FE;
pub const MAX_ARRAY_TEXTURE_LAYERS = 0x88FF;
pub const MIN_PROGRAM_TEXEL_OFFSET = 0x8904;
pub const MAX_PROGRAM_TEXEL_OFFSET = 0x8905;
pub const SAMPLES_PASSED = 0x8914;
pub const GEOMETRY_VERTICES_OUT = 0x8916;
pub const GEOMETRY_INPUT_TYPE = 0x8917;
pub const GEOMETRY_OUTPUT_TYPE = 0x8918;
pub const SAMPLER_BINDING = 0x8919;
pub const CLAMP_READ_COLOR = 0x891C;
pub const FIXED_ONLY = 0x891D;
pub const UNIFORM_BUFFER = 0x8A11;
pub const UNIFORM_BUFFER_BINDING = 0x8A28;
pub const UNIFORM_BUFFER_START = 0x8A29;
pub const UNIFORM_BUFFER_SIZE = 0x8A2A;
pub const MAX_VERTEX_UNIFORM_BLOCKS = 0x8A2B;
pub const MAX_GEOMETRY_UNIFORM_BLOCKS = 0x8A2C;
pub const MAX_FRAGMENT_UNIFORM_BLOCKS = 0x8A2D;
pub const MAX_COMBINED_UNIFORM_BLOCKS = 0x8A2E;
pub const MAX_UNIFORM_BUFFER_BINDINGS = 0x8A2F;
pub const MAX_UNIFORM_BLOCK_SIZE = 0x8A30;
pub const MAX_COMBINED_VERTEX_UNIFORM_COMPONENTS = 0x8A31;
pub const MAX_COMBINED_GEOMETRY_UNIFORM_COMPONENTS = 0x8A32;
pub const MAX_COMBINED_FRAGMENT_UNIFORM_COMPONENTS = 0x8A33;
pub const UNIFORM_BUFFER_OFFSET_ALIGNMENT = 0x8A34;
pub const ACTIVE_UNIFORM_BLOCK_MAX_NAME_LENGTH = 0x8A35;
pub const ACTIVE_UNIFORM_BLOCKS = 0x8A36;
pub const UNIFORM_TYPE = 0x8A37;
pub const UNIFORM_SIZE = 0x8A38;
pub const UNIFORM_NAME_LENGTH = 0x8A39;
pub const UNIFORM_BLOCK_INDEX = 0x8A3A;
pub const UNIFORM_OFFSET = 0x8A3B;
pub const UNIFORM_ARRAY_STRIDE = 0x8A3C;
pub const UNIFORM_MATRIX_STRIDE = 0x8A3D;
pub const UNIFORM_IS_ROW_MAJOR = 0x8A3E;
pub const UNIFORM_BLOCK_BINDING = 0x8A3F;
pub const UNIFORM_BLOCK_DATA_SIZE = 0x8A40;
pub const UNIFORM_BLOCK_NAME_LENGTH = 0x8A41;
pub const UNIFORM_BLOCK_ACTIVE_UNIFORMS = 0x8A42;
pub const UNIFORM_BLOCK_ACTIVE_UNIFORM_INDICES = 0x8A43;
pub const UNIFORM_BLOCK_REFERENCED_BY_VERTEX_SHADER = 0x8A44;
pub const UNIFORM_BLOCK_REFERENCED_BY_GEOMETRY_SHADER = 0x8A45;
pub const UNIFORM_BLOCK_REFERENCED_BY_FRAGMENT_SHADER = 0x8A46;
pub const FRAGMENT_SHADER = 0x8B30;
pub const VERTEX_SHADER = 0x8B31;
pub const MAX_FRAGMENT_UNIFORM_COMPONENTS = 0x8B49;
pub const MAX_VERTEX_UNIFORM_COMPONENTS = 0x8B4A;
pub const MAX_VARYING_COMPONENTS = 0x8B4B;
pub const MAX_VARYING_FLOATS = 0x8B4B;
pub const MAX_VERTEX_TEXTURE_IMAGE_UNITS = 0x8B4C;
pub const MAX_COMBINED_TEXTURE_IMAGE_UNITS = 0x8B4D;
pub const SHADER_TYPE = 0x8B4F;
pub const FLOAT_VEC2 = 0x8B50;
pub const FLOAT_VEC3 = 0x8B51;
pub const FLOAT_VEC4 = 0x8B52;
pub const INT_VEC2 = 0x8B53;
pub const INT_VEC3 = 0x8B54;
pub const INT_VEC4 = 0x8B55;
pub const BOOL = 0x8B56;
pub const BOOL_VEC2 = 0x8B57;
pub const BOOL_VEC3 = 0x8B58;
pub const BOOL_VEC4 = 0x8B59;
pub const FLOAT_MAT2 = 0x8B5A;
pub const FLOAT_MAT3 = 0x8B5B;
pub const FLOAT_MAT4 = 0x8B5C;
pub const SAMPLER_1D = 0x8B5D;
pub const SAMPLER_2D = 0x8B5E;
pub const SAMPLER_3D = 0x8B5F;
pub const SAMPLER_CUBE = 0x8B60;
pub const SAMPLER_1D_SHADOW = 0x8B61;
pub const SAMPLER_2D_SHADOW = 0x8B62;
pub const SAMPLER_2D_RECT = 0x8B63;
pub const SAMPLER_2D_RECT_SHADOW = 0x8B64;
pub const FLOAT_MAT2x3 = 0x8B65;
pub const FLOAT_MAT2x4 = 0x8B66;
pub const FLOAT_MAT3x2 = 0x8B67;
pub const FLOAT_MAT3x4 = 0x8B68;
pub const FLOAT_MAT4x2 = 0x8B69;
pub const FLOAT_MAT4x3 = 0x8B6A;
pub const DELETE_STATUS = 0x8B80;
pub const COMPILE_STATUS = 0x8B81;
pub const LINK_STATUS = 0x8B82;
pub const VALIDATE_STATUS = 0x8B83;
pub const INFO_LOG_LENGTH = 0x8B84;
pub const ATTACHED_SHADERS = 0x8B85;
pub const ACTIVE_UNIFORMS = 0x8B86;
pub const ACTIVE_UNIFORM_MAX_LENGTH = 0x8B87;
pub const SHADER_SOURCE_LENGTH = 0x8B88;
pub const ACTIVE_ATTRIBUTES = 0x8B89;
pub const ACTIVE_ATTRIBUTE_MAX_LENGTH = 0x8B8A;
pub const FRAGMENT_SHADER_DERIVATIVE_HINT = 0x8B8B;
pub const SHADING_LANGUAGE_VERSION = 0x8B8C;
pub const CURRENT_PROGRAM = 0x8B8D;
pub const IMPLEMENTATION_COLOR_READ_TYPE = 0x8B9A;
pub const IMPLEMENTATION_COLOR_READ_FORMAT = 0x8B9B;
pub const TEXTURE_RED_TYPE = 0x8C10;
pub const TEXTURE_GREEN_TYPE = 0x8C11;
pub const TEXTURE_BLUE_TYPE = 0x8C12;
pub const TEXTURE_ALPHA_TYPE = 0x8C13;
pub const TEXTURE_DEPTH_TYPE = 0x8C16;
pub const UNSIGNED_NORMALIZED = 0x8C17;
pub const TEXTURE_1D_ARRAY = 0x8C18;
pub const PROXY_TEXTURE_1D_ARRAY = 0x8C19;
pub const TEXTURE_2D_ARRAY = 0x8C1A;
pub const PROXY_TEXTURE_2D_ARRAY = 0x8C1B;
pub const TEXTURE_BINDING_1D_ARRAY = 0x8C1C;
pub const TEXTURE_BINDING_2D_ARRAY = 0x8C1D;
pub const MAX_GEOMETRY_TEXTURE_IMAGE_UNITS = 0x8C29;
pub const TEXTURE_BUFFER = 0x8C2A;
pub const MAX_TEXTURE_BUFFER_SIZE = 0x8C2B;
pub const TEXTURE_BINDING_BUFFER = 0x8C2C;
pub const TEXTURE_BUFFER_DATA_STORE_BINDING = 0x8C2D;
pub const ANY_SAMPLES_PASSED = 0x8C2F;
pub const SAMPLE_SHADING = 0x8C36;
pub const MIN_SAMPLE_SHADING_VALUE = 0x8C37;
pub const R11F_G11F_B10F = 0x8C3A;
pub const UNSIGNED_INT_10F_11F_11F_REV = 0x8C3B;
pub const RGB9_E5 = 0x8C3D;
pub const UNSIGNED_INT_5_9_9_9_REV = 0x8C3E;
pub const TEXTURE_SHARED_SIZE = 0x8C3F;
pub const SRGB = 0x8C40;
pub const SRGB8 = 0x8C41;
pub const SRGB_ALPHA = 0x8C42;
pub const SRGB8_ALPHA8 = 0x8C43;
pub const COMPRESSED_SRGB = 0x8C48;
pub const COMPRESSED_SRGB_ALPHA = 0x8C49;
pub const TRANSFORM_FEEDBACK_VARYING_MAX_LENGTH = 0x8C76;
pub const TRANSFORM_FEEDBACK_BUFFER_MODE = 0x8C7F;
pub const MAX_TRANSFORM_FEEDBACK_SEPARATE_COMPONENTS = 0x8C80;
pub const TRANSFORM_FEEDBACK_VARYINGS = 0x8C83;
pub const TRANSFORM_FEEDBACK_BUFFER_START = 0x8C84;
pub const TRANSFORM_FEEDBACK_BUFFER_SIZE = 0x8C85;
pub const PRIMITIVES_GENERATED = 0x8C87;
pub const TRANSFORM_FEEDBACK_PRIMITIVES_WRITTEN = 0x8C88;
pub const RASTERIZER_DISCARD = 0x8C89;
pub const MAX_TRANSFORM_FEEDBACK_INTERLEAVED_COMPONENTS = 0x8C8A;
pub const MAX_TRANSFORM_FEEDBACK_SEPARATE_ATTRIBS = 0x8C8B;
pub const INTERLEAVED_ATTRIBS = 0x8C8C;
pub const SEPARATE_ATTRIBS = 0x8C8D;
pub const TRANSFORM_FEEDBACK_BUFFER = 0x8C8E;
pub const TRANSFORM_FEEDBACK_BUFFER_BINDING = 0x8C8F;
pub const POINT_SPRITE_COORD_ORIGIN = 0x8CA0;
pub const LOWER_LEFT = 0x8CA1;
pub const UPPER_LEFT = 0x8CA2;
pub const STENCIL_BACK_REF = 0x8CA3;
pub const STENCIL_BACK_VALUE_MASK = 0x8CA4;
pub const STENCIL_BACK_WRITEMASK = 0x8CA5;
pub const DRAW_FRAMEBUFFER_BINDING = 0x8CA6;
pub const FRAMEBUFFER_BINDING = 0x8CA6;
pub const RENDERBUFFER_BINDING = 0x8CA7;
pub const READ_FRAMEBUFFER = 0x8CA8;
pub const DRAW_FRAMEBUFFER = 0x8CA9;
pub const READ_FRAMEBUFFER_BINDING = 0x8CAA;
pub const RENDERBUFFER_SAMPLES = 0x8CAB;
pub const DEPTH_COMPONENT32F = 0x8CAC;
pub const DEPTH32F_STENCIL8 = 0x8CAD;
pub const FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE = 0x8CD0;
pub const FRAMEBUFFER_ATTACHMENT_OBJECT_NAME = 0x8CD1;
pub const FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL = 0x8CD2;
pub const FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE = 0x8CD3;
pub const FRAMEBUFFER_ATTACHMENT_TEXTURE_LAYER = 0x8CD4;
pub const FRAMEBUFFER_COMPLETE = 0x8CD5;
pub const FRAMEBUFFER_INCOMPLETE_ATTACHMENT = 0x8CD6;
pub const FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT = 0x8CD7;
pub const FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER = 0x8CDB;
pub const FRAMEBUFFER_INCOMPLETE_READ_BUFFER = 0x8CDC;
pub const FRAMEBUFFER_UNSUPPORTED = 0x8CDD;
pub const MAX_COLOR_ATTACHMENTS = 0x8CDF;
pub const COLOR_ATTACHMENT0 = 0x8CE0;
pub const COLOR_ATTACHMENT1 = 0x8CE1;
pub const COLOR_ATTACHMENT2 = 0x8CE2;
pub const COLOR_ATTACHMENT3 = 0x8CE3;
pub const COLOR_ATTACHMENT4 = 0x8CE4;
pub const COLOR_ATTACHMENT5 = 0x8CE5;
pub const COLOR_ATTACHMENT6 = 0x8CE6;
pub const COLOR_ATTACHMENT7 = 0x8CE7;
pub const COLOR_ATTACHMENT8 = 0x8CE8;
pub const COLOR_ATTACHMENT9 = 0x8CE9;
pub const COLOR_ATTACHMENT10 = 0x8CEA;
pub const COLOR_ATTACHMENT11 = 0x8CEB;
pub const COLOR_ATTACHMENT12 = 0x8CEC;
pub const COLOR_ATTACHMENT13 = 0x8CED;
pub const COLOR_ATTACHMENT14 = 0x8CEE;
pub const COLOR_ATTACHMENT15 = 0x8CEF;
pub const COLOR_ATTACHMENT16 = 0x8CF0;
pub const COLOR_ATTACHMENT17 = 0x8CF1;
pub const COLOR_ATTACHMENT18 = 0x8CF2;
pub const COLOR_ATTACHMENT19 = 0x8CF3;
pub const COLOR_ATTACHMENT20 = 0x8CF4;
pub const COLOR_ATTACHMENT21 = 0x8CF5;
pub const COLOR_ATTACHMENT22 = 0x8CF6;
pub const COLOR_ATTACHMENT23 = 0x8CF7;
pub const COLOR_ATTACHMENT24 = 0x8CF8;
pub const COLOR_ATTACHMENT25 = 0x8CF9;
pub const COLOR_ATTACHMENT26 = 0x8CFA;
pub const COLOR_ATTACHMENT27 = 0x8CFB;
pub const COLOR_ATTACHMENT28 = 0x8CFC;
pub const COLOR_ATTACHMENT29 = 0x8CFD;
pub const COLOR_ATTACHMENT30 = 0x8CFE;
pub const COLOR_ATTACHMENT31 = 0x8CFF;
pub const DEPTH_ATTACHMENT = 0x8D00;
pub const STENCIL_ATTACHMENT = 0x8D20;
pub const FRAMEBUFFER = 0x8D40;
pub const RENDERBUFFER = 0x8D41;
pub const RENDERBUFFER_WIDTH = 0x8D42;
pub const RENDERBUFFER_HEIGHT = 0x8D43;
pub const RENDERBUFFER_INTERNAL_FORMAT = 0x8D44;
pub const STENCIL_INDEX1 = 0x8D46;
pub const STENCIL_INDEX4 = 0x8D47;
pub const STENCIL_INDEX8 = 0x8D48;
pub const STENCIL_INDEX16 = 0x8D49;
pub const RENDERBUFFER_RED_SIZE = 0x8D50;
pub const RENDERBUFFER_GREEN_SIZE = 0x8D51;
pub const RENDERBUFFER_BLUE_SIZE = 0x8D52;
pub const RENDERBUFFER_ALPHA_SIZE = 0x8D53;
pub const RENDERBUFFER_DEPTH_SIZE = 0x8D54;
pub const RENDERBUFFER_STENCIL_SIZE = 0x8D55;
pub const FRAMEBUFFER_INCOMPLETE_MULTISAMPLE = 0x8D56;
pub const MAX_SAMPLES = 0x8D57;
pub const RGB565 = 0x8D62;
pub const RGBA32UI = 0x8D70;
pub const RGB32UI = 0x8D71;
pub const RGBA16UI = 0x8D76;
pub const RGB16UI = 0x8D77;
pub const RGBA8UI = 0x8D7C;
pub const RGB8UI = 0x8D7D;
pub const RGBA32I = 0x8D82;
pub const RGB32I = 0x8D83;
pub const RGBA16I = 0x8D88;
pub const RGB16I = 0x8D89;
pub const RGBA8I = 0x8D8E;
pub const RGB8I = 0x8D8F;
pub const RED_INTEGER = 0x8D94;
pub const GREEN_INTEGER = 0x8D95;
pub const BLUE_INTEGER = 0x8D96;
pub const RGB_INTEGER = 0x8D98;
pub const RGBA_INTEGER = 0x8D99;
pub const BGR_INTEGER = 0x8D9A;
pub const BGRA_INTEGER = 0x8D9B;
pub const INT_2_10_10_10_REV = 0x8D9F;
pub const FRAMEBUFFER_ATTACHMENT_LAYERED = 0x8DA7;
pub const FRAMEBUFFER_INCOMPLETE_LAYER_TARGETS = 0x8DA8;
pub const FLOAT_32_UNSIGNED_INT_24_8_REV = 0x8DAD;
pub const FRAMEBUFFER_SRGB = 0x8DB9;
pub const COMPRESSED_RED_RGTC1 = 0x8DBB;
pub const COMPRESSED_SIGNED_RED_RGTC1 = 0x8DBC;
pub const COMPRESSED_RG_RGTC2 = 0x8DBD;
pub const COMPRESSED_SIGNED_RG_RGTC2 = 0x8DBE;
pub const SAMPLER_1D_ARRAY = 0x8DC0;
pub const SAMPLER_2D_ARRAY = 0x8DC1;
pub const SAMPLER_BUFFER = 0x8DC2;
pub const SAMPLER_1D_ARRAY_SHADOW = 0x8DC3;
pub const SAMPLER_2D_ARRAY_SHADOW = 0x8DC4;
pub const SAMPLER_CUBE_SHADOW = 0x8DC5;
pub const UNSIGNED_INT_VEC2 = 0x8DC6;
pub const UNSIGNED_INT_VEC3 = 0x8DC7;
pub const UNSIGNED_INT_VEC4 = 0x8DC8;
pub const INT_SAMPLER_1D = 0x8DC9;
pub const INT_SAMPLER_2D = 0x8DCA;
pub const INT_SAMPLER_3D = 0x8DCB;
pub const INT_SAMPLER_CUBE = 0x8DCC;
pub const INT_SAMPLER_2D_RECT = 0x8DCD;
pub const INT_SAMPLER_1D_ARRAY = 0x8DCE;
pub const INT_SAMPLER_2D_ARRAY = 0x8DCF;
pub const INT_SAMPLER_BUFFER = 0x8DD0;
pub const UNSIGNED_INT_SAMPLER_1D = 0x8DD1;
pub const UNSIGNED_INT_SAMPLER_2D = 0x8DD2;
pub const UNSIGNED_INT_SAMPLER_3D = 0x8DD3;
pub const UNSIGNED_INT_SAMPLER_CUBE = 0x8DD4;
pub const UNSIGNED_INT_SAMPLER_2D_RECT = 0x8DD5;
pub const UNSIGNED_INT_SAMPLER_1D_ARRAY = 0x8DD6;
pub const UNSIGNED_INT_SAMPLER_2D_ARRAY = 0x8DD7;
pub const UNSIGNED_INT_SAMPLER_BUFFER = 0x8DD8;
pub const GEOMETRY_SHADER = 0x8DD9;
pub const MAX_GEOMETRY_UNIFORM_COMPONENTS = 0x8DDF;
pub const MAX_GEOMETRY_OUTPUT_VERTICES = 0x8DE0;
pub const MAX_GEOMETRY_TOTAL_OUTPUT_COMPONENTS = 0x8DE1;
pub const ACTIVE_SUBROUTINES = 0x8DE5;
pub const ACTIVE_SUBROUTINE_UNIFORMS = 0x8DE6;
pub const MAX_SUBROUTINES = 0x8DE7;
pub const MAX_SUBROUTINE_UNIFORM_LOCATIONS = 0x8DE8;
pub const LOW_FLOAT = 0x8DF0;
pub const MEDIUM_FLOAT = 0x8DF1;
pub const HIGH_FLOAT = 0x8DF2;
pub const LOW_INT = 0x8DF3;
pub const MEDIUM_INT = 0x8DF4;
pub const HIGH_INT = 0x8DF5;
pub const SHADER_BINARY_FORMATS = 0x8DF8;
pub const NUM_SHADER_BINARY_FORMATS = 0x8DF9;
pub const SHADER_COMPILER = 0x8DFA;
pub const MAX_VERTEX_UNIFORM_VECTORS = 0x8DFB;
pub const MAX_VARYING_VECTORS = 0x8DFC;
pub const MAX_FRAGMENT_UNIFORM_VECTORS = 0x8DFD;
pub const QUERY_WAIT = 0x8E13;
pub const QUERY_NO_WAIT = 0x8E14;
pub const QUERY_BY_REGION_WAIT = 0x8E15;
pub const QUERY_BY_REGION_NO_WAIT = 0x8E16;
pub const MAX_COMBINED_TESS_CONTROL_UNIFORM_COMPONENTS = 0x8E1E;
pub const MAX_COMBINED_TESS_EVALUATION_UNIFORM_COMPONENTS = 0x8E1F;
pub const TRANSFORM_FEEDBACK = 0x8E22;
pub const TRANSFORM_FEEDBACK_BUFFER_PAUSED = 0x8E23;
pub const TRANSFORM_FEEDBACK_BUFFER_ACTIVE = 0x8E24;
pub const TRANSFORM_FEEDBACK_BINDING = 0x8E25;
pub const TIMESTAMP = 0x8E28;
pub const TEXTURE_SWIZZLE_R = 0x8E42;
pub const TEXTURE_SWIZZLE_G = 0x8E43;
pub const TEXTURE_SWIZZLE_B = 0x8E44;
pub const TEXTURE_SWIZZLE_A = 0x8E45;
pub const TEXTURE_SWIZZLE_RGBA = 0x8E46;
pub const ACTIVE_SUBROUTINE_UNIFORM_LOCATIONS = 0x8E47;
pub const ACTIVE_SUBROUTINE_MAX_LENGTH = 0x8E48;
pub const ACTIVE_SUBROUTINE_UNIFORM_MAX_LENGTH = 0x8E49;
pub const NUM_COMPATIBLE_SUBROUTINES = 0x8E4A;
pub const COMPATIBLE_SUBROUTINES = 0x8E4B;
pub const QUADS_FOLLOW_PROVOKING_VERTEX_CONVENTION = 0x8E4C;
pub const FIRST_VERTEX_CONVENTION = 0x8E4D;
pub const LAST_VERTEX_CONVENTION = 0x8E4E;
pub const PROVOKING_VERTEX = 0x8E4F;
pub const SAMPLE_POSITION = 0x8E50;
pub const SAMPLE_MASK = 0x8E51;
pub const SAMPLE_MASK_VALUE = 0x8E52;
pub const MAX_SAMPLE_MASK_WORDS = 0x8E59;
pub const MAX_GEOMETRY_SHADER_INVOCATIONS = 0x8E5A;
pub const MIN_FRAGMENT_INTERPOLATION_OFFSET = 0x8E5B;
pub const MAX_FRAGMENT_INTERPOLATION_OFFSET = 0x8E5C;
pub const FRAGMENT_INTERPOLATION_OFFSET_BITS = 0x8E5D;
pub const MIN_PROGRAM_TEXTURE_GATHER_OFFSET = 0x8E5E;
pub const MAX_PROGRAM_TEXTURE_GATHER_OFFSET = 0x8E5F;
pub const MAX_TRANSFORM_FEEDBACK_BUFFERS = 0x8E70;
pub const MAX_VERTEX_STREAMS = 0x8E71;
pub const PATCH_VERTICES = 0x8E72;
pub const PATCH_DEFAULT_INNER_LEVEL = 0x8E73;
pub const PATCH_DEFAULT_OUTER_LEVEL = 0x8E74;
pub const TESS_CONTROL_OUTPUT_VERTICES = 0x8E75;
pub const TESS_GEN_MODE = 0x8E76;
pub const TESS_GEN_SPACING = 0x8E77;
pub const TESS_GEN_VERTEX_ORDER = 0x8E78;
pub const TESS_GEN_POINT_MODE = 0x8E79;
pub const ISOLINES = 0x8E7A;
pub const FRACTIONAL_ODD = 0x8E7B;
pub const FRACTIONAL_EVEN = 0x8E7C;
pub const MAX_PATCH_VERTICES = 0x8E7D;
pub const MAX_TESS_GEN_LEVEL = 0x8E7E;
pub const MAX_TESS_CONTROL_UNIFORM_COMPONENTS = 0x8E7F;
pub const MAX_TESS_EVALUATION_UNIFORM_COMPONENTS = 0x8E80;
pub const MAX_TESS_CONTROL_TEXTURE_IMAGE_UNITS = 0x8E81;
pub const MAX_TESS_EVALUATION_TEXTURE_IMAGE_UNITS = 0x8E82;
pub const MAX_TESS_CONTROL_OUTPUT_COMPONENTS = 0x8E83;
pub const MAX_TESS_PATCH_COMPONENTS = 0x8E84;
pub const MAX_TESS_CONTROL_TOTAL_OUTPUT_COMPONENTS = 0x8E85;
pub const MAX_TESS_EVALUATION_OUTPUT_COMPONENTS = 0x8E86;
pub const TESS_EVALUATION_SHADER = 0x8E87;
pub const TESS_CONTROL_SHADER = 0x8E88;
pub const MAX_TESS_CONTROL_UNIFORM_BLOCKS = 0x8E89;
pub const MAX_TESS_EVALUATION_UNIFORM_BLOCKS = 0x8E8A;
pub const COPY_READ_BUFFER = 0x8F36;
pub const COPY_WRITE_BUFFER = 0x8F37;
pub const DRAW_INDIRECT_BUFFER = 0x8F3F;
pub const DRAW_INDIRECT_BUFFER_BINDING = 0x8F43;
pub const DOUBLE_MAT2 = 0x8F46;
pub const DOUBLE_MAT3 = 0x8F47;
pub const DOUBLE_MAT4 = 0x8F48;
pub const DOUBLE_MAT2x3 = 0x8F49;
pub const DOUBLE_MAT2x4 = 0x8F4A;
pub const DOUBLE_MAT3x2 = 0x8F4B;
pub const DOUBLE_MAT3x4 = 0x8F4C;
pub const DOUBLE_MAT4x2 = 0x8F4D;
pub const DOUBLE_MAT4x3 = 0x8F4E;
pub const R8_SNORM = 0x8F94;
pub const RG8_SNORM = 0x8F95;
pub const RGB8_SNORM = 0x8F96;
pub const RGBA8_SNORM = 0x8F97;
pub const R16_SNORM = 0x8F98;
pub const RG16_SNORM = 0x8F99;
pub const RGB16_SNORM = 0x8F9A;
pub const RGBA16_SNORM = 0x8F9B;
pub const SIGNED_NORMALIZED = 0x8F9C;
pub const PRIMITIVE_RESTART = 0x8F9D;
pub const PRIMITIVE_RESTART_INDEX = 0x8F9E;
pub const DOUBLE_VEC2 = 0x8FFC;
pub const DOUBLE_VEC3 = 0x8FFD;
pub const DOUBLE_VEC4 = 0x8FFE;
pub const TEXTURE_CUBE_MAP_ARRAY = 0x9009;
pub const TEXTURE_BINDING_CUBE_MAP_ARRAY = 0x900A;
pub const PROXY_TEXTURE_CUBE_MAP_ARRAY = 0x900B;
pub const SAMPLER_CUBE_MAP_ARRAY = 0x900C;
pub const SAMPLER_CUBE_MAP_ARRAY_SHADOW = 0x900D;
pub const INT_SAMPLER_CUBE_MAP_ARRAY = 0x900E;
pub const UNSIGNED_INT_SAMPLER_CUBE_MAP_ARRAY = 0x900F;
pub const RGB10_A2UI = 0x906F;
pub const TEXTURE_2D_MULTISAMPLE = 0x9100;
pub const PROXY_TEXTURE_2D_MULTISAMPLE = 0x9101;
pub const TEXTURE_2D_MULTISAMPLE_ARRAY = 0x9102;
pub const PROXY_TEXTURE_2D_MULTISAMPLE_ARRAY = 0x9103;
pub const TEXTURE_BINDING_2D_MULTISAMPLE = 0x9104;
pub const TEXTURE_BINDING_2D_MULTISAMPLE_ARRAY = 0x9105;
pub const TEXTURE_SAMPLES = 0x9106;
pub const TEXTURE_FIXED_SAMPLE_LOCATIONS = 0x9107;
pub const SAMPLER_2D_MULTISAMPLE = 0x9108;
pub const INT_SAMPLER_2D_MULTISAMPLE = 0x9109;
pub const UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE = 0x910A;
pub const SAMPLER_2D_MULTISAMPLE_ARRAY = 0x910B;
pub const INT_SAMPLER_2D_MULTISAMPLE_ARRAY = 0x910C;
pub const UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY = 0x910D;
pub const MAX_COLOR_TEXTURE_SAMPLES = 0x910E;
pub const MAX_DEPTH_TEXTURE_SAMPLES = 0x910F;
pub const MAX_INTEGER_SAMPLES = 0x9110;
pub const MAX_SERVER_WAIT_TIMEOUT = 0x9111;
pub const OBJECT_TYPE = 0x9112;
pub const SYNC_CONDITION = 0x9113;
pub const SYNC_STATUS = 0x9114;
pub const SYNC_FLAGS = 0x9115;
pub const SYNC_FENCE = 0x9116;
pub const SYNC_GPU_COMMANDS_COMPLETE = 0x9117;
pub const UNSIGNALED = 0x9118;
pub const SIGNALED = 0x9119;
pub const ALREADY_SIGNALED = 0x911A;
pub const TIMEOUT_EXPIRED = 0x911B;
pub const CONDITION_SATISFIED = 0x911C;
pub const WAIT_FAILED = 0x911D;
pub const BUFFER_ACCESS_FLAGS = 0x911F;
pub const BUFFER_MAP_LENGTH = 0x9120;
pub const BUFFER_MAP_OFFSET = 0x9121;
pub const MAX_VERTEX_OUTPUT_COMPONENTS = 0x9122;
pub const MAX_GEOMETRY_INPUT_COMPONENTS = 0x9123;
pub const MAX_GEOMETRY_OUTPUT_COMPONENTS = 0x9124;
pub const MAX_FRAGMENT_INPUT_COMPONENTS = 0x9125;
pub const CONTEXT_PROFILE_MASK = 0x9126;
//#endregion Constants

//#region Commands
pub fn activeShaderProgram(pipeline: Uint, program: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glActiveShaderProgram", .{ pipeline, program });
}
pub fn activeTexture(texture: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glActiveTexture", .{texture});
}
pub fn attachShader(program: Uint, shader: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glAttachShader", .{ program, shader });
}
pub fn beginConditionalRender(id: Uint, mode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBeginConditionalRender", .{ id, mode });
}
pub fn beginQuery(target: Enum, id: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBeginQuery", .{ target, id });
}
pub fn beginQueryIndexed(target: Enum, index: Uint, id: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBeginQueryIndexed", .{ target, index, id });
}
pub fn beginTransformFeedback(primitiveMode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBeginTransformFeedback", .{primitiveMode});
}
pub fn bindAttribLocation(program: Uint, index: Uint, name: [*c]const Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindAttribLocation", .{ program, index, name });
}
pub fn bindBuffer(target: Enum, buffer: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindBuffer", .{ target, buffer });
}
pub fn bindBufferBase(target: Enum, index: Uint, buffer: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindBufferBase", .{ target, index, buffer });
}
pub fn bindBufferRange(target: Enum, index: Uint, buffer: Uint, offset: Intptr, size: Sizeiptr) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindBufferRange", .{ target, index, buffer, offset, size });
}
pub fn bindFragDataLocation(program: Uint, color: Uint, name: [*c]const Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindFragDataLocation", .{ program, color, name });
}
pub fn bindFragDataLocationIndexed(program: Uint, colorNumber: Uint, index: Uint, name: [*c]const Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindFragDataLocationIndexed", .{ program, colorNumber, index, name });
}
pub fn bindFramebuffer(target: Enum, framebuffer: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindFramebuffer", .{ target, framebuffer });
}
pub fn bindProgramPipeline(pipeline: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindProgramPipeline", .{pipeline});
}
pub fn bindRenderbuffer(target: Enum, renderbuffer: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindRenderbuffer", .{ target, renderbuffer });
}
pub fn bindSampler(unit: Uint, sampler: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindSampler", .{ unit, sampler });
}
pub fn bindTexture(target: Enum, texture: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindTexture", .{ target, texture });
}
pub fn bindTransformFeedback(target: Enum, id: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindTransformFeedback", .{ target, id });
}
pub fn bindVertexArray(array: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBindVertexArray", .{array});
}
pub fn blendColor(red: Float, green: Float, blue: Float, alpha: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlendColor", .{ red, green, blue, alpha });
}
pub fn blendEquation(mode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlendEquation", .{mode});
}
pub fn blendEquationSeparate(modeRGB: Enum, modeAlpha: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlendEquationSeparate", .{ modeRGB, modeAlpha });
}
pub fn blendEquationSeparatei(buf: Uint, modeRGB: Enum, modeAlpha: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlendEquationSeparatei", .{ buf, modeRGB, modeAlpha });
}
pub fn blendEquationi(buf: Uint, mode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlendEquationi", .{ buf, mode });
}
pub fn blendFunc(sfactor: Enum, dfactor: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlendFunc", .{ sfactor, dfactor });
}
pub fn blendFuncSeparate(sfactorRGB: Enum, dfactorRGB: Enum, sfactorAlpha: Enum, dfactorAlpha: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlendFuncSeparate", .{ sfactorRGB, dfactorRGB, sfactorAlpha, dfactorAlpha });
}
pub fn blendFuncSeparatei(buf: Uint, srcRGB: Enum, dstRGB: Enum, srcAlpha: Enum, dstAlpha: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlendFuncSeparatei", .{ buf, srcRGB, dstRGB, srcAlpha, dstAlpha });
}
pub fn blendFunci(buf: Uint, src: Enum, dst: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlendFunci", .{ buf, src, dst });
}
pub fn blitFramebuffer(srcX0: Int, srcY0: Int, srcX1: Int, srcY1: Int, dstX0: Int, dstY0: Int, dstX1: Int, dstY1: Int, mask: Bitfield, filter: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBlitFramebuffer", .{ srcX0, srcY0, srcX1, srcY1, dstX0, dstY0, dstX1, dstY1, mask, filter });
}
pub fn bufferData(target: Enum, size: Sizeiptr, data: ?*const anyopaque, usage: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBufferData", .{ target, size, data, usage });
}
pub fn bufferSubData(target: Enum, offset: Intptr, size: Sizeiptr, data: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glBufferSubData", .{ target, offset, size, data });
}
pub fn checkFramebufferStatus(target: Enum) callconv(.C) Enum {
    return DispatchTable.current.?.invokeIntercepted("glCheckFramebufferStatus", .{target});
}
pub fn clampColor(target: Enum, clamp: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClampColor", .{ target, clamp });
}
pub fn clear(mask: Bitfield) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClear", .{mask});
}
pub fn clearBufferfi(buffer: Enum, drawbuffer: Int, depth: Float, stencil: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClearBufferfi", .{ buffer, drawbuffer, depth, stencil });
}
pub fn clearBufferfv(buffer: Enum, drawbuffer: Int, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClearBufferfv", .{ buffer, drawbuffer, value });
}
pub fn clearBufferiv(buffer: Enum, drawbuffer: Int, value: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClearBufferiv", .{ buffer, drawbuffer, value });
}
pub fn clearBufferuiv(buffer: Enum, drawbuffer: Int, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClearBufferuiv", .{ buffer, drawbuffer, value });
}
pub fn clearColor(red: Float, green: Float, blue: Float, alpha: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClearColor", .{ red, green, blue, alpha });
}
pub fn clearDepth(depth: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClearDepth", .{depth});
}
pub fn clearDepthf(d: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClearDepthf", .{d});
}
pub fn clearStencil(s: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glClearStencil", .{s});
}
pub fn clientWaitSync(sync: Sync, flags: Bitfield, timeout: Uint64) callconv(.C) Enum {
    return DispatchTable.current.?.invokeIntercepted("glClientWaitSync", .{ sync, flags, timeout });
}
pub fn colorMask(red: Boolean, green: Boolean, blue: Boolean, alpha: Boolean) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glColorMask", .{ red, green, blue, alpha });
}
pub fn colorMaski(index: Uint, r: Boolean, g: Boolean, b: Boolean, a: Boolean) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glColorMaski", .{ index, r, g, b, a });
}
pub fn compileShader(shader: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCompileShader", .{shader});
}
pub fn compressedTexImage1D(target: Enum, level: Int, internalformat: Enum, width: Sizei, border: Int, imageSize: Sizei, data: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCompressedTexImage1D", .{ target, level, internalformat, width, border, imageSize, data });
}
pub fn compressedTexImage2D(target: Enum, level: Int, internalformat: Enum, width: Sizei, height: Sizei, border: Int, imageSize: Sizei, data: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCompressedTexImage2D", .{ target, level, internalformat, width, height, border, imageSize, data });
}
pub fn compressedTexImage3D(target: Enum, level: Int, internalformat: Enum, width: Sizei, height: Sizei, depth: Sizei, border: Int, imageSize: Sizei, data: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCompressedTexImage3D", .{ target, level, internalformat, width, height, depth, border, imageSize, data });
}
pub fn compressedTexSubImage1D(target: Enum, level: Int, xoffset: Int, width: Sizei, format: Enum, imageSize: Sizei, data: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCompressedTexSubImage1D", .{ target, level, xoffset, width, format, imageSize, data });
}
pub fn compressedTexSubImage2D(target: Enum, level: Int, xoffset: Int, yoffset: Int, width: Sizei, height: Sizei, format: Enum, imageSize: Sizei, data: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCompressedTexSubImage2D", .{ target, level, xoffset, yoffset, width, height, format, imageSize, data });
}
pub fn compressedTexSubImage3D(target: Enum, level: Int, xoffset: Int, yoffset: Int, zoffset: Int, width: Sizei, height: Sizei, depth: Sizei, format: Enum, imageSize: Sizei, data: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCompressedTexSubImage3D", .{ target, level, xoffset, yoffset, zoffset, width, height, depth, format, imageSize, data });
}
pub fn copyBufferSubData(readTarget: Enum, writeTarget: Enum, readOffset: Intptr, writeOffset: Intptr, size: Sizeiptr) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCopyBufferSubData", .{ readTarget, writeTarget, readOffset, writeOffset, size });
}
pub fn copyTexImage1D(target: Enum, level: Int, internalformat: Enum, x: Int, y: Int, width: Sizei, border: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCopyTexImage1D", .{ target, level, internalformat, x, y, width, border });
}
pub fn copyTexImage2D(target: Enum, level: Int, internalformat: Enum, x: Int, y: Int, width: Sizei, height: Sizei, border: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCopyTexImage2D", .{ target, level, internalformat, x, y, width, height, border });
}
pub fn copyTexSubImage1D(target: Enum, level: Int, xoffset: Int, x: Int, y: Int, width: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCopyTexSubImage1D", .{ target, level, xoffset, x, y, width });
}
pub fn copyTexSubImage2D(target: Enum, level: Int, xoffset: Int, yoffset: Int, x: Int, y: Int, width: Sizei, height: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCopyTexSubImage2D", .{ target, level, xoffset, yoffset, x, y, width, height });
}
pub fn copyTexSubImage3D(target: Enum, level: Int, xoffset: Int, yoffset: Int, zoffset: Int, x: Int, y: Int, width: Sizei, height: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCopyTexSubImage3D", .{ target, level, xoffset, yoffset, zoffset, x, y, width, height });
}
pub fn createProgram() callconv(.C) Uint {
    return DispatchTable.current.?.invokeIntercepted("glCreateProgram", .{});
}
pub fn createShader(@"type": Enum) callconv(.C) Uint {
    return DispatchTable.current.?.invokeIntercepted("glCreateShader", .{@"type"});
}
pub fn createShaderProgramv(@"type": Enum, count: Sizei, strings: [*c]const [*c]const Char) callconv(.C) Uint {
    return DispatchTable.current.?.invokeIntercepted("glCreateShaderProgramv", .{ @"type", count, strings });
}
pub fn cullFace(mode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glCullFace", .{mode});
}
pub fn deleteBuffers(n: Sizei, buffers: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteBuffers", .{ n, buffers });
}
pub fn deleteFramebuffers(n: Sizei, framebuffers: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteFramebuffers", .{ n, framebuffers });
}
pub fn deleteProgram(program: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteProgram", .{program});
}
pub fn deleteProgramPipelines(n: Sizei, pipelines: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteProgramPipelines", .{ n, pipelines });
}
pub fn deleteQueries(n: Sizei, ids: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteQueries", .{ n, ids });
}
pub fn deleteRenderbuffers(n: Sizei, renderbuffers: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteRenderbuffers", .{ n, renderbuffers });
}
pub fn deleteSamplers(count: Sizei, samplers: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteSamplers", .{ count, samplers });
}
pub fn deleteShader(shader: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteShader", .{shader});
}
pub fn deleteSync(sync: Sync) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteSync", .{sync});
}
pub fn deleteTextures(n: Sizei, textures: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteTextures", .{ n, textures });
}
pub fn deleteTransformFeedbacks(n: Sizei, ids: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteTransformFeedbacks", .{ n, ids });
}
pub fn deleteVertexArrays(n: Sizei, arrays: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDeleteVertexArrays", .{ n, arrays });
}
pub fn depthFunc(func: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDepthFunc", .{func});
}
pub fn depthMask(flag: Boolean) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDepthMask", .{flag});
}
pub fn depthRange(n: Double, f: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDepthRange", .{ n, f });
}
pub fn depthRangeArrayv(first: Uint, count: Sizei, v: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDepthRangeArrayv", .{ first, count, v });
}
pub fn depthRangeIndexed(index: Uint, n: Double, f: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDepthRangeIndexed", .{ index, n, f });
}
pub fn depthRangef(n: Float, f: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDepthRangef", .{ n, f });
}
pub fn detachShader(program: Uint, shader: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDetachShader", .{ program, shader });
}
pub fn disable(cap: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDisable", .{cap});
}
pub fn disableVertexAttribArray(index: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDisableVertexAttribArray", .{index});
}
pub fn disablei(target: Enum, index: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDisablei", .{ target, index });
}
pub fn drawArrays(mode: Enum, first: Int, count: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawArrays", .{ mode, first, count });
}
pub fn drawArraysIndirect(mode: Enum, indirect: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawArraysIndirect", .{ mode, indirect });
}
pub fn drawArraysInstanced(mode: Enum, first: Int, count: Sizei, instancecount: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawArraysInstanced", .{ mode, first, count, instancecount });
}
pub fn drawBuffer(buf: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawBuffer", .{buf});
}
pub fn drawBuffers(n: Sizei, bufs: [*c]const Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawBuffers", .{ n, bufs });
}
pub fn drawElements(mode: Enum, count: Sizei, @"type": Enum, indices: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawElements", .{ mode, count, @"type", indices });
}
pub fn drawElementsBaseVertex(mode: Enum, count: Sizei, @"type": Enum, indices: ?*const anyopaque, basevertex: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawElementsBaseVertex", .{ mode, count, @"type", indices, basevertex });
}
pub fn drawElementsIndirect(mode: Enum, @"type": Enum, indirect: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawElementsIndirect", .{ mode, @"type", indirect });
}
pub fn drawElementsInstanced(mode: Enum, count: Sizei, @"type": Enum, indices: ?*const anyopaque, instancecount: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawElementsInstanced", .{ mode, count, @"type", indices, instancecount });
}
pub fn drawElementsInstancedBaseVertex(mode: Enum, count: Sizei, @"type": Enum, indices: ?*const anyopaque, instancecount: Sizei, basevertex: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawElementsInstancedBaseVertex", .{ mode, count, @"type", indices, instancecount, basevertex });
}
pub fn drawRangeElements(mode: Enum, start: Uint, end: Uint, count: Sizei, @"type": Enum, indices: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawRangeElements", .{ mode, start, end, count, @"type", indices });
}
pub fn drawRangeElementsBaseVertex(mode: Enum, start: Uint, end: Uint, count: Sizei, @"type": Enum, indices: ?*const anyopaque, basevertex: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawRangeElementsBaseVertex", .{ mode, start, end, count, @"type", indices, basevertex });
}
pub fn drawTransformFeedback(mode: Enum, id: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawTransformFeedback", .{ mode, id });
}
pub fn drawTransformFeedbackStream(mode: Enum, id: Uint, stream: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glDrawTransformFeedbackStream", .{ mode, id, stream });
}
pub fn enable(cap: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glEnable", .{cap});
}
pub fn enableVertexAttribArray(index: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glEnableVertexAttribArray", .{index});
}
pub fn enablei(target: Enum, index: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glEnablei", .{ target, index });
}
pub fn endConditionalRender() callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glEndConditionalRender", .{});
}
pub fn endQuery(target: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glEndQuery", .{target});
}
pub fn endQueryIndexed(target: Enum, index: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glEndQueryIndexed", .{ target, index });
}
pub fn endTransformFeedback() callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glEndTransformFeedback", .{});
}
pub fn fenceSync(condition: Enum, flags: Bitfield) callconv(.C) Sync {
    return DispatchTable.current.?.invokeIntercepted("glFenceSync", .{ condition, flags });
}
pub fn finish() callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFinish", .{});
}
pub fn flush() callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFlush", .{});
}
pub fn flushMappedBufferRange(target: Enum, offset: Intptr, length: Sizeiptr) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFlushMappedBufferRange", .{ target, offset, length });
}
pub fn framebufferRenderbuffer(target: Enum, attachment: Enum, renderbuffertarget: Enum, renderbuffer: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFramebufferRenderbuffer", .{ target, attachment, renderbuffertarget, renderbuffer });
}
pub fn framebufferTexture(target: Enum, attachment: Enum, texture: Uint, level: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFramebufferTexture", .{ target, attachment, texture, level });
}
pub fn framebufferTexture1D(target: Enum, attachment: Enum, textarget: Enum, texture: Uint, level: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFramebufferTexture1D", .{ target, attachment, textarget, texture, level });
}
pub fn framebufferTexture2D(target: Enum, attachment: Enum, textarget: Enum, texture: Uint, level: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFramebufferTexture2D", .{ target, attachment, textarget, texture, level });
}
pub fn framebufferTexture3D(target: Enum, attachment: Enum, textarget: Enum, texture: Uint, level: Int, zoffset: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFramebufferTexture3D", .{ target, attachment, textarget, texture, level, zoffset });
}
pub fn framebufferTextureLayer(target: Enum, attachment: Enum, texture: Uint, level: Int, layer: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFramebufferTextureLayer", .{ target, attachment, texture, level, layer });
}
pub fn frontFace(mode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glFrontFace", .{mode});
}
pub fn genBuffers(n: Sizei, buffers: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenBuffers", .{ n, buffers });
}
pub fn genFramebuffers(n: Sizei, framebuffers: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenFramebuffers", .{ n, framebuffers });
}
pub fn genProgramPipelines(n: Sizei, pipelines: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenProgramPipelines", .{ n, pipelines });
}
pub fn genQueries(n: Sizei, ids: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenQueries", .{ n, ids });
}
pub fn genRenderbuffers(n: Sizei, renderbuffers: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenRenderbuffers", .{ n, renderbuffers });
}
pub fn genSamplers(count: Sizei, samplers: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenSamplers", .{ count, samplers });
}
pub fn genTextures(n: Sizei, textures: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenTextures", .{ n, textures });
}
pub fn genTransformFeedbacks(n: Sizei, ids: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenTransformFeedbacks", .{ n, ids });
}
pub fn genVertexArrays(n: Sizei, arrays: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenVertexArrays", .{ n, arrays });
}
pub fn generateMipmap(target: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGenerateMipmap", .{target});
}
pub fn getActiveAttrib(program: Uint, index: Uint, bufSize: Sizei, length: [*c]Sizei, size: [*c]Int, @"type": [*c]Enum, name: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetActiveAttrib", .{ program, index, bufSize, length, size, @"type", name });
}
pub fn getActiveSubroutineName(program: Uint, shadertype: Enum, index: Uint, bufSize: Sizei, length: [*c]Sizei, name: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetActiveSubroutineName", .{ program, shadertype, index, bufSize, length, name });
}
pub fn getActiveSubroutineUniformName(program: Uint, shadertype: Enum, index: Uint, bufSize: Sizei, length: [*c]Sizei, name: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetActiveSubroutineUniformName", .{ program, shadertype, index, bufSize, length, name });
}
pub fn getActiveSubroutineUniformiv(program: Uint, shadertype: Enum, index: Uint, pname: Enum, values: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetActiveSubroutineUniformiv", .{ program, shadertype, index, pname, values });
}
pub fn getActiveUniform(program: Uint, index: Uint, bufSize: Sizei, length: [*c]Sizei, size: [*c]Int, @"type": [*c]Enum, name: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetActiveUniform", .{ program, index, bufSize, length, size, @"type", name });
}
pub fn getActiveUniformBlockName(program: Uint, uniformBlockIndex: Uint, bufSize: Sizei, length: [*c]Sizei, uniformBlockName: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetActiveUniformBlockName", .{ program, uniformBlockIndex, bufSize, length, uniformBlockName });
}
pub fn getActiveUniformBlockiv(program: Uint, uniformBlockIndex: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetActiveUniformBlockiv", .{ program, uniformBlockIndex, pname, params });
}
pub fn getActiveUniformName(program: Uint, uniformIndex: Uint, bufSize: Sizei, length: [*c]Sizei, uniformName: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetActiveUniformName", .{ program, uniformIndex, bufSize, length, uniformName });
}
pub fn getActiveUniformsiv(program: Uint, uniformCount: Sizei, uniformIndices: [*c]const Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetActiveUniformsiv", .{ program, uniformCount, uniformIndices, pname, params });
}
pub fn getAttachedShaders(program: Uint, maxCount: Sizei, count: [*c]Sizei, shaders: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetAttachedShaders", .{ program, maxCount, count, shaders });
}
pub fn getAttribLocation(program: Uint, name: [*c]const Char) callconv(.C) Int {
    return DispatchTable.current.?.invokeIntercepted("glGetAttribLocation", .{ program, name });
}
pub fn getBooleani_v(target: Enum, index: Uint, data: [*c]Boolean) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetBooleani_v", .{ target, index, data });
}
pub fn getBooleanv(pname: Enum, data: [*c]Boolean) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetBooleanv", .{ pname, data });
}
pub fn getBufferParameteri64v(target: Enum, pname: Enum, params: [*c]Int64) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetBufferParameteri64v", .{ target, pname, params });
}
pub fn getBufferParameteriv(target: Enum, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetBufferParameteriv", .{ target, pname, params });
}
pub fn getBufferPointerv(target: Enum, pname: Enum, params: [*c]?*anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetBufferPointerv", .{ target, pname, params });
}
pub fn getBufferSubData(target: Enum, offset: Intptr, size: Sizeiptr, data: ?*anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetBufferSubData", .{ target, offset, size, data });
}
pub fn getCompressedTexImage(target: Enum, level: Int, img: ?*anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetCompressedTexImage", .{ target, level, img });
}
pub fn getDoublei_v(target: Enum, index: Uint, data: [*c]Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetDoublei_v", .{ target, index, data });
}
pub fn getDoublev(pname: Enum, data: [*c]Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetDoublev", .{ pname, data });
}
pub fn getError() callconv(.C) Enum {
    return DispatchTable.current.?.invokeIntercepted("glGetError", .{});
}
pub fn getFloati_v(target: Enum, index: Uint, data: [*c]Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetFloati_v", .{ target, index, data });
}
pub fn getFloatv(pname: Enum, data: [*c]Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetFloatv", .{ pname, data });
}
pub fn getFragDataIndex(program: Uint, name: [*c]const Char) callconv(.C) Int {
    return DispatchTable.current.?.invokeIntercepted("glGetFragDataIndex", .{ program, name });
}
pub fn getFragDataLocation(program: Uint, name: [*c]const Char) callconv(.C) Int {
    return DispatchTable.current.?.invokeIntercepted("glGetFragDataLocation", .{ program, name });
}
pub fn getFramebufferAttachmentParameteriv(target: Enum, attachment: Enum, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetFramebufferAttachmentParameteriv", .{ target, attachment, pname, params });
}
pub fn getInteger64i_v(target: Enum, index: Uint, data: [*c]Int64) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetInteger64i_v", .{ target, index, data });
}
pub fn getInteger64v(pname: Enum, data: [*c]Int64) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetInteger64v", .{ pname, data });
}
pub fn getIntegeri_v(target: Enum, index: Uint, data: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetIntegeri_v", .{ target, index, data });
}
pub fn getIntegerv(pname: Enum, data: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetIntegerv", .{ pname, data });
}
pub fn getMultisamplefv(pname: Enum, index: Uint, val: [*c]Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetMultisamplefv", .{ pname, index, val });
}
pub fn getProgramBinary(program: Uint, bufSize: Sizei, length: [*c]Sizei, binaryFormat: [*c]Enum, binary: ?*anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetProgramBinary", .{ program, bufSize, length, binaryFormat, binary });
}
pub fn getProgramInfoLog(program: Uint, bufSize: Sizei, length: [*c]Sizei, infoLog: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetProgramInfoLog", .{ program, bufSize, length, infoLog });
}
pub fn getProgramPipelineInfoLog(pipeline: Uint, bufSize: Sizei, length: [*c]Sizei, infoLog: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetProgramPipelineInfoLog", .{ pipeline, bufSize, length, infoLog });
}
pub fn getProgramPipelineiv(pipeline: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetProgramPipelineiv", .{ pipeline, pname, params });
}
pub fn getProgramStageiv(program: Uint, shadertype: Enum, pname: Enum, values: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetProgramStageiv", .{ program, shadertype, pname, values });
}
pub fn getProgramiv(program: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetProgramiv", .{ program, pname, params });
}
pub fn getQueryIndexediv(target: Enum, index: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetQueryIndexediv", .{ target, index, pname, params });
}
pub fn getQueryObjecti64v(id: Uint, pname: Enum, params: [*c]Int64) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetQueryObjecti64v", .{ id, pname, params });
}
pub fn getQueryObjectiv(id: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetQueryObjectiv", .{ id, pname, params });
}
pub fn getQueryObjectui64v(id: Uint, pname: Enum, params: [*c]Uint64) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetQueryObjectui64v", .{ id, pname, params });
}
pub fn getQueryObjectuiv(id: Uint, pname: Enum, params: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetQueryObjectuiv", .{ id, pname, params });
}
pub fn getQueryiv(target: Enum, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetQueryiv", .{ target, pname, params });
}
pub fn getRenderbufferParameteriv(target: Enum, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetRenderbufferParameteriv", .{ target, pname, params });
}
pub fn getSamplerParameterIiv(sampler: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetSamplerParameterIiv", .{ sampler, pname, params });
}
pub fn getSamplerParameterIuiv(sampler: Uint, pname: Enum, params: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetSamplerParameterIuiv", .{ sampler, pname, params });
}
pub fn getSamplerParameterfv(sampler: Uint, pname: Enum, params: [*c]Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetSamplerParameterfv", .{ sampler, pname, params });
}
pub fn getSamplerParameteriv(sampler: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetSamplerParameteriv", .{ sampler, pname, params });
}
pub fn getShaderInfoLog(shader: Uint, bufSize: Sizei, length: [*c]Sizei, infoLog: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetShaderInfoLog", .{ shader, bufSize, length, infoLog });
}
pub fn getShaderPrecisionFormat(shadertype: Enum, precisiontype: Enum, range: [*c]Int, precision: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetShaderPrecisionFormat", .{ shadertype, precisiontype, range, precision });
}
pub fn getShaderSource(shader: Uint, bufSize: Sizei, length: [*c]Sizei, source: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetShaderSource", .{ shader, bufSize, length, source });
}
pub fn getShaderiv(shader: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetShaderiv", .{ shader, pname, params });
}
pub fn getString(name: Enum) callconv(.C) [*c]const Ubyte {
    return DispatchTable.current.?.invokeIntercepted("glGetString", .{name});
}
pub fn getStringi(name: Enum, index: Uint) callconv(.C) [*c]const Ubyte {
    return DispatchTable.current.?.invokeIntercepted("glGetStringi", .{ name, index });
}
pub fn getSubroutineIndex(program: Uint, shadertype: Enum, name: [*c]const Char) callconv(.C) Uint {
    return DispatchTable.current.?.invokeIntercepted("glGetSubroutineIndex", .{ program, shadertype, name });
}
pub fn getSubroutineUniformLocation(program: Uint, shadertype: Enum, name: [*c]const Char) callconv(.C) Int {
    return DispatchTable.current.?.invokeIntercepted("glGetSubroutineUniformLocation", .{ program, shadertype, name });
}
pub fn getSynciv(sync: Sync, pname: Enum, count: Sizei, length: [*c]Sizei, values: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetSynciv", .{ sync, pname, count, length, values });
}
pub fn getTexImage(target: Enum, level: Int, format: Enum, @"type": Enum, pixels: ?*anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetTexImage", .{ target, level, format, @"type", pixels });
}
pub fn getTexLevelParameterfv(target: Enum, level: Int, pname: Enum, params: [*c]Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetTexLevelParameterfv", .{ target, level, pname, params });
}
pub fn getTexLevelParameteriv(target: Enum, level: Int, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetTexLevelParameteriv", .{ target, level, pname, params });
}
pub fn getTexParameterIiv(target: Enum, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetTexParameterIiv", .{ target, pname, params });
}
pub fn getTexParameterIuiv(target: Enum, pname: Enum, params: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetTexParameterIuiv", .{ target, pname, params });
}
pub fn getTexParameterfv(target: Enum, pname: Enum, params: [*c]Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetTexParameterfv", .{ target, pname, params });
}
pub fn getTexParameteriv(target: Enum, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetTexParameteriv", .{ target, pname, params });
}
pub fn getTransformFeedbackVarying(program: Uint, index: Uint, bufSize: Sizei, length: [*c]Sizei, size: [*c]Sizei, @"type": [*c]Enum, name: [*c]Char) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetTransformFeedbackVarying", .{ program, index, bufSize, length, size, @"type", name });
}
pub fn getUniformBlockIndex(program: Uint, uniformBlockName: [*c]const Char) callconv(.C) Uint {
    return DispatchTable.current.?.invokeIntercepted("glGetUniformBlockIndex", .{ program, uniformBlockName });
}
pub fn getUniformIndices(program: Uint, uniformCount: Sizei, uniformNames: [*c]const [*c]const Char, uniformIndices: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetUniformIndices", .{ program, uniformCount, uniformNames, uniformIndices });
}
pub fn getUniformLocation(program: Uint, name: [*c]const Char) callconv(.C) Int {
    return DispatchTable.current.?.invokeIntercepted("glGetUniformLocation", .{ program, name });
}
pub fn getUniformSubroutineuiv(shadertype: Enum, location: Int, params: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetUniformSubroutineuiv", .{ shadertype, location, params });
}
pub fn getUniformdv(program: Uint, location: Int, params: [*c]Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetUniformdv", .{ program, location, params });
}
pub fn getUniformfv(program: Uint, location: Int, params: [*c]Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetUniformfv", .{ program, location, params });
}
pub fn getUniformiv(program: Uint, location: Int, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetUniformiv", .{ program, location, params });
}
pub fn getUniformuiv(program: Uint, location: Int, params: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetUniformuiv", .{ program, location, params });
}
pub fn getVertexAttribIiv(index: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetVertexAttribIiv", .{ index, pname, params });
}
pub fn getVertexAttribIuiv(index: Uint, pname: Enum, params: [*c]Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetVertexAttribIuiv", .{ index, pname, params });
}
pub fn getVertexAttribLdv(index: Uint, pname: Enum, params: [*c]Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetVertexAttribLdv", .{ index, pname, params });
}
pub fn getVertexAttribPointerv(index: Uint, pname: Enum, pointer: [*c]?*anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetVertexAttribPointerv", .{ index, pname, pointer });
}
pub fn getVertexAttribdv(index: Uint, pname: Enum, params: [*c]Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetVertexAttribdv", .{ index, pname, params });
}
pub fn getVertexAttribfv(index: Uint, pname: Enum, params: [*c]Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetVertexAttribfv", .{ index, pname, params });
}
pub fn getVertexAttribiv(index: Uint, pname: Enum, params: [*c]Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glGetVertexAttribiv", .{ index, pname, params });
}
pub fn hint(target: Enum, mode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glHint", .{ target, mode });
}
pub fn isBuffer(buffer: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsBuffer", .{buffer});
}
pub fn isEnabled(cap: Enum) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsEnabled", .{cap});
}
pub fn isEnabledi(target: Enum, index: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsEnabledi", .{ target, index });
}
pub fn isFramebuffer(framebuffer: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsFramebuffer", .{framebuffer});
}
pub fn isProgram(program: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsProgram", .{program});
}
pub fn isProgramPipeline(pipeline: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsProgramPipeline", .{pipeline});
}
pub fn isQuery(id: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsQuery", .{id});
}
pub fn isRenderbuffer(renderbuffer: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsRenderbuffer", .{renderbuffer});
}
pub fn isSampler(sampler: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsSampler", .{sampler});
}
pub fn isShader(shader: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsShader", .{shader});
}
pub fn isSync(sync: Sync) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsSync", .{sync});
}
pub fn isTexture(texture: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsTexture", .{texture});
}
pub fn isTransformFeedback(id: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsTransformFeedback", .{id});
}
pub fn isVertexArray(array: Uint) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glIsVertexArray", .{array});
}
pub fn lineWidth(width: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glLineWidth", .{width});
}
pub fn linkProgram(program: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glLinkProgram", .{program});
}
pub fn logicOp(opcode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glLogicOp", .{opcode});
}
pub fn mapBuffer(target: Enum, access: Enum) callconv(.C) ?*anyopaque {
    return DispatchTable.current.?.invokeIntercepted("glMapBuffer", .{ target, access });
}
pub fn mapBufferRange(target: Enum, offset: Intptr, length: Sizeiptr, access: Bitfield) callconv(.C) ?*anyopaque {
    return DispatchTable.current.?.invokeIntercepted("glMapBufferRange", .{ target, offset, length, access });
}
pub fn minSampleShading(value: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glMinSampleShading", .{value});
}
pub fn multiDrawArrays(mode: Enum, first: [*c]const Int, count: [*c]const Sizei, drawcount: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glMultiDrawArrays", .{ mode, first, count, drawcount });
}
pub fn multiDrawElements(mode: Enum, count: [*c]const Sizei, @"type": Enum, indices: [*c]const ?*const anyopaque, drawcount: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glMultiDrawElements", .{ mode, count, @"type", indices, drawcount });
}
pub fn multiDrawElementsBaseVertex(mode: Enum, count: [*c]const Sizei, @"type": Enum, indices: [*c]const ?*const anyopaque, drawcount: Sizei, basevertex: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glMultiDrawElementsBaseVertex", .{ mode, count, @"type", indices, drawcount, basevertex });
}
pub fn patchParameterfv(pname: Enum, values: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPatchParameterfv", .{ pname, values });
}
pub fn patchParameteri(pname: Enum, value: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPatchParameteri", .{ pname, value });
}
pub fn pauseTransformFeedback() callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPauseTransformFeedback", .{});
}
pub fn pixelStoref(pname: Enum, param: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPixelStoref", .{ pname, param });
}
pub fn pixelStorei(pname: Enum, param: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPixelStorei", .{ pname, param });
}
pub fn pointParameterf(pname: Enum, param: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPointParameterf", .{ pname, param });
}
pub fn pointParameterfv(pname: Enum, params: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPointParameterfv", .{ pname, params });
}
pub fn pointParameteri(pname: Enum, param: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPointParameteri", .{ pname, param });
}
pub fn pointParameteriv(pname: Enum, params: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPointParameteriv", .{ pname, params });
}
pub fn pointSize(size: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPointSize", .{size});
}
pub fn polygonMode(face: Enum, mode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPolygonMode", .{ face, mode });
}
pub fn polygonOffset(factor: Float, units: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPolygonOffset", .{ factor, units });
}
pub fn primitiveRestartIndex(index: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glPrimitiveRestartIndex", .{index});
}
pub fn programBinary(program: Uint, binaryFormat: Enum, binary: ?*const anyopaque, length: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramBinary", .{ program, binaryFormat, binary, length });
}
pub fn programParameteri(program: Uint, pname: Enum, value: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramParameteri", .{ program, pname, value });
}
pub fn programUniform1d(program: Uint, location: Int, v0: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform1d", .{ program, location, v0 });
}
pub fn programUniform1dv(program: Uint, location: Int, count: Sizei, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform1dv", .{ program, location, count, value });
}
pub fn programUniform1f(program: Uint, location: Int, v0: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform1f", .{ program, location, v0 });
}
pub fn programUniform1fv(program: Uint, location: Int, count: Sizei, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform1fv", .{ program, location, count, value });
}
pub fn programUniform1i(program: Uint, location: Int, v0: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform1i", .{ program, location, v0 });
}
pub fn programUniform1iv(program: Uint, location: Int, count: Sizei, value: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform1iv", .{ program, location, count, value });
}
pub fn programUniform1ui(program: Uint, location: Int, v0: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform1ui", .{ program, location, v0 });
}
pub fn programUniform1uiv(program: Uint, location: Int, count: Sizei, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform1uiv", .{ program, location, count, value });
}
pub fn programUniform2d(program: Uint, location: Int, v0: Double, v1: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform2d", .{ program, location, v0, v1 });
}
pub fn programUniform2dv(program: Uint, location: Int, count: Sizei, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform2dv", .{ program, location, count, value });
}
pub fn programUniform2f(program: Uint, location: Int, v0: Float, v1: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform2f", .{ program, location, v0, v1 });
}
pub fn programUniform2fv(program: Uint, location: Int, count: Sizei, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform2fv", .{ program, location, count, value });
}
pub fn programUniform2i(program: Uint, location: Int, v0: Int, v1: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform2i", .{ program, location, v0, v1 });
}
pub fn programUniform2iv(program: Uint, location: Int, count: Sizei, value: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform2iv", .{ program, location, count, value });
}
pub fn programUniform2ui(program: Uint, location: Int, v0: Uint, v1: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform2ui", .{ program, location, v0, v1 });
}
pub fn programUniform2uiv(program: Uint, location: Int, count: Sizei, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform2uiv", .{ program, location, count, value });
}
pub fn programUniform3d(program: Uint, location: Int, v0: Double, v1: Double, v2: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform3d", .{ program, location, v0, v1, v2 });
}
pub fn programUniform3dv(program: Uint, location: Int, count: Sizei, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform3dv", .{ program, location, count, value });
}
pub fn programUniform3f(program: Uint, location: Int, v0: Float, v1: Float, v2: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform3f", .{ program, location, v0, v1, v2 });
}
pub fn programUniform3fv(program: Uint, location: Int, count: Sizei, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform3fv", .{ program, location, count, value });
}
pub fn programUniform3i(program: Uint, location: Int, v0: Int, v1: Int, v2: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform3i", .{ program, location, v0, v1, v2 });
}
pub fn programUniform3iv(program: Uint, location: Int, count: Sizei, value: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform3iv", .{ program, location, count, value });
}
pub fn programUniform3ui(program: Uint, location: Int, v0: Uint, v1: Uint, v2: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform3ui", .{ program, location, v0, v1, v2 });
}
pub fn programUniform3uiv(program: Uint, location: Int, count: Sizei, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform3uiv", .{ program, location, count, value });
}
pub fn programUniform4d(program: Uint, location: Int, v0: Double, v1: Double, v2: Double, v3: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform4d", .{ program, location, v0, v1, v2, v3 });
}
pub fn programUniform4dv(program: Uint, location: Int, count: Sizei, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform4dv", .{ program, location, count, value });
}
pub fn programUniform4f(program: Uint, location: Int, v0: Float, v1: Float, v2: Float, v3: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform4f", .{ program, location, v0, v1, v2, v3 });
}
pub fn programUniform4fv(program: Uint, location: Int, count: Sizei, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform4fv", .{ program, location, count, value });
}
pub fn programUniform4i(program: Uint, location: Int, v0: Int, v1: Int, v2: Int, v3: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform4i", .{ program, location, v0, v1, v2, v3 });
}
pub fn programUniform4iv(program: Uint, location: Int, count: Sizei, value: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform4iv", .{ program, location, count, value });
}
pub fn programUniform4ui(program: Uint, location: Int, v0: Uint, v1: Uint, v2: Uint, v3: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform4ui", .{ program, location, v0, v1, v2, v3 });
}
pub fn programUniform4uiv(program: Uint, location: Int, count: Sizei, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniform4uiv", .{ program, location, count, value });
}
pub fn programUniformMatrix2dv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix2dv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix2fv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix2fv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix2x3dv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix2x3dv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix2x3fv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix2x3fv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix2x4dv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix2x4dv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix2x4fv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix2x4fv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix3dv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix3dv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix3fv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix3fv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix3x2dv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix3x2dv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix3x2fv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix3x2fv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix3x4dv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix3x4dv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix3x4fv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix3x4fv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix4dv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix4dv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix4fv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix4fv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix4x2dv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix4x2dv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix4x2fv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix4x2fv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix4x3dv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix4x3dv", .{ program, location, count, transpose, value });
}
pub fn programUniformMatrix4x3fv(program: Uint, location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProgramUniformMatrix4x3fv", .{ program, location, count, transpose, value });
}
pub fn provokingVertex(mode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glProvokingVertex", .{mode});
}
pub fn queryCounter(id: Uint, target: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glQueryCounter", .{ id, target });
}
pub fn readBuffer(src: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glReadBuffer", .{src});
}
pub fn readPixels(x: Int, y: Int, width: Sizei, height: Sizei, format: Enum, @"type": Enum, pixels: ?*anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glReadPixels", .{ x, y, width, height, format, @"type", pixels });
}
pub fn releaseShaderCompiler() callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glReleaseShaderCompiler", .{});
}
pub fn renderbufferStorage(target: Enum, internalformat: Enum, width: Sizei, height: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glRenderbufferStorage", .{ target, internalformat, width, height });
}
pub fn renderbufferStorageMultisample(target: Enum, samples: Sizei, internalformat: Enum, width: Sizei, height: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glRenderbufferStorageMultisample", .{ target, samples, internalformat, width, height });
}
pub fn resumeTransformFeedback() callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glResumeTransformFeedback", .{});
}
pub fn sampleCoverage(value: Float, invert: Boolean) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glSampleCoverage", .{ value, invert });
}
pub fn sampleMaski(maskNumber: Uint, mask: Bitfield) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glSampleMaski", .{ maskNumber, mask });
}
pub fn samplerParameterIiv(sampler: Uint, pname: Enum, param: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glSamplerParameterIiv", .{ sampler, pname, param });
}
pub fn samplerParameterIuiv(sampler: Uint, pname: Enum, param: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glSamplerParameterIuiv", .{ sampler, pname, param });
}
pub fn samplerParameterf(sampler: Uint, pname: Enum, param: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glSamplerParameterf", .{ sampler, pname, param });
}
pub fn samplerParameterfv(sampler: Uint, pname: Enum, param: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glSamplerParameterfv", .{ sampler, pname, param });
}
pub fn samplerParameteri(sampler: Uint, pname: Enum, param: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glSamplerParameteri", .{ sampler, pname, param });
}
pub fn samplerParameteriv(sampler: Uint, pname: Enum, param: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glSamplerParameteriv", .{ sampler, pname, param });
}
pub fn scissor(x: Int, y: Int, width: Sizei, height: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glScissor", .{ x, y, width, height });
}
pub fn scissorArrayv(first: Uint, count: Sizei, v: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glScissorArrayv", .{ first, count, v });
}
pub fn scissorIndexed(index: Uint, left: Int, bottom: Int, width: Sizei, height: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glScissorIndexed", .{ index, left, bottom, width, height });
}
pub fn scissorIndexedv(index: Uint, v: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glScissorIndexedv", .{ index, v });
}
pub fn shaderBinary(count: Sizei, shaders: [*c]const Uint, binaryFormat: Enum, binary: ?*const anyopaque, length: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glShaderBinary", .{ count, shaders, binaryFormat, binary, length });
}
pub fn shaderSource(shader: Uint, count: Sizei, string: [*c]const [*c]const Char, length: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glShaderSource", .{ shader, count, string, length });
}
pub fn stencilFunc(func: Enum, ref: Int, mask: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glStencilFunc", .{ func, ref, mask });
}
pub fn stencilFuncSeparate(face: Enum, func: Enum, ref: Int, mask: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glStencilFuncSeparate", .{ face, func, ref, mask });
}
pub fn stencilMask(mask: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glStencilMask", .{mask});
}
pub fn stencilMaskSeparate(face: Enum, mask: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glStencilMaskSeparate", .{ face, mask });
}
pub fn stencilOp(fail: Enum, zfail: Enum, zpass: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glStencilOp", .{ fail, zfail, zpass });
}
pub fn stencilOpSeparate(face: Enum, sfail: Enum, dpfail: Enum, dppass: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glStencilOpSeparate", .{ face, sfail, dpfail, dppass });
}
pub fn texBuffer(target: Enum, internalformat: Enum, buffer: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexBuffer", .{ target, internalformat, buffer });
}
pub fn texImage1D(target: Enum, level: Int, internalformat: Int, width: Sizei, border: Int, format: Enum, @"type": Enum, pixels: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexImage1D", .{ target, level, internalformat, width, border, format, @"type", pixels });
}
pub fn texImage2D(target: Enum, level: Int, internalformat: Int, width: Sizei, height: Sizei, border: Int, format: Enum, @"type": Enum, pixels: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexImage2D", .{ target, level, internalformat, width, height, border, format, @"type", pixels });
}
pub fn texImage2DMultisample(target: Enum, samples: Sizei, internalformat: Enum, width: Sizei, height: Sizei, fixedsamplelocations: Boolean) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexImage2DMultisample", .{ target, samples, internalformat, width, height, fixedsamplelocations });
}
pub fn texImage3D(target: Enum, level: Int, internalformat: Int, width: Sizei, height: Sizei, depth: Sizei, border: Int, format: Enum, @"type": Enum, pixels: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexImage3D", .{ target, level, internalformat, width, height, depth, border, format, @"type", pixels });
}
pub fn texImage3DMultisample(target: Enum, samples: Sizei, internalformat: Enum, width: Sizei, height: Sizei, depth: Sizei, fixedsamplelocations: Boolean) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexImage3DMultisample", .{ target, samples, internalformat, width, height, depth, fixedsamplelocations });
}
pub fn texParameterIiv(target: Enum, pname: Enum, params: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexParameterIiv", .{ target, pname, params });
}
pub fn texParameterIuiv(target: Enum, pname: Enum, params: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexParameterIuiv", .{ target, pname, params });
}
pub fn texParameterf(target: Enum, pname: Enum, param: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexParameterf", .{ target, pname, param });
}
pub fn texParameterfv(target: Enum, pname: Enum, params: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexParameterfv", .{ target, pname, params });
}
pub fn texParameteri(target: Enum, pname: Enum, param: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexParameteri", .{ target, pname, param });
}
pub fn texParameteriv(target: Enum, pname: Enum, params: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexParameteriv", .{ target, pname, params });
}
pub fn texSubImage1D(target: Enum, level: Int, xoffset: Int, width: Sizei, format: Enum, @"type": Enum, pixels: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexSubImage1D", .{ target, level, xoffset, width, format, @"type", pixels });
}
pub fn texSubImage2D(target: Enum, level: Int, xoffset: Int, yoffset: Int, width: Sizei, height: Sizei, format: Enum, @"type": Enum, pixels: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexSubImage2D", .{ target, level, xoffset, yoffset, width, height, format, @"type", pixels });
}
pub fn texSubImage3D(target: Enum, level: Int, xoffset: Int, yoffset: Int, zoffset: Int, width: Sizei, height: Sizei, depth: Sizei, format: Enum, @"type": Enum, pixels: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTexSubImage3D", .{ target, level, xoffset, yoffset, zoffset, width, height, depth, format, @"type", pixels });
}
pub fn transformFeedbackVaryings(program: Uint, count: Sizei, varyings: [*c]const [*c]const Char, bufferMode: Enum) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glTransformFeedbackVaryings", .{ program, count, varyings, bufferMode });
}
pub fn uniform1d(location: Int, x: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform1d", .{ location, x });
}
pub fn uniform1dv(location: Int, count: Sizei, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform1dv", .{ location, count, value });
}
pub fn uniform1f(location: Int, v0: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform1f", .{ location, v0 });
}
pub fn uniform1fv(location: Int, count: Sizei, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform1fv", .{ location, count, value });
}
pub fn uniform1i(location: Int, v0: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform1i", .{ location, v0 });
}
pub fn uniform1iv(location: Int, count: Sizei, value: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform1iv", .{ location, count, value });
}
pub fn uniform1ui(location: Int, v0: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform1ui", .{ location, v0 });
}
pub fn uniform1uiv(location: Int, count: Sizei, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform1uiv", .{ location, count, value });
}
pub fn uniform2d(location: Int, x: Double, y: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform2d", .{ location, x, y });
}
pub fn uniform2dv(location: Int, count: Sizei, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform2dv", .{ location, count, value });
}
pub fn uniform2f(location: Int, v0: Float, v1: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform2f", .{ location, v0, v1 });
}
pub fn uniform2fv(location: Int, count: Sizei, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform2fv", .{ location, count, value });
}
pub fn uniform2i(location: Int, v0: Int, v1: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform2i", .{ location, v0, v1 });
}
pub fn uniform2iv(location: Int, count: Sizei, value: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform2iv", .{ location, count, value });
}
pub fn uniform2ui(location: Int, v0: Uint, v1: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform2ui", .{ location, v0, v1 });
}
pub fn uniform2uiv(location: Int, count: Sizei, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform2uiv", .{ location, count, value });
}
pub fn uniform3d(location: Int, x: Double, y: Double, z: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform3d", .{ location, x, y, z });
}
pub fn uniform3dv(location: Int, count: Sizei, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform3dv", .{ location, count, value });
}
pub fn uniform3f(location: Int, v0: Float, v1: Float, v2: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform3f", .{ location, v0, v1, v2 });
}
pub fn uniform3fv(location: Int, count: Sizei, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform3fv", .{ location, count, value });
}
pub fn uniform3i(location: Int, v0: Int, v1: Int, v2: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform3i", .{ location, v0, v1, v2 });
}
pub fn uniform3iv(location: Int, count: Sizei, value: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform3iv", .{ location, count, value });
}
pub fn uniform3ui(location: Int, v0: Uint, v1: Uint, v2: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform3ui", .{ location, v0, v1, v2 });
}
pub fn uniform3uiv(location: Int, count: Sizei, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform3uiv", .{ location, count, value });
}
pub fn uniform4d(location: Int, x: Double, y: Double, z: Double, w: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform4d", .{ location, x, y, z, w });
}
pub fn uniform4dv(location: Int, count: Sizei, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform4dv", .{ location, count, value });
}
pub fn uniform4f(location: Int, v0: Float, v1: Float, v2: Float, v3: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform4f", .{ location, v0, v1, v2, v3 });
}
pub fn uniform4fv(location: Int, count: Sizei, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform4fv", .{ location, count, value });
}
pub fn uniform4i(location: Int, v0: Int, v1: Int, v2: Int, v3: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform4i", .{ location, v0, v1, v2, v3 });
}
pub fn uniform4iv(location: Int, count: Sizei, value: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform4iv", .{ location, count, value });
}
pub fn uniform4ui(location: Int, v0: Uint, v1: Uint, v2: Uint, v3: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform4ui", .{ location, v0, v1, v2, v3 });
}
pub fn uniform4uiv(location: Int, count: Sizei, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniform4uiv", .{ location, count, value });
}
pub fn uniformBlockBinding(program: Uint, uniformBlockIndex: Uint, uniformBlockBinding_: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformBlockBinding", .{ program, uniformBlockIndex, uniformBlockBinding_ });
}
pub fn uniformMatrix2dv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix2dv", .{ location, count, transpose, value });
}
pub fn uniformMatrix2fv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix2fv", .{ location, count, transpose, value });
}
pub fn uniformMatrix2x3dv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix2x3dv", .{ location, count, transpose, value });
}
pub fn uniformMatrix2x3fv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix2x3fv", .{ location, count, transpose, value });
}
pub fn uniformMatrix2x4dv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix2x4dv", .{ location, count, transpose, value });
}
pub fn uniformMatrix2x4fv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix2x4fv", .{ location, count, transpose, value });
}
pub fn uniformMatrix3dv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix3dv", .{ location, count, transpose, value });
}
pub fn uniformMatrix3fv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix3fv", .{ location, count, transpose, value });
}
pub fn uniformMatrix3x2dv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix3x2dv", .{ location, count, transpose, value });
}
pub fn uniformMatrix3x2fv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix3x2fv", .{ location, count, transpose, value });
}
pub fn uniformMatrix3x4dv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix3x4dv", .{ location, count, transpose, value });
}
pub fn uniformMatrix3x4fv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix3x4fv", .{ location, count, transpose, value });
}
pub fn uniformMatrix4dv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix4dv", .{ location, count, transpose, value });
}
pub fn uniformMatrix4fv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix4fv", .{ location, count, transpose, value });
}
pub fn uniformMatrix4x2dv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix4x2dv", .{ location, count, transpose, value });
}
pub fn uniformMatrix4x2fv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix4x2fv", .{ location, count, transpose, value });
}
pub fn uniformMatrix4x3dv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix4x3dv", .{ location, count, transpose, value });
}
pub fn uniformMatrix4x3fv(location: Int, count: Sizei, transpose: Boolean, value: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformMatrix4x3fv", .{ location, count, transpose, value });
}
pub fn uniformSubroutinesuiv(shadertype: Enum, count: Sizei, indices: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUniformSubroutinesuiv", .{ shadertype, count, indices });
}
pub fn unmapBuffer(target: Enum) callconv(.C) Boolean {
    return DispatchTable.current.?.invokeIntercepted("glUnmapBuffer", .{target});
}
pub fn useProgram(program: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUseProgram", .{program});
}
pub fn useProgramStages(pipeline: Uint, stages: Bitfield, program: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glUseProgramStages", .{ pipeline, stages, program });
}
pub fn validateProgram(program: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glValidateProgram", .{program});
}
pub fn validateProgramPipeline(pipeline: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glValidateProgramPipeline", .{pipeline});
}
pub fn vertexAttrib1d(index: Uint, x: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib1d", .{ index, x });
}
pub fn vertexAttrib1dv(index: Uint, v: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib1dv", .{ index, v });
}
pub fn vertexAttrib1f(index: Uint, x: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib1f", .{ index, x });
}
pub fn vertexAttrib1fv(index: Uint, v: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib1fv", .{ index, v });
}
pub fn vertexAttrib1s(index: Uint, x: Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib1s", .{ index, x });
}
pub fn vertexAttrib1sv(index: Uint, v: [*c]const Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib1sv", .{ index, v });
}
pub fn vertexAttrib2d(index: Uint, x: Double, y: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib2d", .{ index, x, y });
}
pub fn vertexAttrib2dv(index: Uint, v: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib2dv", .{ index, v });
}
pub fn vertexAttrib2f(index: Uint, x: Float, y: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib2f", .{ index, x, y });
}
pub fn vertexAttrib2fv(index: Uint, v: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib2fv", .{ index, v });
}
pub fn vertexAttrib2s(index: Uint, x: Short, y: Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib2s", .{ index, x, y });
}
pub fn vertexAttrib2sv(index: Uint, v: [*c]const Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib2sv", .{ index, v });
}
pub fn vertexAttrib3d(index: Uint, x: Double, y: Double, z: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib3d", .{ index, x, y, z });
}
pub fn vertexAttrib3dv(index: Uint, v: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib3dv", .{ index, v });
}
pub fn vertexAttrib3f(index: Uint, x: Float, y: Float, z: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib3f", .{ index, x, y, z });
}
pub fn vertexAttrib3fv(index: Uint, v: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib3fv", .{ index, v });
}
pub fn vertexAttrib3s(index: Uint, x: Short, y: Short, z: Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib3s", .{ index, x, y, z });
}
pub fn vertexAttrib3sv(index: Uint, v: [*c]const Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib3sv", .{ index, v });
}
pub fn vertexAttrib4Nbv(index: Uint, v: [*c]const Byte) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4Nbv", .{ index, v });
}
pub fn vertexAttrib4Niv(index: Uint, v: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4Niv", .{ index, v });
}
pub fn vertexAttrib4Nsv(index: Uint, v: [*c]const Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4Nsv", .{ index, v });
}
pub fn vertexAttrib4Nub(index: Uint, x: Ubyte, y: Ubyte, z: Ubyte, w: Ubyte) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4Nub", .{ index, x, y, z, w });
}
pub fn vertexAttrib4Nubv(index: Uint, v: [*c]const Ubyte) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4Nubv", .{ index, v });
}
pub fn vertexAttrib4Nuiv(index: Uint, v: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4Nuiv", .{ index, v });
}
pub fn vertexAttrib4Nusv(index: Uint, v: [*c]const Ushort) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4Nusv", .{ index, v });
}
pub fn vertexAttrib4bv(index: Uint, v: [*c]const Byte) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4bv", .{ index, v });
}
pub fn vertexAttrib4d(index: Uint, x: Double, y: Double, z: Double, w: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4d", .{ index, x, y, z, w });
}
pub fn vertexAttrib4dv(index: Uint, v: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4dv", .{ index, v });
}
pub fn vertexAttrib4f(index: Uint, x: Float, y: Float, z: Float, w: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4f", .{ index, x, y, z, w });
}
pub fn vertexAttrib4fv(index: Uint, v: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4fv", .{ index, v });
}
pub fn vertexAttrib4iv(index: Uint, v: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4iv", .{ index, v });
}
pub fn vertexAttrib4s(index: Uint, x: Short, y: Short, z: Short, w: Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4s", .{ index, x, y, z, w });
}
pub fn vertexAttrib4sv(index: Uint, v: [*c]const Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4sv", .{ index, v });
}
pub fn vertexAttrib4ubv(index: Uint, v: [*c]const Ubyte) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4ubv", .{ index, v });
}
pub fn vertexAttrib4uiv(index: Uint, v: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4uiv", .{ index, v });
}
pub fn vertexAttrib4usv(index: Uint, v: [*c]const Ushort) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttrib4usv", .{ index, v });
}
pub fn vertexAttribDivisor(index: Uint, divisor: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribDivisor", .{ index, divisor });
}
pub fn vertexAttribI1i(index: Uint, x: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI1i", .{ index, x });
}
pub fn vertexAttribI1iv(index: Uint, v: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI1iv", .{ index, v });
}
pub fn vertexAttribI1ui(index: Uint, x: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI1ui", .{ index, x });
}
pub fn vertexAttribI1uiv(index: Uint, v: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI1uiv", .{ index, v });
}
pub fn vertexAttribI2i(index: Uint, x: Int, y: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI2i", .{ index, x, y });
}
pub fn vertexAttribI2iv(index: Uint, v: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI2iv", .{ index, v });
}
pub fn vertexAttribI2ui(index: Uint, x: Uint, y: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI2ui", .{ index, x, y });
}
pub fn vertexAttribI2uiv(index: Uint, v: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI2uiv", .{ index, v });
}
pub fn vertexAttribI3i(index: Uint, x: Int, y: Int, z: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI3i", .{ index, x, y, z });
}
pub fn vertexAttribI3iv(index: Uint, v: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI3iv", .{ index, v });
}
pub fn vertexAttribI3ui(index: Uint, x: Uint, y: Uint, z: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI3ui", .{ index, x, y, z });
}
pub fn vertexAttribI3uiv(index: Uint, v: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI3uiv", .{ index, v });
}
pub fn vertexAttribI4bv(index: Uint, v: [*c]const Byte) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI4bv", .{ index, v });
}
pub fn vertexAttribI4i(index: Uint, x: Int, y: Int, z: Int, w: Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI4i", .{ index, x, y, z, w });
}
pub fn vertexAttribI4iv(index: Uint, v: [*c]const Int) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI4iv", .{ index, v });
}
pub fn vertexAttribI4sv(index: Uint, v: [*c]const Short) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI4sv", .{ index, v });
}
pub fn vertexAttribI4ubv(index: Uint, v: [*c]const Ubyte) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI4ubv", .{ index, v });
}
pub fn vertexAttribI4ui(index: Uint, x: Uint, y: Uint, z: Uint, w: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI4ui", .{ index, x, y, z, w });
}
pub fn vertexAttribI4uiv(index: Uint, v: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI4uiv", .{ index, v });
}
pub fn vertexAttribI4usv(index: Uint, v: [*c]const Ushort) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribI4usv", .{ index, v });
}
pub fn vertexAttribIPointer(index: Uint, size: Int, @"type": Enum, stride: Sizei, pointer: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribIPointer", .{ index, size, @"type", stride, pointer });
}
pub fn vertexAttribL1d(index: Uint, x: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribL1d", .{ index, x });
}
pub fn vertexAttribL1dv(index: Uint, v: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribL1dv", .{ index, v });
}
pub fn vertexAttribL2d(index: Uint, x: Double, y: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribL2d", .{ index, x, y });
}
pub fn vertexAttribL2dv(index: Uint, v: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribL2dv", .{ index, v });
}
pub fn vertexAttribL3d(index: Uint, x: Double, y: Double, z: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribL3d", .{ index, x, y, z });
}
pub fn vertexAttribL3dv(index: Uint, v: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribL3dv", .{ index, v });
}
pub fn vertexAttribL4d(index: Uint, x: Double, y: Double, z: Double, w: Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribL4d", .{ index, x, y, z, w });
}
pub fn vertexAttribL4dv(index: Uint, v: [*c]const Double) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribL4dv", .{ index, v });
}
pub fn vertexAttribLPointer(index: Uint, size: Int, @"type": Enum, stride: Sizei, pointer: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribLPointer", .{ index, size, @"type", stride, pointer });
}
pub fn vertexAttribP1ui(index: Uint, @"type": Enum, normalized: Boolean, value: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribP1ui", .{ index, @"type", normalized, value });
}
pub fn vertexAttribP1uiv(index: Uint, @"type": Enum, normalized: Boolean, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribP1uiv", .{ index, @"type", normalized, value });
}
pub fn vertexAttribP2ui(index: Uint, @"type": Enum, normalized: Boolean, value: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribP2ui", .{ index, @"type", normalized, value });
}
pub fn vertexAttribP2uiv(index: Uint, @"type": Enum, normalized: Boolean, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribP2uiv", .{ index, @"type", normalized, value });
}
pub fn vertexAttribP3ui(index: Uint, @"type": Enum, normalized: Boolean, value: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribP3ui", .{ index, @"type", normalized, value });
}
pub fn vertexAttribP3uiv(index: Uint, @"type": Enum, normalized: Boolean, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribP3uiv", .{ index, @"type", normalized, value });
}
pub fn vertexAttribP4ui(index: Uint, @"type": Enum, normalized: Boolean, value: Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribP4ui", .{ index, @"type", normalized, value });
}
pub fn vertexAttribP4uiv(index: Uint, @"type": Enum, normalized: Boolean, value: [*c]const Uint) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribP4uiv", .{ index, @"type", normalized, value });
}
pub fn vertexAttribPointer(index: Uint, size: Int, @"type": Enum, normalized: Boolean, stride: Sizei, pointer: ?*const anyopaque) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glVertexAttribPointer", .{ index, size, @"type", normalized, stride, pointer });
}
pub fn viewport(x: Int, y: Int, width: Sizei, height: Sizei) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glViewport", .{ x, y, width, height });
}
pub fn viewportArrayv(first: Uint, count: Sizei, v: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glViewportArrayv", .{ first, count, v });
}
pub fn viewportIndexedf(index: Uint, x: Float, y: Float, w: Float, h: Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glViewportIndexedf", .{ index, x, y, w, h });
}
pub fn viewportIndexedfv(index: Uint, v: [*c]const Float) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glViewportIndexedfv", .{ index, v });
}
pub fn waitSync(sync: Sync, flags: Bitfield, timeout: Uint64) callconv(.C) void {
    return DispatchTable.current.?.invokeIntercepted("glWaitSync", .{ sync, flags, timeout });
}
//#endregion Commands

/// Holds dynamically loaded OpenGL features.
///
/// This struct is very large; avoid storing instances of it on the stack.
pub const DispatchTable = struct {
    threadlocal var current: ?*const DispatchTable = null;

    //#region Fields
    glActiveShaderProgram: *const @TypeOf(activeShaderProgram),
    glActiveTexture: *const @TypeOf(activeTexture),
    glAttachShader: *const @TypeOf(attachShader),
    glBeginConditionalRender: *const @TypeOf(beginConditionalRender),
    glBeginQuery: *const @TypeOf(beginQuery),
    glBeginQueryIndexed: *const @TypeOf(beginQueryIndexed),
    glBeginTransformFeedback: *const @TypeOf(beginTransformFeedback),
    glBindAttribLocation: *const @TypeOf(bindAttribLocation),
    glBindBuffer: *const @TypeOf(bindBuffer),
    glBindBufferBase: *const @TypeOf(bindBufferBase),
    glBindBufferRange: *const @TypeOf(bindBufferRange),
    glBindFragDataLocation: *const @TypeOf(bindFragDataLocation),
    glBindFragDataLocationIndexed: *const @TypeOf(bindFragDataLocationIndexed),
    glBindFramebuffer: *const @TypeOf(bindFramebuffer),
    glBindProgramPipeline: *const @TypeOf(bindProgramPipeline),
    glBindRenderbuffer: *const @TypeOf(bindRenderbuffer),
    glBindSampler: *const @TypeOf(bindSampler),
    glBindTexture: *const @TypeOf(bindTexture),
    glBindTransformFeedback: *const @TypeOf(bindTransformFeedback),
    glBindVertexArray: *const @TypeOf(bindVertexArray),
    glBlendColor: *const @TypeOf(blendColor),
    glBlendEquation: *const @TypeOf(blendEquation),
    glBlendEquationSeparate: *const @TypeOf(blendEquationSeparate),
    glBlendEquationSeparatei: *const @TypeOf(blendEquationSeparatei),
    glBlendEquationi: *const @TypeOf(blendEquationi),
    glBlendFunc: *const @TypeOf(blendFunc),
    glBlendFuncSeparate: *const @TypeOf(blendFuncSeparate),
    glBlendFuncSeparatei: *const @TypeOf(blendFuncSeparatei),
    glBlendFunci: *const @TypeOf(blendFunci),
    glBlitFramebuffer: *const @TypeOf(blitFramebuffer),
    glBufferData: *const @TypeOf(bufferData),
    glBufferSubData: *const @TypeOf(bufferSubData),
    glCheckFramebufferStatus: *const @TypeOf(checkFramebufferStatus),
    glClampColor: *const @TypeOf(clampColor),
    glClear: *const @TypeOf(clear),
    glClearBufferfi: *const @TypeOf(clearBufferfi),
    glClearBufferfv: *const @TypeOf(clearBufferfv),
    glClearBufferiv: *const @TypeOf(clearBufferiv),
    glClearBufferuiv: *const @TypeOf(clearBufferuiv),
    glClearColor: *const @TypeOf(clearColor),
    glClearDepth: *const @TypeOf(clearDepth),
    glClearDepthf: *const @TypeOf(clearDepthf),
    glClearStencil: *const @TypeOf(clearStencil),
    glClientWaitSync: *const @TypeOf(clientWaitSync),
    glColorMask: *const @TypeOf(colorMask),
    glColorMaski: *const @TypeOf(colorMaski),
    glCompileShader: *const @TypeOf(compileShader),
    glCompressedTexImage1D: *const @TypeOf(compressedTexImage1D),
    glCompressedTexImage2D: *const @TypeOf(compressedTexImage2D),
    glCompressedTexImage3D: *const @TypeOf(compressedTexImage3D),
    glCompressedTexSubImage1D: *const @TypeOf(compressedTexSubImage1D),
    glCompressedTexSubImage2D: *const @TypeOf(compressedTexSubImage2D),
    glCompressedTexSubImage3D: *const @TypeOf(compressedTexSubImage3D),
    glCopyBufferSubData: *const @TypeOf(copyBufferSubData),
    glCopyTexImage1D: *const @TypeOf(copyTexImage1D),
    glCopyTexImage2D: *const @TypeOf(copyTexImage2D),
    glCopyTexSubImage1D: *const @TypeOf(copyTexSubImage1D),
    glCopyTexSubImage2D: *const @TypeOf(copyTexSubImage2D),
    glCopyTexSubImage3D: *const @TypeOf(copyTexSubImage3D),
    glCreateProgram: *const @TypeOf(createProgram),
    glCreateShader: *const @TypeOf(createShader),
    glCreateShaderProgramv: *const @TypeOf(createShaderProgramv),
    glCullFace: *const @TypeOf(cullFace),
    glDeleteBuffers: *const @TypeOf(deleteBuffers),
    glDeleteFramebuffers: *const @TypeOf(deleteFramebuffers),
    glDeleteProgram: *const @TypeOf(deleteProgram),
    glDeleteProgramPipelines: *const @TypeOf(deleteProgramPipelines),
    glDeleteQueries: *const @TypeOf(deleteQueries),
    glDeleteRenderbuffers: *const @TypeOf(deleteRenderbuffers),
    glDeleteSamplers: *const @TypeOf(deleteSamplers),
    glDeleteShader: *const @TypeOf(deleteShader),
    glDeleteSync: *const @TypeOf(deleteSync),
    glDeleteTextures: *const @TypeOf(deleteTextures),
    glDeleteTransformFeedbacks: *const @TypeOf(deleteTransformFeedbacks),
    glDeleteVertexArrays: *const @TypeOf(deleteVertexArrays),
    glDepthFunc: *const @TypeOf(depthFunc),
    glDepthMask: *const @TypeOf(depthMask),
    glDepthRange: *const @TypeOf(depthRange),
    glDepthRangeArrayv: *const @TypeOf(depthRangeArrayv),
    glDepthRangeIndexed: *const @TypeOf(depthRangeIndexed),
    glDepthRangef: *const @TypeOf(depthRangef),
    glDetachShader: *const @TypeOf(detachShader),
    glDisable: *const @TypeOf(disable),
    glDisableVertexAttribArray: *const @TypeOf(disableVertexAttribArray),
    glDisablei: *const @TypeOf(disablei),
    glDrawArrays: *const @TypeOf(drawArrays),
    glDrawArraysIndirect: *const @TypeOf(drawArraysIndirect),
    glDrawArraysInstanced: *const @TypeOf(drawArraysInstanced),
    glDrawBuffer: *const @TypeOf(drawBuffer),
    glDrawBuffers: *const @TypeOf(drawBuffers),
    glDrawElements: *const @TypeOf(drawElements),
    glDrawElementsBaseVertex: *const @TypeOf(drawElementsBaseVertex),
    glDrawElementsIndirect: *const @TypeOf(drawElementsIndirect),
    glDrawElementsInstanced: *const @TypeOf(drawElementsInstanced),
    glDrawElementsInstancedBaseVertex: *const @TypeOf(drawElementsInstancedBaseVertex),
    glDrawRangeElements: *const @TypeOf(drawRangeElements),
    glDrawRangeElementsBaseVertex: *const @TypeOf(drawRangeElementsBaseVertex),
    glDrawTransformFeedback: *const @TypeOf(drawTransformFeedback),
    glDrawTransformFeedbackStream: *const @TypeOf(drawTransformFeedbackStream),
    glEnable: *const @TypeOf(enable),
    glEnableVertexAttribArray: *const @TypeOf(enableVertexAttribArray),
    glEnablei: *const @TypeOf(enablei),
    glEndConditionalRender: *const @TypeOf(endConditionalRender),
    glEndQuery: *const @TypeOf(endQuery),
    glEndQueryIndexed: *const @TypeOf(endQueryIndexed),
    glEndTransformFeedback: *const @TypeOf(endTransformFeedback),
    glFenceSync: *const @TypeOf(fenceSync),
    glFinish: *const @TypeOf(finish),
    glFlush: *const @TypeOf(flush),
    glFlushMappedBufferRange: *const @TypeOf(flushMappedBufferRange),
    glFramebufferRenderbuffer: *const @TypeOf(framebufferRenderbuffer),
    glFramebufferTexture: *const @TypeOf(framebufferTexture),
    glFramebufferTexture1D: *const @TypeOf(framebufferTexture1D),
    glFramebufferTexture2D: *const @TypeOf(framebufferTexture2D),
    glFramebufferTexture3D: *const @TypeOf(framebufferTexture3D),
    glFramebufferTextureLayer: *const @TypeOf(framebufferTextureLayer),
    glFrontFace: *const @TypeOf(frontFace),
    glGenBuffers: *const @TypeOf(genBuffers),
    glGenFramebuffers: *const @TypeOf(genFramebuffers),
    glGenProgramPipelines: *const @TypeOf(genProgramPipelines),
    glGenQueries: *const @TypeOf(genQueries),
    glGenRenderbuffers: *const @TypeOf(genRenderbuffers),
    glGenSamplers: *const @TypeOf(genSamplers),
    glGenTextures: *const @TypeOf(genTextures),
    glGenTransformFeedbacks: *const @TypeOf(genTransformFeedbacks),
    glGenVertexArrays: *const @TypeOf(genVertexArrays),
    glGenerateMipmap: *const @TypeOf(generateMipmap),
    glGetActiveAttrib: *const @TypeOf(getActiveAttrib),
    glGetActiveSubroutineName: *const @TypeOf(getActiveSubroutineName),
    glGetActiveSubroutineUniformName: *const @TypeOf(getActiveSubroutineUniformName),
    glGetActiveSubroutineUniformiv: *const @TypeOf(getActiveSubroutineUniformiv),
    glGetActiveUniform: *const @TypeOf(getActiveUniform),
    glGetActiveUniformBlockName: *const @TypeOf(getActiveUniformBlockName),
    glGetActiveUniformBlockiv: *const @TypeOf(getActiveUniformBlockiv),
    glGetActiveUniformName: *const @TypeOf(getActiveUniformName),
    glGetActiveUniformsiv: *const @TypeOf(getActiveUniformsiv),
    glGetAttachedShaders: *const @TypeOf(getAttachedShaders),
    glGetAttribLocation: *const @TypeOf(getAttribLocation),
    glGetBooleani_v: *const @TypeOf(getBooleani_v),
    glGetBooleanv: *const @TypeOf(getBooleanv),
    glGetBufferParameteri64v: *const @TypeOf(getBufferParameteri64v),
    glGetBufferParameteriv: *const @TypeOf(getBufferParameteriv),
    glGetBufferPointerv: *const @TypeOf(getBufferPointerv),
    glGetBufferSubData: *const @TypeOf(getBufferSubData),
    glGetCompressedTexImage: *const @TypeOf(getCompressedTexImage),
    glGetDoublei_v: *const @TypeOf(getDoublei_v),
    glGetDoublev: *const @TypeOf(getDoublev),
    glGetError: *const @TypeOf(getError),
    glGetFloati_v: *const @TypeOf(getFloati_v),
    glGetFloatv: *const @TypeOf(getFloatv),
    glGetFragDataIndex: *const @TypeOf(getFragDataIndex),
    glGetFragDataLocation: *const @TypeOf(getFragDataLocation),
    glGetFramebufferAttachmentParameteriv: *const @TypeOf(getFramebufferAttachmentParameteriv),
    glGetInteger64i_v: *const @TypeOf(getInteger64i_v),
    glGetInteger64v: *const @TypeOf(getInteger64v),
    glGetIntegeri_v: *const @TypeOf(getIntegeri_v),
    glGetIntegerv: *const @TypeOf(getIntegerv),
    glGetMultisamplefv: *const @TypeOf(getMultisamplefv),
    glGetProgramBinary: *const @TypeOf(getProgramBinary),
    glGetProgramInfoLog: *const @TypeOf(getProgramInfoLog),
    glGetProgramPipelineInfoLog: *const @TypeOf(getProgramPipelineInfoLog),
    glGetProgramPipelineiv: *const @TypeOf(getProgramPipelineiv),
    glGetProgramStageiv: *const @TypeOf(getProgramStageiv),
    glGetProgramiv: *const @TypeOf(getProgramiv),
    glGetQueryIndexediv: *const @TypeOf(getQueryIndexediv),
    glGetQueryObjecti64v: *const @TypeOf(getQueryObjecti64v),
    glGetQueryObjectiv: *const @TypeOf(getQueryObjectiv),
    glGetQueryObjectui64v: *const @TypeOf(getQueryObjectui64v),
    glGetQueryObjectuiv: *const @TypeOf(getQueryObjectuiv),
    glGetQueryiv: *const @TypeOf(getQueryiv),
    glGetRenderbufferParameteriv: *const @TypeOf(getRenderbufferParameteriv),
    glGetSamplerParameterIiv: *const @TypeOf(getSamplerParameterIiv),
    glGetSamplerParameterIuiv: *const @TypeOf(getSamplerParameterIuiv),
    glGetSamplerParameterfv: *const @TypeOf(getSamplerParameterfv),
    glGetSamplerParameteriv: *const @TypeOf(getSamplerParameteriv),
    glGetShaderInfoLog: *const @TypeOf(getShaderInfoLog),
    glGetShaderPrecisionFormat: *const @TypeOf(getShaderPrecisionFormat),
    glGetShaderSource: *const @TypeOf(getShaderSource),
    glGetShaderiv: *const @TypeOf(getShaderiv),
    glGetString: *const @TypeOf(getString),
    glGetStringi: *const @TypeOf(getStringi),
    glGetSubroutineIndex: *const @TypeOf(getSubroutineIndex),
    glGetSubroutineUniformLocation: *const @TypeOf(getSubroutineUniformLocation),
    glGetSynciv: *const @TypeOf(getSynciv),
    glGetTexImage: *const @TypeOf(getTexImage),
    glGetTexLevelParameterfv: *const @TypeOf(getTexLevelParameterfv),
    glGetTexLevelParameteriv: *const @TypeOf(getTexLevelParameteriv),
    glGetTexParameterIiv: *const @TypeOf(getTexParameterIiv),
    glGetTexParameterIuiv: *const @TypeOf(getTexParameterIuiv),
    glGetTexParameterfv: *const @TypeOf(getTexParameterfv),
    glGetTexParameteriv: *const @TypeOf(getTexParameteriv),
    glGetTransformFeedbackVarying: *const @TypeOf(getTransformFeedbackVarying),
    glGetUniformBlockIndex: *const @TypeOf(getUniformBlockIndex),
    glGetUniformIndices: *const @TypeOf(getUniformIndices),
    glGetUniformLocation: *const @TypeOf(getUniformLocation),
    glGetUniformSubroutineuiv: *const @TypeOf(getUniformSubroutineuiv),
    glGetUniformdv: *const @TypeOf(getUniformdv),
    glGetUniformfv: *const @TypeOf(getUniformfv),
    glGetUniformiv: *const @TypeOf(getUniformiv),
    glGetUniformuiv: *const @TypeOf(getUniformuiv),
    glGetVertexAttribIiv: *const @TypeOf(getVertexAttribIiv),
    glGetVertexAttribIuiv: *const @TypeOf(getVertexAttribIuiv),
    glGetVertexAttribLdv: *const @TypeOf(getVertexAttribLdv),
    glGetVertexAttribPointerv: *const @TypeOf(getVertexAttribPointerv),
    glGetVertexAttribdv: *const @TypeOf(getVertexAttribdv),
    glGetVertexAttribfv: *const @TypeOf(getVertexAttribfv),
    glGetVertexAttribiv: *const @TypeOf(getVertexAttribiv),
    glHint: *const @TypeOf(hint),
    glIsBuffer: *const @TypeOf(isBuffer),
    glIsEnabled: *const @TypeOf(isEnabled),
    glIsEnabledi: *const @TypeOf(isEnabledi),
    glIsFramebuffer: *const @TypeOf(isFramebuffer),
    glIsProgram: *const @TypeOf(isProgram),
    glIsProgramPipeline: *const @TypeOf(isProgramPipeline),
    glIsQuery: *const @TypeOf(isQuery),
    glIsRenderbuffer: *const @TypeOf(isRenderbuffer),
    glIsSampler: *const @TypeOf(isSampler),
    glIsShader: *const @TypeOf(isShader),
    glIsSync: *const @TypeOf(isSync),
    glIsTexture: *const @TypeOf(isTexture),
    glIsTransformFeedback: *const @TypeOf(isTransformFeedback),
    glIsVertexArray: *const @TypeOf(isVertexArray),
    glLineWidth: *const @TypeOf(lineWidth),
    glLinkProgram: *const @TypeOf(linkProgram),
    glLogicOp: *const @TypeOf(logicOp),
    glMapBuffer: *const @TypeOf(mapBuffer),
    glMapBufferRange: *const @TypeOf(mapBufferRange),
    glMinSampleShading: *const @TypeOf(minSampleShading),
    glMultiDrawArrays: *const @TypeOf(multiDrawArrays),
    glMultiDrawElements: *const @TypeOf(multiDrawElements),
    glMultiDrawElementsBaseVertex: *const @TypeOf(multiDrawElementsBaseVertex),
    glPatchParameterfv: *const @TypeOf(patchParameterfv),
    glPatchParameteri: *const @TypeOf(patchParameteri),
    glPauseTransformFeedback: *const @TypeOf(pauseTransformFeedback),
    glPixelStoref: *const @TypeOf(pixelStoref),
    glPixelStorei: *const @TypeOf(pixelStorei),
    glPointParameterf: *const @TypeOf(pointParameterf),
    glPointParameterfv: *const @TypeOf(pointParameterfv),
    glPointParameteri: *const @TypeOf(pointParameteri),
    glPointParameteriv: *const @TypeOf(pointParameteriv),
    glPointSize: *const @TypeOf(pointSize),
    glPolygonMode: *const @TypeOf(polygonMode),
    glPolygonOffset: *const @TypeOf(polygonOffset),
    glPrimitiveRestartIndex: *const @TypeOf(primitiveRestartIndex),
    glProgramBinary: *const @TypeOf(programBinary),
    glProgramParameteri: *const @TypeOf(programParameteri),
    glProgramUniform1d: *const @TypeOf(programUniform1d),
    glProgramUniform1dv: *const @TypeOf(programUniform1dv),
    glProgramUniform1f: *const @TypeOf(programUniform1f),
    glProgramUniform1fv: *const @TypeOf(programUniform1fv),
    glProgramUniform1i: *const @TypeOf(programUniform1i),
    glProgramUniform1iv: *const @TypeOf(programUniform1iv),
    glProgramUniform1ui: *const @TypeOf(programUniform1ui),
    glProgramUniform1uiv: *const @TypeOf(programUniform1uiv),
    glProgramUniform2d: *const @TypeOf(programUniform2d),
    glProgramUniform2dv: *const @TypeOf(programUniform2dv),
    glProgramUniform2f: *const @TypeOf(programUniform2f),
    glProgramUniform2fv: *const @TypeOf(programUniform2fv),
    glProgramUniform2i: *const @TypeOf(programUniform2i),
    glProgramUniform2iv: *const @TypeOf(programUniform2iv),
    glProgramUniform2ui: *const @TypeOf(programUniform2ui),
    glProgramUniform2uiv: *const @TypeOf(programUniform2uiv),
    glProgramUniform3d: *const @TypeOf(programUniform3d),
    glProgramUniform3dv: *const @TypeOf(programUniform3dv),
    glProgramUniform3f: *const @TypeOf(programUniform3f),
    glProgramUniform3fv: *const @TypeOf(programUniform3fv),
    glProgramUniform3i: *const @TypeOf(programUniform3i),
    glProgramUniform3iv: *const @TypeOf(programUniform3iv),
    glProgramUniform3ui: *const @TypeOf(programUniform3ui),
    glProgramUniform3uiv: *const @TypeOf(programUniform3uiv),
    glProgramUniform4d: *const @TypeOf(programUniform4d),
    glProgramUniform4dv: *const @TypeOf(programUniform4dv),
    glProgramUniform4f: *const @TypeOf(programUniform4f),
    glProgramUniform4fv: *const @TypeOf(programUniform4fv),
    glProgramUniform4i: *const @TypeOf(programUniform4i),
    glProgramUniform4iv: *const @TypeOf(programUniform4iv),
    glProgramUniform4ui: *const @TypeOf(programUniform4ui),
    glProgramUniform4uiv: *const @TypeOf(programUniform4uiv),
    glProgramUniformMatrix2dv: *const @TypeOf(programUniformMatrix2dv),
    glProgramUniformMatrix2fv: *const @TypeOf(programUniformMatrix2fv),
    glProgramUniformMatrix2x3dv: *const @TypeOf(programUniformMatrix2x3dv),
    glProgramUniformMatrix2x3fv: *const @TypeOf(programUniformMatrix2x3fv),
    glProgramUniformMatrix2x4dv: *const @TypeOf(programUniformMatrix2x4dv),
    glProgramUniformMatrix2x4fv: *const @TypeOf(programUniformMatrix2x4fv),
    glProgramUniformMatrix3dv: *const @TypeOf(programUniformMatrix3dv),
    glProgramUniformMatrix3fv: *const @TypeOf(programUniformMatrix3fv),
    glProgramUniformMatrix3x2dv: *const @TypeOf(programUniformMatrix3x2dv),
    glProgramUniformMatrix3x2fv: *const @TypeOf(programUniformMatrix3x2fv),
    glProgramUniformMatrix3x4dv: *const @TypeOf(programUniformMatrix3x4dv),
    glProgramUniformMatrix3x4fv: *const @TypeOf(programUniformMatrix3x4fv),
    glProgramUniformMatrix4dv: *const @TypeOf(programUniformMatrix4dv),
    glProgramUniformMatrix4fv: *const @TypeOf(programUniformMatrix4fv),
    glProgramUniformMatrix4x2dv: *const @TypeOf(programUniformMatrix4x2dv),
    glProgramUniformMatrix4x2fv: *const @TypeOf(programUniformMatrix4x2fv),
    glProgramUniformMatrix4x3dv: *const @TypeOf(programUniformMatrix4x3dv),
    glProgramUniformMatrix4x3fv: *const @TypeOf(programUniformMatrix4x3fv),
    glProvokingVertex: *const @TypeOf(provokingVertex),
    glQueryCounter: *const @TypeOf(queryCounter),
    glReadBuffer: *const @TypeOf(readBuffer),
    glReadPixels: *const @TypeOf(readPixels),
    glReleaseShaderCompiler: *const @TypeOf(releaseShaderCompiler),
    glRenderbufferStorage: *const @TypeOf(renderbufferStorage),
    glRenderbufferStorageMultisample: *const @TypeOf(renderbufferStorageMultisample),
    glResumeTransformFeedback: *const @TypeOf(resumeTransformFeedback),
    glSampleCoverage: *const @TypeOf(sampleCoverage),
    glSampleMaski: *const @TypeOf(sampleMaski),
    glSamplerParameterIiv: *const @TypeOf(samplerParameterIiv),
    glSamplerParameterIuiv: *const @TypeOf(samplerParameterIuiv),
    glSamplerParameterf: *const @TypeOf(samplerParameterf),
    glSamplerParameterfv: *const @TypeOf(samplerParameterfv),
    glSamplerParameteri: *const @TypeOf(samplerParameteri),
    glSamplerParameteriv: *const @TypeOf(samplerParameteriv),
    glScissor: *const @TypeOf(scissor),
    glScissorArrayv: *const @TypeOf(scissorArrayv),
    glScissorIndexed: *const @TypeOf(scissorIndexed),
    glScissorIndexedv: *const @TypeOf(scissorIndexedv),
    glShaderBinary: *const @TypeOf(shaderBinary),
    glShaderSource: *const @TypeOf(shaderSource),
    glStencilFunc: *const @TypeOf(stencilFunc),
    glStencilFuncSeparate: *const @TypeOf(stencilFuncSeparate),
    glStencilMask: *const @TypeOf(stencilMask),
    glStencilMaskSeparate: *const @TypeOf(stencilMaskSeparate),
    glStencilOp: *const @TypeOf(stencilOp),
    glStencilOpSeparate: *const @TypeOf(stencilOpSeparate),
    glTexBuffer: *const @TypeOf(texBuffer),
    glTexImage1D: *const @TypeOf(texImage1D),
    glTexImage2D: *const @TypeOf(texImage2D),
    glTexImage2DMultisample: *const @TypeOf(texImage2DMultisample),
    glTexImage3D: *const @TypeOf(texImage3D),
    glTexImage3DMultisample: *const @TypeOf(texImage3DMultisample),
    glTexParameterIiv: *const @TypeOf(texParameterIiv),
    glTexParameterIuiv: *const @TypeOf(texParameterIuiv),
    glTexParameterf: *const @TypeOf(texParameterf),
    glTexParameterfv: *const @TypeOf(texParameterfv),
    glTexParameteri: *const @TypeOf(texParameteri),
    glTexParameteriv: *const @TypeOf(texParameteriv),
    glTexSubImage1D: *const @TypeOf(texSubImage1D),
    glTexSubImage2D: *const @TypeOf(texSubImage2D),
    glTexSubImage3D: *const @TypeOf(texSubImage3D),
    glTransformFeedbackVaryings: *const @TypeOf(transformFeedbackVaryings),
    glUniform1d: *const @TypeOf(uniform1d),
    glUniform1dv: *const @TypeOf(uniform1dv),
    glUniform1f: *const @TypeOf(uniform1f),
    glUniform1fv: *const @TypeOf(uniform1fv),
    glUniform1i: *const @TypeOf(uniform1i),
    glUniform1iv: *const @TypeOf(uniform1iv),
    glUniform1ui: *const @TypeOf(uniform1ui),
    glUniform1uiv: *const @TypeOf(uniform1uiv),
    glUniform2d: *const @TypeOf(uniform2d),
    glUniform2dv: *const @TypeOf(uniform2dv),
    glUniform2f: *const @TypeOf(uniform2f),
    glUniform2fv: *const @TypeOf(uniform2fv),
    glUniform2i: *const @TypeOf(uniform2i),
    glUniform2iv: *const @TypeOf(uniform2iv),
    glUniform2ui: *const @TypeOf(uniform2ui),
    glUniform2uiv: *const @TypeOf(uniform2uiv),
    glUniform3d: *const @TypeOf(uniform3d),
    glUniform3dv: *const @TypeOf(uniform3dv),
    glUniform3f: *const @TypeOf(uniform3f),
    glUniform3fv: *const @TypeOf(uniform3fv),
    glUniform3i: *const @TypeOf(uniform3i),
    glUniform3iv: *const @TypeOf(uniform3iv),
    glUniform3ui: *const @TypeOf(uniform3ui),
    glUniform3uiv: *const @TypeOf(uniform3uiv),
    glUniform4d: *const @TypeOf(uniform4d),
    glUniform4dv: *const @TypeOf(uniform4dv),
    glUniform4f: *const @TypeOf(uniform4f),
    glUniform4fv: *const @TypeOf(uniform4fv),
    glUniform4i: *const @TypeOf(uniform4i),
    glUniform4iv: *const @TypeOf(uniform4iv),
    glUniform4ui: *const @TypeOf(uniform4ui),
    glUniform4uiv: *const @TypeOf(uniform4uiv),
    glUniformBlockBinding: *const @TypeOf(uniformBlockBinding),
    glUniformMatrix2dv: *const @TypeOf(uniformMatrix2dv),
    glUniformMatrix2fv: *const @TypeOf(uniformMatrix2fv),
    glUniformMatrix2x3dv: *const @TypeOf(uniformMatrix2x3dv),
    glUniformMatrix2x3fv: *const @TypeOf(uniformMatrix2x3fv),
    glUniformMatrix2x4dv: *const @TypeOf(uniformMatrix2x4dv),
    glUniformMatrix2x4fv: *const @TypeOf(uniformMatrix2x4fv),
    glUniformMatrix3dv: *const @TypeOf(uniformMatrix3dv),
    glUniformMatrix3fv: *const @TypeOf(uniformMatrix3fv),
    glUniformMatrix3x2dv: *const @TypeOf(uniformMatrix3x2dv),
    glUniformMatrix3x2fv: *const @TypeOf(uniformMatrix3x2fv),
    glUniformMatrix3x4dv: *const @TypeOf(uniformMatrix3x4dv),
    glUniformMatrix3x4fv: *const @TypeOf(uniformMatrix3x4fv),
    glUniformMatrix4dv: *const @TypeOf(uniformMatrix4dv),
    glUniformMatrix4fv: *const @TypeOf(uniformMatrix4fv),
    glUniformMatrix4x2dv: *const @TypeOf(uniformMatrix4x2dv),
    glUniformMatrix4x2fv: *const @TypeOf(uniformMatrix4x2fv),
    glUniformMatrix4x3dv: *const @TypeOf(uniformMatrix4x3dv),
    glUniformMatrix4x3fv: *const @TypeOf(uniformMatrix4x3fv),
    glUniformSubroutinesuiv: *const @TypeOf(uniformSubroutinesuiv),
    glUnmapBuffer: *const @TypeOf(unmapBuffer),
    glUseProgram: *const @TypeOf(useProgram),
    glUseProgramStages: *const @TypeOf(useProgramStages),
    glValidateProgram: *const @TypeOf(validateProgram),
    glValidateProgramPipeline: *const @TypeOf(validateProgramPipeline),
    glVertexAttrib1d: *const @TypeOf(vertexAttrib1d),
    glVertexAttrib1dv: *const @TypeOf(vertexAttrib1dv),
    glVertexAttrib1f: *const @TypeOf(vertexAttrib1f),
    glVertexAttrib1fv: *const @TypeOf(vertexAttrib1fv),
    glVertexAttrib1s: *const @TypeOf(vertexAttrib1s),
    glVertexAttrib1sv: *const @TypeOf(vertexAttrib1sv),
    glVertexAttrib2d: *const @TypeOf(vertexAttrib2d),
    glVertexAttrib2dv: *const @TypeOf(vertexAttrib2dv),
    glVertexAttrib2f: *const @TypeOf(vertexAttrib2f),
    glVertexAttrib2fv: *const @TypeOf(vertexAttrib2fv),
    glVertexAttrib2s: *const @TypeOf(vertexAttrib2s),
    glVertexAttrib2sv: *const @TypeOf(vertexAttrib2sv),
    glVertexAttrib3d: *const @TypeOf(vertexAttrib3d),
    glVertexAttrib3dv: *const @TypeOf(vertexAttrib3dv),
    glVertexAttrib3f: *const @TypeOf(vertexAttrib3f),
    glVertexAttrib3fv: *const @TypeOf(vertexAttrib3fv),
    glVertexAttrib3s: *const @TypeOf(vertexAttrib3s),
    glVertexAttrib3sv: *const @TypeOf(vertexAttrib3sv),
    glVertexAttrib4Nbv: *const @TypeOf(vertexAttrib4Nbv),
    glVertexAttrib4Niv: *const @TypeOf(vertexAttrib4Niv),
    glVertexAttrib4Nsv: *const @TypeOf(vertexAttrib4Nsv),
    glVertexAttrib4Nub: *const @TypeOf(vertexAttrib4Nub),
    glVertexAttrib4Nubv: *const @TypeOf(vertexAttrib4Nubv),
    glVertexAttrib4Nuiv: *const @TypeOf(vertexAttrib4Nuiv),
    glVertexAttrib4Nusv: *const @TypeOf(vertexAttrib4Nusv),
    glVertexAttrib4bv: *const @TypeOf(vertexAttrib4bv),
    glVertexAttrib4d: *const @TypeOf(vertexAttrib4d),
    glVertexAttrib4dv: *const @TypeOf(vertexAttrib4dv),
    glVertexAttrib4f: *const @TypeOf(vertexAttrib4f),
    glVertexAttrib4fv: *const @TypeOf(vertexAttrib4fv),
    glVertexAttrib4iv: *const @TypeOf(vertexAttrib4iv),
    glVertexAttrib4s: *const @TypeOf(vertexAttrib4s),
    glVertexAttrib4sv: *const @TypeOf(vertexAttrib4sv),
    glVertexAttrib4ubv: *const @TypeOf(vertexAttrib4ubv),
    glVertexAttrib4uiv: *const @TypeOf(vertexAttrib4uiv),
    glVertexAttrib4usv: *const @TypeOf(vertexAttrib4usv),
    glVertexAttribDivisor: *const @TypeOf(vertexAttribDivisor),
    glVertexAttribI1i: *const @TypeOf(vertexAttribI1i),
    glVertexAttribI1iv: *const @TypeOf(vertexAttribI1iv),
    glVertexAttribI1ui: *const @TypeOf(vertexAttribI1ui),
    glVertexAttribI1uiv: *const @TypeOf(vertexAttribI1uiv),
    glVertexAttribI2i: *const @TypeOf(vertexAttribI2i),
    glVertexAttribI2iv: *const @TypeOf(vertexAttribI2iv),
    glVertexAttribI2ui: *const @TypeOf(vertexAttribI2ui),
    glVertexAttribI2uiv: *const @TypeOf(vertexAttribI2uiv),
    glVertexAttribI3i: *const @TypeOf(vertexAttribI3i),
    glVertexAttribI3iv: *const @TypeOf(vertexAttribI3iv),
    glVertexAttribI3ui: *const @TypeOf(vertexAttribI3ui),
    glVertexAttribI3uiv: *const @TypeOf(vertexAttribI3uiv),
    glVertexAttribI4bv: *const @TypeOf(vertexAttribI4bv),
    glVertexAttribI4i: *const @TypeOf(vertexAttribI4i),
    glVertexAttribI4iv: *const @TypeOf(vertexAttribI4iv),
    glVertexAttribI4sv: *const @TypeOf(vertexAttribI4sv),
    glVertexAttribI4ubv: *const @TypeOf(vertexAttribI4ubv),
    glVertexAttribI4ui: *const @TypeOf(vertexAttribI4ui),
    glVertexAttribI4uiv: *const @TypeOf(vertexAttribI4uiv),
    glVertexAttribI4usv: *const @TypeOf(vertexAttribI4usv),
    glVertexAttribIPointer: *const @TypeOf(vertexAttribIPointer),
    glVertexAttribL1d: *const @TypeOf(vertexAttribL1d),
    glVertexAttribL1dv: *const @TypeOf(vertexAttribL1dv),
    glVertexAttribL2d: *const @TypeOf(vertexAttribL2d),
    glVertexAttribL2dv: *const @TypeOf(vertexAttribL2dv),
    glVertexAttribL3d: *const @TypeOf(vertexAttribL3d),
    glVertexAttribL3dv: *const @TypeOf(vertexAttribL3dv),
    glVertexAttribL4d: *const @TypeOf(vertexAttribL4d),
    glVertexAttribL4dv: *const @TypeOf(vertexAttribL4dv),
    glVertexAttribLPointer: *const @TypeOf(vertexAttribLPointer),
    glVertexAttribP1ui: *const @TypeOf(vertexAttribP1ui),
    glVertexAttribP1uiv: *const @TypeOf(vertexAttribP1uiv),
    glVertexAttribP2ui: *const @TypeOf(vertexAttribP2ui),
    glVertexAttribP2uiv: *const @TypeOf(vertexAttribP2uiv),
    glVertexAttribP3ui: *const @TypeOf(vertexAttribP3ui),
    glVertexAttribP3uiv: *const @TypeOf(vertexAttribP3uiv),
    glVertexAttribP4ui: *const @TypeOf(vertexAttribP4ui),
    glVertexAttribP4uiv: *const @TypeOf(vertexAttribP4uiv),
    glVertexAttribPointer: *const @TypeOf(vertexAttribPointer),
    glViewport: *const @TypeOf(viewport),
    glViewportArrayv: *const @TypeOf(viewportArrayv),
    glViewportIndexedf: *const @TypeOf(viewportIndexedf),
    glViewportIndexedfv: *const @TypeOf(viewportIndexedfv),
    glWaitSync: *const @TypeOf(waitSync),
    //#endregion Fields

    /// Initializes the specified dispatch table. Returns `true` if successful, `false` otherwise.
    ///
    /// This function must be called successfully before passing the dispatch table to
    /// `makeDispatchTableCurrent()`, `invoke()`, `invokeIntercepted()` or accessing any of its
    /// fields.
    ///
    /// `loader` is duck-typed and can be either a container or an instance, so long as it satisfies
    /// the following code:
    ///
    /// ```
    /// const prefixed_command_name: [:0]const u8 = "glExample";
    /// const AnyCFnPtr = *align(@alignOf(fn () callconv(.C) void)) const anyopaque;
    /// const fn_ptr_opt: ?AnyCFnPtr = loader.GetCommandFnPtr(prefixed_command_name);
    /// _ = fn_ptr_opt;
    /// ```
    ///
    /// No references to `loader` are retained after this function returns. There is no
    /// corresponding `deinit()` function.
    pub fn init(self: *DispatchTable, loader: anytype) bool {
        @setEvalBranchQuota(1_000_000);
        var success: u1 = 1;
        inline for (@typeInfo(DispatchTable).Struct.fields) |field_info| {
            const prefixed_feature_name = comptime nullTerminate(field_info.name);
            switch (@typeInfo(field_info.type)) {
                .Pointer => |ptr_info| switch (@typeInfo(ptr_info.child)) {
                    .Fn => success &= @intFromBool(self.load(loader, prefixed_feature_name)),
                    else => comptime unreachable,
                },
                else => comptime unreachable,
            }
        }
        return success != 0;
    }

    fn nullTerminate(comptime string: []const u8) [:0]const u8 {
        comptime {
            var buf: [string.len + 1]u8 = undefined;
            std.mem.copy(u8, &buf, string);
            buf[string.len] = 0;
            return buf[0..string.len :0];
        }
    }

    fn load(
        self: *DispatchTable,
        loader: anytype,
        comptime prefixed_command_name: [:0]const u8,
    ) bool {
        const FieldType = @TypeOf(@field(self, prefixed_command_name));
        const AnyCFnPtr = *align(@alignOf(fn () callconv(.C) void)) const anyopaque;
        const fn_ptr_opt: ?AnyCFnPtr = loader.getCommandFnPtr(prefixed_command_name);
        if (fn_ptr_opt) |fn_ptr| {
            @field(self, prefixed_command_name) = @ptrCast(fn_ptr);
            return true;
        } else {
            return @typeInfo(FieldType) == .Optional;
        }
    }

    /// Invokes the specified OpenGL command with the specified arguments. The invocation will not
    /// be intercepted.
    pub fn invoke(
        self: *const DispatchTable,
        comptime prefixed_command_name: [:0]const u8,
        args: anytype,
    ) ReturnType(prefixed_command_name) {
        const FieldType = @TypeOf(@field(self, prefixed_command_name));
        return if (@typeInfo(FieldType) == .Optional)
            @call(.auto, @field(self, prefixed_command_name).?, args)
        else
            @call(.auto, @field(self, prefixed_command_name), args);
    }

    /// Invokes the specified OpenGL command with the specified arguments. The invocation will be
    /// intercepted by `options.intercept()`.
    pub fn invokeIntercepted(
        self: *const DispatchTable,
        comptime prefixed_command_name: [:0]const u8,
        args: anytype,
    ) ReturnType(prefixed_command_name) {
        return options.intercept(self, prefixed_command_name, args);
    }

    pub fn ReturnType(comptime prefixed_command_name: [:0]const u8) type {
        const FieldType = @TypeOf(@field(@as(DispatchTable, undefined), prefixed_command_name));
        if (@hasField(DispatchTable, prefixed_command_name)) {
            switch (@typeInfo(FieldType)) {
                .Pointer => |ptr_info| switch (@typeInfo(ptr_info.child)) {
                    .Fn => |fn_info| return fn_info.return_type.?,
                    else => comptime unreachable,
                },
                .Bool => {},
                .Optional => |opt_info| switch (@typeInfo(opt_info.child)) {
                    .Pointer => |ptr_info| switch (@typeInfo(ptr_info.child)) {
                        .Fn => |fn_info| return fn_info.return_type.?,
                        else => comptime unreachable,
                    },
                    else => comptime unreachable,
                },
                else => comptime unreachable,
            }
        }
        @compileError("unknown command: '" ++ prefixed_command_name ++ "'");
    }
};

/// Options that can be overriden by publicly declaring a container named `gl_options` in the root
/// source file.
pub const options = struct {
    /// Intercepts OpenGL command invocations.
    pub const intercept: @TypeOf(struct {
        fn intercept(
            dispatch_table: *const DispatchTable,
            comptime prefixed_command_name: [:0]const u8,
            args: anytype,
        ) DispatchTable.ReturnType(prefixed_command_name) {
            _ = args;
            _ = dispatch_table;
            comptime unreachable;
        }
    }.intercept) = if (@hasDecl(options_overrides, "intercept"))
        options_overrides.intercept
    else
        DispatchTable.invoke;
};

const options_overrides = if (@hasDecl(root, "gl_options")) root.gl_options else struct {};

comptime {
    for (@typeInfo(options_overrides).Struct.decls) |decl| {
        if (!@hasDecl(options, decl.name)) @compileError("unknown option: '" ++ decl.name ++ "'");
    }
}

test {
    @setEvalBranchQuota(1_000_000);
    std.testing.refAllDeclsRecursive(@This());
}
