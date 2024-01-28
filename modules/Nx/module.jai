// Bindings for libnx, devkitPro's  Switch homebrew userland support library.
// This file contains all the bindings that had to be manually written - mainly for inline functions and such.

// Load the file that contains all the stuff Bindings_Generator was able to do.
// It won't be able to work on its own without the stuff in this file.
#load "autogen.jai";

#import "Bitfields";
#import "POSIX";
#import "Socket";

__uintptr_t :: u64;

__clock_t     :: clock_t;
__time_t      :: time_t;
__clockid_t   :: clockid_t;
__daddr_t     :: s64;
__timer_t     :: u64;

BIT :: (x: $T) -> T {
    return (cast(T)1) << x;
}

/// Checks whether a result code indicates success.
R_SUCCEEDED   :: inline (res: Result) -> bool { return res == 0; }
/// Checks whether a result code indicates failure.
R_FAILED      :: inline (res: Result) -> bool { return res != 0; }
/// Returns the module ID of a result code.
R_MODULE      :: inline (res: Result) -> bool { return (res & 0x1FF) != 0; }
/// Returns the description of a result code.
R_DESCRIPTION :: inline (res: Result) -> bool { return ((res >> 9) & 0x1FFF) != 0; }
/// Masks out unused bits in a result code, retrieving the actual value for use in comparisons.
R_VALUE       :: inline (res: Result) -> bool { return (res & 0x3FFFFF) != 0; }

/// Builds a result code from its constituent components.
MAKERESULT :: inline (module: u32, description: u32) -> Result {
    return xx (module & 0x1FF) | (description & 0x1FFF) << 9;
}

/// Builds a kernel error result code.
// KERNELRESULT :: inline (description: Result) -> bool { return \; }
//     MAKERESULT(Module_Kernel, KernelError_##description)

/**
 * @brief Initializes a \ref PadState object to read input from one or more controller input sources.
 * @param[in] _pad Pointer to \ref PadState.
 * @remarks This is a variadic macro, pass the \ref HidNpadIdType value of each controller to add to the set.
 */
padInitialize :: inline (pad: *PadState, pad_ids: ..HidNpadIdType) {
    pad_mask: u64 = 0;
    for pad_ids {
        pad_mask |= (cast(u64)1) << it;
    }
    padInitializeWithMask(pad, pad_mask);
}

/**
 * @brief Same as \ref padInitialize, but including \ref HidNpadIdType_No1 and \ref HidNpadIdType_Handheld.
 * @param[in] pad Pointer to \ref PadState.
 * @remark Use this function if you just want to accept input for a single-player application.
 */
padInitializeDefault :: inline (pad: *PadState) {
    padInitialize(pad, .No1, .Handheld);
}

/**
 * @brief Retrieves whether \ref HidNpadIdType_Handheld is an active input source (i.e. it was possible to read from it).
 * @param[in] pad Pointer to \ref PadState.
 * @return Boolean value.
 * @remark \ref padUpdate must have been previously called.
 */
padIsHandheld :: inline (pad: PadState) -> bool {
    return pad.active_handheld;
}

/**
 * @brief Retrieves whether the specified controller is an active input source (i.e. it was possible to read from it).
 * @param[in] pad Pointer to \ref PadState.
 * @param[in] id ID of the controller input source (see \ref HidNpadIdType)
 * @return Boolean value.
 * @remark \ref padUpdate must have been previously called.
 */
padIsNpadActive :: inline (pad: PadState, id: HidNpadIdType) -> bool {
    if      id <= .No8       return pad.active_id_mask & BIT(id);
    else if id == .Handheld  return pad.active_handheld;
    else                     return false;
}

/**
 * @brief Retrieves the set of input styles supported by the selected controller input sources.
 * @param[in] pad Pointer to \ref PadState.
 * @return Bitfield of \ref HidNpadStyleTag.
 * @remark \ref padUpdate must have been previously called.
 */
padGetStyleSet :: inline (pad: PadState) -> u32 {
    return pad.style_set;
}

/**
 * @brief Retrieves the set of attributes reported by the system for the selected controller input sources.
 * @param[in] pad Pointer to \ref PadState.
 * @return Bitfield of \ref HidNpadAttribute.
 * @remark \ref padUpdate must have been previously called.
 */
padGetAttributes :: inline (pad: PadState) -> u32 {
    return pad.attributes;
}

/**
 * @brief Retrieves whether any of the selected controller input sources is connected.
 * @param[in] pad Pointer to \ref PadState.
 * @return Boolean value.
 * @remark \ref padUpdate must have been previously called.
 */
padIsConnected :: inline (pad: PadState) -> bool {
    return pad.attributes & HidNpadAttribute_IsConnected;
}

/**
 * @brief Retrieves the current set of pressed buttons across all selected controller input sources.
 * @param[in] pad Pointer to \ref PadState.
 * @return Bitfield of \ref HidNpadButton.
 * @remark \ref padUpdate must have been previously called.
 */
padGetButtons :: inline (pad: PadState) -> HidNpadButton {
    return xx pad.buttons_cur;
}

/**
 * @brief Retrieves the set of buttons that are newly pressed.
 * @param[in] pad Pointer to \ref PadState.
 * @return Bitfield of \ref HidNpadButton.
 * @remark \ref padUpdate must have been previously called.
 */
padGetButtonsDown :: inline (pad: PadState) -> HidNpadButton {
    return xx ~pad.buttons_old & pad.buttons_cur;
}

/**
 * @brief Retrieves the set of buttons that are newly released.
 * @param[in] pad Pointer to \ref PadState.
 * @return Bitfield of \ref HidNpadButton.
 * @remark \ref padUpdate must have been previously called.
 */
padGetButtonsUp :: inline (pad: PadState) -> HidNpadButton {
    return xx pad.buttons_old & ~pad.buttons_cur;
}

/**
 * @brief Retrieves the position of an analog stick in a controller.
 * @param[in] pad Pointer to \ref PadState.
 * @param[in] i ID of the analog stick to read (0=left, 1=right).
 * @return \ref HidAnalogStickState.
 * @remark \ref padUpdate must have been previously called.
 */
padGetStickPos :: inline (pad: PadState, i: s64) -> HidAnalogStickState {
    return pad.sticks[i];
}

/**
 * @brief Retrieves the position of an analog trigger in a GameCube controller.
 * @param[in] pad Pointer to \ref PadState.
 * @param[in] i ID of the analog trigger to read (0=left, 1=right).
 * @return Analog trigger position (range is 0 to 0x7fff).
 * @remark \ref padUpdate must have been previously called.
 * @remark \ref HidNpadStyleTag_NpadGc must have been previously configured as a supported style in \ref padConfigureInput for GC trigger data to be readable.
 */
padGetGcTriggerPos :: inline (pad: PadState, i: s64) -> u32 {
    return pad.gc_triggers[i];
}

/**
 * @brief Initializes a \ref PadRepeater object with the specified settings.
 * @param[in] r Pointer to \ref PadRepeater.
 * @param[in] delay Number of input updates between button presses being first detected and them being considered for repeat.
 * @param[in] repeat Number of input updates between autogenerated repeat button presses.
 */
padRepeaterInitialize :: inline (r: *PadRepeater, delay: u16, repeat: u16) {
    r.button_mask = 0;
    r.counter = 0;
    r.delay = delay;
    r.repeat = repeat;
}

/**
 * @brief Retrieves the set of buttons that are being repeated according to the parameters specified in \ref padRepeaterInitialize.
 * @param[in] r Pointer to \ref PadRepeater.
 * @return Bitfield of \ref HidNpadButton.
 * @remark It is suggested to bitwise-OR the return value of this function with that of \ref padGetButtonsDown.
 */
padRepeaterGetButtons :: inline (r: PadRepeater) -> HidNpadButton {
    return ifx r.counter == 0 then xx r.button_mask else 0;
}

/// Retrieves a pointer to temporary stage for reading entries
fsdevDirGetEntries :: inline (dir: *fsdev_dir_t) -> *FsDirectoryEntry
{
    return cast(*FsDirectoryEntry)cast(*void)(dir+1);
}

/// Wrapper for \ref sslConnectionSetDtlsSocketDescriptor. Returns the output sockfd on success and -1 on error. errno==ENOENT indicates that no sockfd was returned, this error must be ignored.
socketSslConnectionSetDtlsSocketDescriptor :: (c: *SslConnection, sockfd: s32, addr: *sockaddr, addrlen: socklen_t) -> s32 #foreign libnx;

/// Wrapper for \ref romfsMountSelf with the default "romfs" device name.
romfsInit :: inline () -> Result {
    return romfsMountSelf("romfs");
}

/// Wrapper for \ref romfsUnmount with the default "romfs" device name.
romfsExit :: inline () -> Result {
    return romfsUnmount("romfs");
}

nvMultiFenceCreate :: inline (mf: *NvMultiFence, fence: *NvFence) {
    mf.num_fences = 1;
    mf.fences[0] = fence.*;
}

nvGpuChannelGetSyncpointId :: inline (c: NvGpuChannel) -> u32 {
    return c.fence.id;
}

nvGpuChannelGetFence :: inline (c: *NvGpuChannel, fence_out: *NvFence) {
    fence_out.id = c.fence.id;
    fence_out.value = c.fence.value + c.fence_incr;
}

nvGpuChannelIncrFence :: inline (c: *NvGpuChannel) {
    c.fence_incr += 1;
}

nvMapGetHandle :: inline (m: NvMap) -> u32 {
    return m.handle;
}

nvMapGetId :: inline (m: NvMap) -> u32 {
    return m.id;
}

nvMapGetSize :: inline (m: NvMap) -> u32 {
    return m.size;
}

nvMapGetCpuAddr :: inline (m: NvMap) -> *void {
    return m.cpu_addr;
}

nvMapIsRemote :: inline (m: NvMap) -> bool {
    return !m.cpu_addr;
}

nvMapGetKind :: inline (m: NvMap) -> NvKind {
    return m.kind;
}

/** hipc.h **/

hipcMakeSendStatic :: inline (buffer: [] void, index: u8) -> HipcStaticDescriptor
{
    return HipcStaticDescriptor.{
        index        = index,
        address_high = cast(u32)(cast(uintptr_t)buffer.data >> 36),
        address_mid  = cast(u32)(cast(uintptr_t)buffer.data >> 32),
        size         = cast(u32)buffer.count,
        address_low  = cast(u32)cast(uintptr_t)buffer.data,
    };
}

hipcMakeBuffer :: inline (buffer: [] void, mode: HipcBufferMode) -> HipcBufferDescriptor
{
    return HipcBufferDescriptor.{
        size_low     = cast(u32)buffer.count,
        address_low  = cast(u32)cast(uintptr_t)buffer.data,
        mode         = mode,
        address_high = cast(u32)(cast(uintptr_t)buffer.data >> 36),
        size_high    = cast(u32)(size >> 32),
        address_mid  = cast(u32)(cast(uintptr_t)buffer.data >> 32),
    };
}

hipcMakeRecvStatic :: inline (buffer: [] void) -> HipcRecvListEntry
{
    return HipcRecvListEntry.{
        address_low  = cast(u32)(cast(uintptr_t)buffer.data),
        address_high = cast(u32)(cast(uintptr_t)buffer.data >> 32),
        size         = cast(u32)buffer.count,
    };
}

hipcGetStaticAddress :: inline (desc: HipcStaticDescriptor) -> *void {
    return cast(*void)(desc.address_low | ((cast(uintptr_t)desc.address_mid) << 32) | ((cast(uintptr_t)desc.address_high) << 36));
}

hipcGetStaticSize :: inline (desc: HipcStaticDescriptor) -> size_t {
    return desc.size;
}

hipcGetBufferAddress :: inline (desc: HipcBufferDescriptor) -> *void {
    return cast(*void)(desc.address_low | ((cast(uintptr_t)desc.address_mid) << 32) | ((cast(uintptr_t)desc.address_high) << 36));
}

hipcGetBufferSize :: inline (desc: HipcBufferDescriptor) -> size_t {
    return desc.size_low | ((cast(size_t)desc.size_high) << 32);
}

hipcCalcRequestLayout :: (meta: HipcMetadata, base: *void) -> HipcRequest {
    // Copy handles
    copy_handles: *Handle;
    if meta.num_copy_handles {
        copy_handles = xx base;
        base = copy_handles + meta.num_copy_handles;
    }

    // Move handles
    move_handles: *Handle;
    if meta.num_move_handles {
        move_handles = xx base;
        base = move_handles + meta.num_move_handles;
    }

    // Send statics
    send_statics: *HipcStaticDescriptor;
    if meta.num_send_statics {
        send_statics = xx base;
        base = send_statics + meta.num_send_statics;
    }

    // Send buffers
    send_buffers: *HipcBufferDescriptor;
    if meta.num_send_buffers {
        send_buffers = xx base;
        base = send_buffers + meta.num_send_buffers;
    }

    // Recv buffers
    recv_buffers: *HipcBufferDescriptor;
    if meta.num_recv_buffers {
        recv_buffers = xx base;
        base = recv_buffers + meta.num_recv_buffers;
    }

    // Exch buffers
    exch_buffers: *HipcBufferDescriptor;
    if meta.num_exch_buffers {
        exch_buffers = xx base;
        base = exch_buffers + meta.num_exch_buffers;
    }

    // Data words
    data_words: *u32;
    if meta.num_data_words {
        data_words = xx base;
        base = data_words + meta.num_data_words;
    }

    // Recv list
    recv_list: *HipcRecvListEntry;
    if meta.num_recv_statics  recv_list = xx base;

    return HipcRequest.{
        send_statics = send_statics,
        send_buffers = send_buffers,
        recv_buffers = recv_buffers,
        exch_buffers = exch_buffers,
        data_words   = data_words,
        recv_list    = recv_list,
        copy_handles = copy_handles,
        move_handles = move_handles,
    };
}

hipcMakeRequest :: (base: *void, meta: HipcMetadata) -> HipcRequest {
    // Write message header
    has_special_header := meta.send_pid || meta.num_copy_handles || meta.num_move_handles;
    hdr: *HipcHeader = xx base;
    base = hdr+1;
    *hdr = HipcHeader.{
        type = meta.type,
        num_send_statics   = meta.num_send_statics,
        num_send_buffers   = meta.num_send_buffers,
        num_recv_buffers   = meta.num_recv_buffers,
        num_exch_buffers   = meta.num_exch_buffers,
        num_data_words     = meta.num_data_words,
        recv_static_mode   = ifx meta.num_recv_statics then (ifx meta.num_recv_statics != HIPC_AUTO_RECV_STATIC then 2 + meta.num_recv_statics else 2) else 0,
        padding            = 0,
        recv_list_offset   = 0,
        has_special_header = has_special_header,
    };

    // Write special header
    if has_special_header {
        sphdr: *HipcSpecialHeader = xx base;
        base = sphdr+1;
        *sphdr = HipcSpecialHeader.{
            send_pid         = meta.send_pid,
            num_copy_handles = meta.num_copy_handles,
            num_move_handles = meta.num_move_handles,
        };
        if meta.send_pid  base = (cast(*u8)base) + size_of(u64);
    }

    // Calculate layout
    return hipcCalcRequestLayout(meta, base);
}

hipcMakeRequestInline :: inline (
    base: *void,

    // Mirroring HipcMetadata
    type:             u32,
    num_send_statics: u32,
    num_send_buffers: u32,
    num_recv_buffers: u32,
    num_exch_buffers: u32,
    num_data_words:   u32,
    num_recv_statics: u32, // also accepts HIPC_AUTO_RECV_STATIC
    send_pid:         u32,
    num_copy_handles: u32,
    num_move_handles: u32
) -> HipcRequest {
    return hipcMakeRequest(
        base,
        HipcMetadata.{
            type             = type,
            num_send_statics = num_send_statics,
            num_send_buffers = num_send_buffers,
            num_recv_buffers = num_recv_buffers,
            num_exch_buffers = num_exch_buffers,
            num_data_words   = num_data_words,
            num_recv_statics = num_recv_statics,
            send_pid         = send_pid,
            num_copy_handles = num_copy_handles,
            num_move_handles = num_move_handles,
        },
    );
}

hipcParseRequest :: (base: *void) -> HipcParsedRequest {
    // Parse message header
    hdr: HipcHeader;
    memcpy(*hdr, base, size_of(hdr));
    base = (cast(*u8)base) + size_of(hdr);
    num_recv_statics: u32 = 0;
    pid: u64 = 0;

    // Parse recv static mode
    if hdr.recv_static_mode {
        if      hdr.recv_static_mode == 2  num_recv_statics = HIPC_AUTO_RECV_STATIC;
        else if hdr.recv_static_mode >  2  num_recv_statics = hdr.recv_static_mode - 2;
    }

    // Parse special header
    sphdr: HipcSpecialHeader;
    if hdr.has_special_header {
        memcpy(*sphdr, base, size_of(sphdr));
        base = (cast(*u8)base) + size_of(sphdr);

        // Read PID descriptor
        if sphdr.send_pid {
            pid = (cast(*u64)base).*;
            base = (cast(*u8)base) + size_of(u64);
        }
    }

    meta := HipcMetadata.{
        type             = hdr.type,
        num_send_statics = hdr.num_send_statics,
        num_send_buffers = hdr.num_send_buffers,
        num_recv_buffers = hdr.num_recv_buffers,
        num_exch_buffers = hdr.num_exch_buffers,
        num_data_words   = hdr.num_data_words,
        num_recv_statics = num_recv_statics,
        send_pid         = sphdr.send_pid,
        num_copy_handles = sphdr.num_copy_handles,
        num_move_handles = sphdr.num_move_handles,
    };

    return HipcParsedRequest.{
        meta = meta,
        data = hipcCalcRequestLayout(meta, base),
        pid  = pid,
    };
}

hipcParseResponse :: (base: *void) -> HipcResponse {
    // Parse header
    hdr: HipcHeader;
    memcpy(*hdr, base, size_of(hdr));
    base = (cast(*u8)base) + size_of(hdr);

    // Initialize response
    response: HipcResponse;
    response.num_statics = hdr.num_send_statics;
    response.num_data_words = hdr.num_data_words;
    response.pid = HIPC_RESPONSE_NO_PID;

    // Parse special header
    if hdr.has_special_header {
        sphdr: HipcSpecialHeader;
        memcpy(*sphdr, base, size_of(sphdr));
        base = (cast(*u8)base) + size_of(sphdr);

        // Update response
        response.num_copy_handles = sphdr.num_copy_handles;
        response.num_move_handles = sphdr.num_move_handles;

        // Parse PID descriptor
        if sphdr.send_pid {
            response.pid = (cast(*u64)base).*;
            base = (cast(*u8)base) + size_of(u64);
        }
    }

    // Copy handles
    response.copy_handles = xx base;
    base = response.copy_handles + response.num_copy_handles;

    // Move handles
    response.move_handles = xx base;
    base = response.move_handles + response.num_move_handles;

    // Send statics
    response.statics = xx base;
    base = response.statics + response.num_statics;

    // Data words
    response.data_words = xx base;

    return response;
}

/** tipc.h **/

/**
 * @brief Creates a tipc service object from an IPC session handle.
 * @param[out] s TIPC service object.
 * @param[in] h IPC session handle.
 */
tipcCreate :: inline (s: *TipcService, h: Handle) {
    s.session = h;
}

/**
 * @brief Closes a tipc service.
 * @param[in] s TIPC service object.
 */
tipcClose :: inline (s: *TipcService) {
    hipcMakeRequestInline(armGetTls(), type = TipcCommandType_Close);
    svcSendSyncRequest(s.session);
    svcCloseHandle(s.session);
    s.* = TipcService.{};
}

tipcRequestInBuffer :: inline (req: *HipcRequest, buffer: [] void, mode: HipcBufferMode) {
    req.send_buffers.* = hipcMakeBuffer(buffer, xx buffer.count, mode);
    req.send_buffers  += 1;
}

tipcRequestOutBuffer :: inline (req: *HipcRequest, buffer: [] void, mode: HipcBufferMode) {
    req.recv_buffers.* = hipcMakeBuffer(buffer, xx buffer.count, mode);
    req.recv_buffers  += 1;
}

tipcRequestInOutBuffer :: inline (req: *HipcRequest, buffer: [] void, mode: HipcBufferMode) {
    req.exch_buffers.* = hipcMakeBuffer(buffer, xx buffer.count, mode);
    req.exch_buffers  += 1;
}

tipcRequestHandle :: inline (req: *HipcRequest, handle: Handle) {
    req.copy_handles.* = handle;
    req.copy_handles  += 1;
}

_tipcRequestFormatProcessBuffer :: (fmt: *TipcRequestFormat, attr: u32) {
    if !attr return;
    is_in  := (attr & SfBufferAttr_In)  != 0;
    is_out := (attr & SfBufferAttr_Out) != 0;

    if attr & SfBufferAttr_HipcMapAlias {
        if      is_in && is_out  fmt.num_inout_buffers += 1;
        else if is_in            fmt.num_in_buffers    += 1;
        else if is_out           fmt.num_out_buffers   += 1;
    }
}

_tipcRequestProcessBuffer :: (req: *HipcRequest, buf: *SfBuffer, attr: u32)
{
    if !attr return;
    is_in  := (attr & SfBufferAttr_In);
    is_out := (attr & SfBufferAttr_Out);

    if attr & SfBufferAttr.HipcMapAlias {
        mode := HipcBufferMode.Normal;
        if attr & SfBufferAttr.HipcMapTransferAllowsNonSecure {
            mode = .NonSecure;
        }
        if attr & SfBufferAttr.HipcMapTransferAllowsNonDevice {
            mode = .NonDevice;
        }

        if      is_in && is_out  tipcRequestInOutBuffer(req, cast(*void)buf.ptr, buf.size, mode);
        else if is_in            tipcRequestInBuffer(req, buf.ptr, buf.size, mode);
        else if is_out           tipcRequestOutBuffer(req, cast(*void)buf.ptr, buf.size, mode);
    }
}

tipcMakeRequest :: (
    request_id: u32, data_size: u32, send_pid: bool,
    buffer_attrs: SfBufferAttrs, buffers: *SfBuffer,
    handles: [] Handle
) -> *void {
    fmt: TipcRequestFormat;
    fmt.request_id = request_id + 16;
    fmt.data_size = data_size;
    fmt.num_handles = xx handles.count;
    fmt.send_pid = send_pid;

    _tipcRequestFormatProcessBuffer(*fmt, buffer_attrs.attr0);
    _tipcRequestFormatProcessBuffer(*fmt, buffer_attrs.attr1);
    _tipcRequestFormatProcessBuffer(*fmt, buffer_attrs.attr2);
    _tipcRequestFormatProcessBuffer(*fmt, buffer_attrs.attr3);
    _tipcRequestFormatProcessBuffer(*fmt, buffer_attrs.attr4);
    _tipcRequestFormatProcessBuffer(*fmt, buffer_attrs.attr5);
    _tipcRequestFormatProcessBuffer(*fmt, buffer_attrs.attr6);
    _tipcRequestFormatProcessBuffer(*fmt, buffer_attrs.attr7);

    req := hipcMakeRequestInline(armGetTls(),
        type             = fmt.request_id,
        num_send_statics = 0,
        num_send_buffers = fmt.num_in_buffers,
        num_recv_buffers = fmt.num_out_buffers,
        num_exch_buffers = fmt.num_inout_buffers,
        num_data_words   = (data_size + 3) / 4,
        num_recv_statics = 0,
        send_pid         = fmt.send_pid,
        num_copy_handles = fmt.num_handles,
        num_move_handles = 0,
    );

    for handles {
        tipcRequestHandle(*req, it);
    }

    _tipcRequestProcessBuffer(*req, *buffers[0], buffer_attrs.attr0);
    _tipcRequestProcessBuffer(*req, *buffers[1], buffer_attrs.attr1);
    _tipcRequestProcessBuffer(*req, *buffers[2], buffer_attrs.attr2);
    _tipcRequestProcessBuffer(*req, *buffers[3], buffer_attrs.attr3);
    _tipcRequestProcessBuffer(*req, *buffers[4], buffer_attrs.attr4);
    _tipcRequestProcessBuffer(*req, *buffers[5], buffer_attrs.attr5);
    _tipcRequestProcessBuffer(*req, *buffers[6], buffer_attrs.attr6);
    _tipcRequestProcessBuffer(*req, *buffers[7], buffer_attrs.attr7);

    return req.data_words;
}

tipcResponseGetCopyHandle :: inline (res: HipcResponse) -> Handle {
    result := res.copy_handles.*;
    res.copy_handles += 1;
    return result;
}

tipcResponseGetMoveHandle :: inline(res: HipcResponse) -> Handle {
    result := res.move_handles.*;
    res.move_handles += 1;
    return result;
}

_tipcResponseGetHandle :: (res: HipcResponse, type: SfOutHandleAttr, out: *Handle)
{
    if #complete type == {
        case .None;
        case .HipcCopy;
            out.* = tipcResponseGetCopyHandle(res);
        case .HipcMove;
            out.* = tipcResponseGetMoveHandle(res);
    }
}

tipcParseResponse :: (
    out_size: u32, out_data: **void,
    out_objects: [] TipcService,
    out_handle_attrs: SfOutHandleAttrs, out_handles: Handle
) -> Result {

    res := hipcParseResponse(armGetTls());

    rc: Result = xx res.data_words.*;
    res.data_words += 1;

    if R_FAILED(rc) return rc;

    if out_size  out_data.* = res.data_words;

    for * out_objects {
        tipcCreate(it, tipcResponseGetMoveHandle(*res));
    }

    _tipcResponseGetHandle(*res, out_handle_attrs.attr0, *out_handles[0]);
    _tipcResponseGetHandle(*res, out_handle_attrs.attr1, *out_handles[1]);
    _tipcResponseGetHandle(*res, out_handle_attrs.attr2, *out_handles[2]);
    _tipcResponseGetHandle(*res, out_handle_attrs.attr3, *out_handles[3]);
    _tipcResponseGetHandle(*res, out_handle_attrs.attr4, *out_handles[4]);
    _tipcResponseGetHandle(*res, out_handle_attrs.attr5, *out_handles[5]);
    _tipcResponseGetHandle(*res, out_handle_attrs.attr6, *out_handles[6]);
    _tipcResponseGetHandle(*res, out_handle_attrs.attr7, *out_handles[7]);

    return 0;
}

tipcDispatchImpl :: (
    s: *TipcService, request_id: u32,
    in_data: [] void,
    out_data: [] void,

    buffer_attrs:     SfBufferAttrs,
    buffers:          [8] SfBuffer,
    in_send_pid:      bool,
    in_handles:       [8] Handle,
    out_num_objects:  u32,
    out_objects:      *TipcService,
    out_handle_attrs: SfOutHandleAttrs,
    out_handles:      *Handle
) -> Result {
    in := tipcMakeRequest(request_id,
        xx in_data.count, disp.in_send_pid,
        disp.buffer_attrs, disp.buffers,
        disp.in_num_handles, disp.in_handles);

    if in_data.count  memcpy(in, in_data, in_data.count);

    rc := svcSendSyncRequest(s.session);
    if R_SUCCEEDED(rc) {
        out: *void;
        rc = tipcParseResponse(xx outdata.count, *out,
            disp.out_num_objects, disp.out_objects,
            disp.out_handle_attrs, disp.out_handles);

        if R_SUCCEEDED(rc) && out_data && outdata.count {
            memcpy(out_data, out, outdata.count);
        }
    }

    return rc;
}

// @Crappy: I was trying to replicate the experience the C headers were going for, but this seems kind of messy.
//          They were doing named optional parameters in C by using the SfDispatchParams struct and macro magic.

tipcDispatch :: inline (
    s: *TipcService, request_id: u32,

    buffer_attrs:     SfBufferAttrs,
    buffers:          [8] SfBuffer,
    in_send_pid:      bool,
    in_handles:       [8] Handle,
    out_num_objects:  u32,
    out_objects:      *TipcService,
    out_handle_attrs: SfOutHandleAttrs,
    out_handles:      *Handle
) -> Result {
    tipcDispatchImpl(
        s, request_id, null, 0, null, 0,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_handles       = in_handles,
        out_num_objects  = out_num_objects,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

tipcDispatchIn :: inline (
    s: *TipcService, request_id: u32, in_data: [] void,

    buffer_attrs:     SfBufferAttrs,
    buffers:          [8] SfBuffer,
    in_send_pid:      bool,
    in_handles:       [8] Handle,
    out_num_objects:  u32,
    out_objects:      *TipcService,
    out_handle_attrs: SfOutHandleAttrs,
    out_handles:      *Handle
) -> Result {
    tipcDispatchImpl(
        s, request_id, in_data.data, xx in_data.count, null, 0,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_handles       = in_handles,
        out_num_objects  = out_num_objects,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

tipcDispatchOut :: inline (
    s: *TipcService, request_id: u32,
    out_data: [] void,

    buffer_attrs:     SfBufferAttrs,
    buffers:          [8] SfBuffer,
    in_send_pid:      bool,
    in_handles:       [8] Handle,
    out_num_objects:  u32,
    out_objects:      *TipcService,
    out_handle_attrs: SfOutHandleAttrs,
    out_handles:      *Handle
) -> Result {
    tipcDispatchImpl(
        s, request_id, null, 0, out_data.ptr, xx out_data.count,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_handles       = in_handles,
        out_num_objects  = out_num_objects,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

tipcDispatchInOut :: inline (
    s: *TipcService, request_id: u32,
    in_data: [] void,
    out_data: [] void,

    buffer_attrs:     SfBufferAttrs,
    buffers:          [8] SfBuffer,
    in_send_pid:      bool,
    in_handles:       [8] Handle,
    out_num_objects:  u32,
    out_objects:      *TipcService,
    out_handle_attrs: SfOutHandleAttrs,
    out_handles:      *Handle
) -> Result {
    tipcDispatchImpl(
        s, request_id, in_data.data, xx in_data.count, out_data.data, xx out_data.count,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_handles       = in_handles,
        out_num_objects  = out_num_objects,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}
