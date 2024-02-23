// Bindings for libnx, devkitPro's  Switch homebrew userland support library.
// This file contains all the bindings that had to be manually written - mainly for inline functions and such.

// Load the file that contains all the stuff Bindings_Generator was able to do.
// It won't be able to work on its own without the stuff in this file.
#load "autogen.jai";

intptr_t    :: s64;
uintptr_t   :: u64;
__uintptr_t :: uintptr_t;

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
MAKERESULT :: inline (module: Module, description: $T) -> Result {
    return xx ((cast(u32)module) & 0x1FF) | ((cast(u32)description) & 0x1FFF) << 9;
}

to_array :: (buf: SfBuffer) -> [] void {
    result: [] void;
    result.data  = buf.ptr;
    result.count = xx buf.size;
    return result;
}

// @HACK: Pretty spooky impelmentation here! I'm assuming the first return value is in x0!
//        Rework when Jai gets inline assembly support for ARM64!
armGetTls :: () -> *void {
    // mrs x0, tpidrro_el0
    // ret
    #bytes .[0x60, 0xD0, 0x3B, 0xD5, 0xC0, 0x03, 0x5F, 0xD6];
    return null; // Make compiler happy, but this shouldn't be reached!
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
    if      id <= .No8       return (pad.active_id_mask & (cast(int) BIT(id))) != 0;
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
    return (pad.attributes & cast(u32) HidNpadAttribute.IsConnected) != 0;
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
    r.counter     = 0;
    r.delay       = delay;
    r.repeat      = repeat;
}

/**
 * @brief Retrieves the set of buttons that are being repeated according to the parameters specified in \ref padRepeaterInitialize.
 * @param[in] r Pointer to \ref PadRepeater.
 * @return Bitfield of \ref HidNpadButton.
 * @remark It is suggested to bitwise-OR the return value of this function with that of \ref padGetButtonsDown.
 */
padRepeaterGetButtons :: inline (r: PadRepeater) -> HidNpadButton {
    return ifx r.counter == 0 then cast(HidNpadButton) r.button_mask else cast(HidNpadButton) 0;
}

/// Retrieves a pointer to temporary stage for reading entries
fsdevDirGetEntries :: inline (dir: *fsdev_dir_t) -> *FsDirectoryEntry {
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

/** error.h **/

/**
 * @brief Creates an \ref ErrorCode.
 * @param low  The module portion of the error, normally this should be set to module + 2000.
 * @param desc The error description.
 */
errorCodeCreate :: inline (low: u32, desc: u32) -> ErrorCode {
    return ErrorCode.{low, desc};
}

/**
 * @brief Creates an \ref ErrorCode with the input Result. Wrapper for \ref errorCodeCreate.
 * @param res Input Result.
 */
errorCodeCreateResult :: inline (res: Result) -> ErrorCode {
    return errorCodeCreate(xx (2000 + xx R_MODULE(res)), xx R_DESCRIPTION(res));
}

/**
 * @brief Creates an invalid \ref ErrorCode.
 */
errorCodeCreateInvalid :: inline () -> ErrorCode {
    return ErrorCode.{};
}

/**
 * @brief Checks whether the input ErrorCode is valid.
 * @param errorCode \ref ErrorCode
 */
errorCodeIsValid :: inline (errorCode: ErrorCode) -> bool {
    return errorCode.low != 0;
}

/**
 * @brief Launches the applet for displaying an error full-screen, using the specified Result and timestamp.
 * @param res Result
 * @param timestamp POSIX timestamp.
 * @note Wrapper for \ref errorCodeRecordShow, see \ref errorCodeRecordShow notes.
 */
errorResultRecordShow :: inline (res: Result, timestamp: u64) -> Result {
    return errorCodeRecordShow(errorCodeCreateResult(res), timestamp);
}

/**
 * @brief Sets the error code.
 * @param c    ErrorSystemConfig struct.
 * @param errorCode \ref ErrorCode
 */
errorSystemSetCode :: inline (c: *ErrorSystemConfig, errorCode: ErrorCode) {
    c.arg.errorCode = errorCode;
}

/**
 * @brief Sets the error code, using the input Result. Wrapper for \ref errorSystemSetCode.
 * @param c    ErrorSystemConfig struct.
 * @param res  The Result to set.
 */
errorSystemSetResult :: inline (c: *ErrorSystemConfig, res: Result) {
    errorSystemSetCode(c, errorCodeCreateResult(res));
}

/**
 * @brief Sets the LanguageCode.
 * @param c            ErrorSystemConfig struct.
 * @param LanguageCode LanguageCode, see set.h.
 */
errorSystemSetLanguageCode :: inline (c: *ErrorSystemConfig, LanguageCode: u64) {
    c.arg.languageCode = LanguageCode;
}

/**
 * @brief Sets the error code number.
 * @param c           ErrorApplicationConfig struct.
 * @param errorNumber Error code number. Raw decimal error number which is displayed in the dialog.
 */
errorApplicationSetNumber :: inline (c: *ErrorApplicationConfig, errorNumber: u32) {
    c.arg.errorNumber = errorNumber;
}

/**
 * @brief Sets the LanguageCode.
 * @param c            ErrorApplicationConfig struct.
 * @param LanguageCode LanguageCode, see set.h.
 */
errorApplicationSetLanguageCode :: inline (c: *ErrorApplicationConfig, LanguageCode: u64) {
    c.arg.languageCode = LanguageCode;
}

/** psel.h **/

/**
 * @brief Sets whether users can be created in the applet.
 * @param ui PselUiSettings struct.
 * @param flag Flag value.
 * @note Only used for PselUiMode.SelectUser.
 */
pselUiSetAllowUserCreation :: inline (ui: *PselUiSettings, flag: bool) {
    if ui.settings.mode == xx PselUiMode.UserSelector {
        ui.settings.is_permitted = xx flag;
    }
}

/**
 * @brief Sets whether users need to be linked to a Nintendo account.
 * @param ui PselUiSettings struct.
 * @param flag Flag value.
 */
pselUiSetNetworkServiceRequired :: inline (ui: *PselUiSettings, flag: bool) {
    ui.settings.is_network_service_account_required = xx flag;
}

/**
 * @brief Sets whether selection can be skipped with a button.
 * @param ui PselUiSettings struct.
 * @param flag Flag value.
 */
pselUiSetSkipButtonEnabled :: inline (ui: *PselUiSettings, flag: bool) {
    ui.settings.show_skip_button = xx flag;
}

/** swkbd.h **/

/**
 * @brief Sets SwkbdArgCommon::SwkbdType.
 * @param c SwkbdConfig struct.
 * @param type \ref SwkbdType
 */
swkbdConfigSetType :: inline (c: *SwkbdConfig, type: SwkbdType) {
    c.arg.arg.arg.type = type;
}

/**
 * @brief Sets SwkbdArgCommon::dicFlag.
 * @param c SwkbdConfig struct.
 * @param flag Flag
 */
swkbdConfigSetDicFlag :: inline (c: *SwkbdConfig, flag: u8) {
    c.arg.arg.arg.dicFlag = flag;
}

/**
 * @brief Sets SwkbdArgCommon::keySetDisableBitmask.
 * @param c SwkbdConfig struct.
 * @param keySetDisableBitmask keySetDisableBitmask
 */
swkbdConfigSetKeySetDisableBitmask :: inline (c: *SwkbdConfig, keySetDisableBitmask: u32) {
    c.arg.arg.arg.keySetDisableBitmask = keySetDisableBitmask;
}

/**
 * @brief Sets SwkbdArgCommon::initialCursorPos.
 * @param c SwkbdConfig struct.
 * @param initialCursorPos initialCursorPos
 */
swkbdConfigSetInitialCursorPos :: inline (c: *SwkbdConfig, initialCursorPos: u32) {
    c.arg.arg.arg.initialCursorPos = initialCursorPos;
}

/**
 * @brief Sets SwkbdArgCommon::stringLenMax.
 * @param c SwkbdConfig struct.
 * @param stringLenMax stringLenMax
 */
swkbdConfigSetStringLenMax :: inline (c: *SwkbdConfig, stringLenMax: u32) {
    c.arg.arg.arg.stringLenMax = stringLenMax;
}

/**
 * @brief Sets SwkbdArgCommon::stringLenMin.
 * @param c SwkbdConfig struct.
 * @param stringLenMin stringLenMin
 */
swkbdConfigSetStringLenMin :: inline (c: *SwkbdConfig, stringLenMin: u32) {
    c.arg.arg.arg.stringLenMin = stringLenMin;
}

/**
 * @brief Sets SwkbdArgCommon::passwordFlag.
 * @param c SwkbdConfig struct.
 * @param flag Flag
 */
swkbdConfigSetPasswordFlag :: inline (c: *SwkbdConfig, flag: u32) {
    c.arg.arg.arg.passwordFlag = flag;
}

/**
 * @brief Sets SwkbdArgCommon::textDrawType.
 * @param c SwkbdConfig struct.
 * @param textDrawType \ref SwkbdTextDrawType
 */
swkbdConfigSetTextDrawType :: inline (c: *SwkbdConfig, textDrawType: SwkbdTextDrawType) {
    c.arg.arg.arg.textDrawType = textDrawType;
}

/**
 * @brief Sets SwkbdArgCommon::returnButtonFlag.
 * @param c SwkbdConfig struct.
 * @param flag Flag
 */
swkbdConfigSetReturnButtonFlag :: inline (c: *SwkbdConfig, flag: u16) {
    c.arg.arg.arg.returnButtonFlag = flag;
}

/**
 * @brief Sets SwkbdArgCommon::blurBackground.
 * @param c SwkbdConfig struct.
 * @param blurBackground blurBackground
 */
swkbdConfigSetBlurBackground :: inline (c: *SwkbdConfig, blurBackground: u8) {
    c.arg.arg.arg.blurBackground = blurBackground;
}

/**
 * @brief Sets SwkbdArgV7::textGrouping.
 * @param index Array index.
 * @param value Value to write.
 */
swkbdConfigSetTextGrouping :: inline (c: *SwkbdConfig, index: u32, value: u32) {
    if index >= size_of(type_of(c.arg.textGrouping))/size_of(u32)  return;
    c.arg.textGrouping[index] = value;
}

/**
 * @brief Sets SwkbdConfig::unkFlag, default is 0. Copied to SwkbdArgVB::unkFlag with [8.0.0+].
 * @param flag Flag
 */
swkbdConfigSetUnkFlag :: inline (c: *SwkbdConfig, flag: u8) {
    c.unkFlag = flag;
}

/**
 * @brief Sets SwkbdConfig::trigger, default is 0. Copied to SwkbdArgVB::trigger with [8.0.0+].
 * @param trigger Trigger
 */
swkbdConfigSetTrigger :: inline (c: *SwkbdConfig, trigger: u8) {
    c.trigger = trigger;
}

/**
 * @brief Sets the stringLenMax for the specified SwkbdAppearArg, which was previously initialized with \ref swkbdInlineMakeAppearArg.
 * @param arg \ref SwkbdAppearArg
 * @param stringLenMax Max string length
 */
swkbdInlineAppearArgSetStringLenMax :: inline (arg: *SwkbdAppearArg, stringLenMax: s32) {
    arg.stringLenMax = stringLenMax;
}

/**
 * @brief Sets the stringLenMin for the specified SwkbdAppearArg, which was previously initialized with \ref swkbdInlineMakeAppearArg.
 * @param arg \ref SwkbdAppearArg
 * @param stringLenMin Min string length
 */
swkbdInlineAppearArgSetStringLenMin :: inline (arg: *SwkbdAppearArg, stringLenMin: s32) {
    arg.stringLenMin = stringLenMin;
}

/** counter.h **/

/**
 * @brief Gets the current system tick.
 * @return The current system tick.
 */
armGetSystemTick :: inline () -> u64 {
    // @HACK: Pretty spooky impelmentation here! I'm assuming the first return value is in x0!
    //        Rework when Jai gets inline assembly support for ARM64!
    // mrs x0, cntpct_el0
    // ret
    #bytes .[0x20, 0xE0, 0x3B, 0xD5, 0xC0, 0x03, 0x5F, 0xD6];
    return 0;
}

/**
 * @brief Gets the system counter-timer frequency
 * @return The system counter-timer frequency, in Hz.
 */
armGetSystemTickFreq :: inline () -> u64 {
    // @HACK: Pretty spooky impelmentation here! I'm assuming the first return value is in x0!
    //        Rework when Jai gets inline assembly support for ARM64!
    // mrs x0, cntfrq_el0
    // ret
    #bytes .[0xC0, 0x03, 0x3B, 0xD5, 0xC0, 0x03, 0x5F, 0xD6];
    return 0;
}

/**
 * @brief Converts from nanoseconds to CPU ticks unit.
 * @param ns Time in nanoseconds.
 * @return Time in CPU ticks.
 */
armNsToTicks :: inline (ns: u64) -> u64 {
    return (ns * 12) / 625;
}

/**
 * @brief Converts from CPU ticks unit to nanoseconds.
 * @param tick Time in ticks.
 * @return Time in nanoseconds.
 */
armTicksToNs :: inline (tick: u64) -> u64 {
    return (tick * 625) / 12;
}

/** thread_context.h **/

/**
 * @brief Determines whether a thread context belong to an AArch64 process based on the PSR.
 * @param[in] ctx Thread context to which PSTATE/cspr has been dumped to.
 * @return true if and only if the thread context belongs to an AArch64 process.
 */
threadContextIsAArch64 :: inline (ctx: ThreadContext) -> bool {
    return (ctx.psr & 0x10) == 0;
}

/**
 * @brief Determines whether a ThreadExceptionDump belongs to an AArch64 process based on the PSTATE.
 * @param[in] ctx ThreadExceptionDump.
 * @return true if and only if the ThreadExceptionDump belongs to an AArch64 process.
 */
threadExceptionIsAArch64 :: inline (ctx: ThreadExceptionDump) -> bool {
    return (ctx.pstate & 0x10) == 0;
}

/** driver.h **/

audrvVoiceSetExtraParams :: inline (d: *AudioDriver, id: s32, params: *void, params_size: size_t) {
    d.in_voices[id].extra_params_ptr = params;
    d.in_voices[id].extra_params_sz  = params_size;
}

audrvVoiceSetDestinationMix :: inline (d: *AudioDriver, id: s32, mix_id: s32) {
    d.in_voices[id].dest_mix_id      = xx mix_id;
    d.in_voices[id].dest_splitter_id = AUDREN_UNUSED_SPLITTER_ID;
}

audrvVoiceSetMixFactor :: inline (d: *AudioDriver, id: s32, factor: float, src_channel_id: s32, dest_channel_id: s32) {
    channel_id := d.in_voices[id].channel_ids[src_channel_id];
    d.in_channels[channel_id].mix[dest_channel_id] = factor;
}

audrvVoiceSetVolume :: inline (d: *AudioDriver, id: s32, volume: float) {
    d.in_voices[id].volume = volume;
}

audrvVoiceSetPitch :: inline (d: *AudioDriver, id: s32, pitch: float) {
    d.in_voices[id].pitch = pitch;
}

audrvVoiceSetPriority :: inline (d: *AudioDriver, id: s32, priority: s32) {
    d.in_voices[id].priority = xx priority;
}

audrvVoiceClearBiquadFilter :: inline (d: *AudioDriver, id: s32, biquad_id: s32) {
    d.in_voices[id].biquads[biquad_id].enable = false;
}

audrvVoiceSetPaused :: inline (d: *AudioDriver, id: s32, paused: bool) {
    d.in_voices[id].set_state(*d.in_voices[id], xx ifx paused then AudioRendererVoicePlayState.Paused else .Started);
}

audrvVoiceStart :: inline (d: *AudioDriver, id: s32) {
    audrvVoiceSetPaused(d, id, false);
}

audrvMixSetDestinationMix :: inline (d: *AudioDriver, id: s32, mix_id: s32) {
    d.in_mixes[id].dest_mix_id = xx mix_id;
    d.in_mixes[id].dest_splitter_id = AUDREN_UNUSED_SPLITTER_ID;
}

audrvMixSetMixFactor :: inline (d: *AudioDriver, id: s32, factor: float, src_channel_id: s32, dest_channel_id: s32) {
    d.in_mixes[id].mix[src_channel_id][dest_channel_id] = factor;
}

audrvMixSetVolume :: inline (d: *AudioDriver, id: s32, volume: float) {
    d.in_mixes[id].volume = volume;
}

/** aes.h **/

AES_128_U32_PER_KEY :: #run AES_128_KEY_SIZE / size_of(u32);
AES_192_U32_PER_KEY :: #run AES_192_KEY_SIZE / size_of(u32);
AES_256_U32_PER_KEY :: #run AES_256_KEY_SIZE / size_of(u32);

/** crc.h **/

// @Incomplete: I don't even know whether I should attempt that #bytes hack for these crc32 instructions.

// __crc32b :: (crc: u32, val: u8) -> u32 #intrinsic "llvm.";

// _CRC_ALIGN :: ($sz: Type, $insn: string) #expand {
//     if ((cast(uintptr_t)`src_u8 & cast(uintptr_t) size_of(sz)) && `len >= size_of(sz)) {
//         `crc = #insert #run tprint("__crc32%(`crc, (cast(*sz)`src_u8).*);", insn);
//         `src_u8 += size_of(sz);
//         `len -= size_of(sz);
//     }
// }

// _CRC_REMAINDER :: ($sz: Type, $insn: string) #expand {
//     if (`len & size_of(sz)) {
//         `crc = #insert #run tprint("__crc32%(`crc, (cast(*sz)`src_u8).*);", insn);
//         `src_u8 += size_of(sz);
//     }
// }

// /// Calculate a CRC32 over data using a seed.
// /// Can be used to calculate a CRC32 in chunks using an initial seed of zero for the first chunk.
// crc32CalculateWithSeed :: inline (seed: u32, src: *void, size: size_t) -> u32 {
//     src_u8 := cast(*u8) src;

//     crc: u32 = ~seed;
//     len: s64 = xx size;

//     _CRC_ALIGN(u8,  "b");
//     _CRC_ALIGN(u16, "h");
//     _CRC_ALIGN(u32, "w");

//     while true {
//         len -= size_of(u64);
//         if len < 0  break;

//         crc = __crc32d(crc, (cast(*u64)src_u8).*);
//         src_u8 += size_of(u64);
//     }

//     _CRC_REMAINDER(u32, "w");
//     _CRC_REMAINDER(u16, "h");
//     _CRC_REMAINDER(u8,  "b");

//     return ~crc;
// }

// /// Calculate a CRC32 over data.
// crc32Calculate :: inline (src: *void, size: size_t) -> u32 {
//     return crc32CalculateWithSeed(0, src, size);
// }

// /// Calculate a CRC32C over data using a seed.
// /// Can be used to calculate a CRC32C in chunks using an initial seed of zero for the first chunk.
// crc32cCalculateWithSeed :: inline (seed: u32, src: *void, size: size_t) -> u32 {
//     src_u8 := cast(*u8)src;

//     crc: u32 = ~seed;
//     len: s64 = xx size;

//     _CRC_ALIGN(u8,  "cb");
//     _CRC_ALIGN(u16, "ch");
//     _CRC_ALIGN(u32, "cw");

//     while true {
//         len -= size_of(u64);
//         if len < 0  break;

//         crc = __crc32cd(crc, (cast(*u64)src_u8).*);
//         src_u8 += size_of(u64);
//     }

//     _CRC_REMAINDER(u32, "cw");
//     _CRC_REMAINDER(u16, "ch");
//     _CRC_REMAINDER(u8,  "cb");

//     return ~crc;
// }

// /// Calculate a CRC32C over data.
// crc32cCalculate :: inline (src: *void, size: size_t) -> u32 {
//     return crc32cCalculateWithSeed(0, src, size);
// }

/** hmac.h **/

HMAC_SHA1_KEY_MAX   :: #run size_of(type_of(HmacSha1Context.key));
HMAC_SHA256_KEY_MAX :: #run size_of(type_of(HmacSha256Context.key));

/** binder.h **/

binderIncreaseWeakRef :: inline (b: *Binder) -> Result {
    return binderAdjustRefcount(b, 1, 0);
}

binderDecreaseWeakRef :: inline (b: *Binder) -> Result {
    return binderAdjustRefcount(b, -1, 0);
}

binderIncreaseStrongRef :: inline (b: *Binder) -> Result {
    return binderAdjustRefcount(b, 1, 1);
}

binderDecreaseStrongRef :: inline (b: *Binder) -> Result {
    return binderAdjustRefcount(b, -1, 1);
}

/** framebuffer.h **/

/// Converts red/green/blue/alpha components to packed RGBA8 (i.e. \ref PIXEL_FORMAT_RGBA_8888).
RGBA8 :: inline (r: u64, g: u64, b: u64, a: u64) -> u32 {
    return xx ((r&0xff)|((g&0xff)<<8)|((b&0xff)<<16)|((a&0xff)<<24));
}

/// Same as \ref RGBA8 except with alpha=0xff.
RGBA8_MAXALPHA :: inline (r: u64, g: u64, b: u64) -> u32 {
    return xx RGBA8(r, g, b, 0xff);
}

/// Converts red/green/blue to packed RGBX8 (i.e. \ref PIXEL_FORMAT_RGBX_8888).
RGBX8 :: inline (r: u64, g: u64, b: u64) -> u32 {
    return xx RGBA8(r, g, b, 0);
}

/// Converts red/green/blue components to packed RGB565 (i.e. \ref PIXEL_FORMAT_RGB_565)
RGB565 :: inline (r: u64, g: u64, b: u64) -> u32 {
    return xx ((b&0x1f)|((g&0x3f)<<5)|((r&0x1f)<<11));
}

/// Same as \ref RGB565 but accepting 8-bit components as input instead.
RGB565_FROM_RGB8 :: inline (r: u64, g: u64, b: u64) -> u32 {
    return xx RGB565(r>>3,g>>2,b>>3);
}

/// Converts red/green/blue/alpha components to packed BGR8 (i.e. \ref PIXEL_FORMAT_BGRA_8888).
BGRA8 :: inline (r: u64, g: u64, b: u64, a: u64) -> u32 {
    return xx RGBA8(b,g,r,a);
}

/// Same as \ref BGRA8 except with alpha=0xff.
BGRA8_MAXALPHA :: inline (r: u64, g: u64, b: u64) -> u32 {
    return xx RGBA8(b,g,r,0xff);
}

/// Converts red/green/blue/alpha components to packed RGBA4 (i.e. \ref PIXEL_FORMAT_RGBA_4444).
RGBA4 :: inline (r: u64, g: u64, b: u64, a: u64) -> u32 {
    return xx ((r&0xf)|((g&0xf)<<4)|((b&0xf)<<8)|((a&0xf)<<12));
}

/// Same as \ref RGBA4 except with alpha=0xf.
RGBA4_MAXALPHA :: inline (r: u64, g: u64, b: u64) -> u32 {
    return xx RGBA4(r,g,b,0xf);
}

/// Same as \ref RGBA4 but accepting 8-bit components as input instead.
RGBA4_FROM_RGBA8 :: inline (r: u64, g: u64, b: u64, a: u64) -> u32 {
    return xx RGBA4(r>>4,g>>4,b>>4,a>>4);
}

/// Same as \ref RGBA4_MAXALPHA except with alpha=0xff.
RGBA4_FROM_RGBA8_MAXALPHA :: inline (r: u64, g: u64, b: u64) -> u32 {
    return xx RGBA4_MAXALPHA(r>>4,g>>4,b>>4);
}

/** native_window.h **/

/// Checks whether the consumer of a \ref NWindow is running behind.
nwindowIsConsumerRunningBehind :: inline (nw: NWindow) -> bool {
    return nw.consumer_running_behind;
}


/** condvar.h **/

/**
 * @brief Initializes a condition variable.
 * @param[in] c Condition variable object.
 */
condvarInit :: inline (c: *CondVar) {
    c.* = 0;
}

/**
 * @brief Waits on a condition variable.
 * @param[in] c Condition variable object.
 * @param[in] m Mutex object to use inside the condition variable.
 * @return Result code.
 * @remark On function return, the underlying mutex is acquired.
 */
condvarWait :: inline (c: *CondVar, m: *Mutex) -> Result {
    return condvarWaitTimeout(c, m, U64_MAX);
}

/**
 * @brief Wakes up up to the specified number of threads waiting on a condition variable.
 * @param[in] c Condition variable object.
 * @param[in] num Maximum number of threads to wake up (or -1 to wake them all up).
 * @return Result code.
 */
condvarWake :: inline (c: *CondVar, num: s32) -> Result {
    svcSignalProcessWideKey(c, num);
    return 0;
}

/**
 * @brief Wakes up a single thread waiting on a condition variable.
 * @param[in] c Condition variable object.
 * @return Result code.
 */
condvarWakeOne :: inline (c: *CondVar) -> Result {
    return condvarWake(c, 1);
}

/**
 * @brief Wakes up all thread waiting on a condition variable.
 * @param[in] c Condition variable object.
 * @return Result code.
 */
condvarWakeAll :: inline (c: *CondVar) -> Result {
    return condvarWake(c, -1);
}

/** detect.h **/

/// Returns true if the process has a debugger attached.
detectDebugger :: inline () -> bool {
    tmp: u64 = 0;
    rc := svcGetInfo(*tmp, xx InfoType.DebuggerAttached, INVALID_HANDLE, 0);
    return R_SUCCEEDED(rc) && tmp != 0;
}

/// Returns true if the underlying kernel is Mesosphère.
detectMesosphere :: inline () -> bool {
    dummy: u64 = 0;
    rc := svcGetInfo(*dummy, 65000, INVALID_HANDLE, 0); // InfoType.MesosphereMeta
    return R_SUCCEEDED(rc);
}

/** event.h **/

/// Creates a \ref Waiter for a kernel-mode event.
waiterForEvent :: inline (t: *Event) -> Waiter {
    wait_obj: Waiter;
    wait_obj.type   = ifx t.autoclear then WaiterType.HandleWithClear else WaiterType.Handle;
    wait_obj.handle = t.revent;
    return wait_obj;
}

/**
 * @brief Returns whether an \ref Event is initialized.
 * @param[in] t Pointer to \ref Event structure.
 * @return Initialization status.
 */
eventActive :: inline (t: *Event) -> bool {
    return t.revent != INVALID_HANDLE;
}

/** jit.h **/

/**
 * @brief Gets the address of the writable memory alias of a JIT buffer.
 * @param j JIT buffer.
 * @return Pointer to alias of the JIT buffer that can be written to.
 */
jitGetRwAddr :: inline (j: Jit) -> *void {
    return j.rw_addr;
}

/**
 * @brief Gets the address of the executable memory alias of a JIT buffer.
 * @param j JIT buffer.
 * @return Pointer to alias of the JIT buffer that can be executed.
 */
jitGetRxAddr :: inline (j: Jit) -> *void {
    return j.rx_addr;
}

/** levent.h **/

/**
 * @brief Initializes a user-mode light event.
 * @param[out] le Pointer to \ref LEvent structure.
 * @param[in] signaled Whether the event starts off in signaled state.
 * @param[in] autoclear Autoclear flag.
 */
leventInit :: inline (le: *LEvent, signaled: bool, autoclear: bool) {
    le.counter   = xx (ifx signaled then 2 else 0);
    le.autoclear = autoclear;
}

/** mutex.h **/

/**
 * @brief Initializes a mutex.
 * @param m Mutex object.
 * @note A mutex can also be statically initialized by assigning 0 to it.
 */
mutexInit :: inline (m: *Mutex) {
    m.* = INVALID_HANDLE;
}

/**
 * @brief Initializes a recursive mutex.
 * @param m Recursive mutex object.
 * @note A recursive mutex can also be statically initialized by assigning {0,0,0} to it.
 */
rmutexInit :: inline (m: *RMutex) {
    m.lock       = 0;
    m.thread_tag = 0;
    m.counter    = 0;
}

/** shmem.h **/

/**
 * @brief Retrieves the mapped address of a shared memory object.
 * @param s Shared memory information structure.
 * @return Mapped address of the shared memory object.
 */
shmemGetAddr :: inline (s: SharedMemory) -> *void {
    return s.map_addr;
}

/** thread.h **/

/// Creates a \ref Waiter for a \ref Thread.
waiterForThread :: inline (t: *Thread) -> Waiter {
    return waiterForHandle(t.handle);
}

/** tmem.h **/

/**
 * @brief Retrieves the mapped address of a transfer memory object.
 * @param t Transfer memory information structure.
 * @return Mapped address of the transfer memory object.
 */
tmemGetAddr :: inline (t: TransferMemory) -> *void {
    return t.map_addr;
}

/** uevent.h **/

/// Creates a waiter for a user-mode event.
waiterForUEvent :: inline (e: *UEvent) -> Waiter {
    wait_obj: Waiter;
    wait_obj.type     = WaiterType.Waitable;
    wait_obj.waitable = *e.waitable;
    return wait_obj;
}

/** wait.h **/

/// Creates a \ref Waiter for a kernel-mode \ref Handle.
waiterForHandle :: inline (h: Handle) -> Waiter {
    wait_obj: Waiter;
    wait_obj.type   = WaiterType.Handle;
    wait_obj.handle = h;
    return wait_obj;
}

/**
 * @brief Helper macro for \ref waitObjects that accepts \ref Waiter structures as variadic arguments instead of as an array.
 * @param[out] idx_out The index of the signalled waiter.
 * @param[in] timeout Timeout (in nanoseconds).
 * @note The number of objects must not be greater than \ref MAX_WAIT_OBJECTS. This is a Horizon kernel limitation.
 */
waitMulti :: inline (idx_out: *s32, timeout: u64, objects: ..Waiter) -> Result {
    return waitObjects(idx_out, objects.data, xx objects.count, timeout);
}

/**
 * @brief Helper macro for \ref waitHandles that accepts handles as variadic arguments instead of as an array.
 * @param[out] idx_out The index of the signalled handle.
 * @param[in] timeout Timeout (in nanoseconds).
 * @note The number of objects must not be greater than \ref MAX_WAIT_OBJECTS. This is a Horizon kernel limitation.
 */
waitMultiHandle :: inline (idx_out: *s32, timeout: u64, handles: ..Handle) -> Result {
    return waitHandles(idx_out, handles.data, xx handles.count, timeout);
}

/**
 * @brief Waits on a single generic waitable synchronization object, optionally with a timeout.
 * @param[in] w \ref Waiter structure.
 * @param[in] timeout Timeout (in nanoseconds).
 */
waitSingle :: inline (w: Waiter, timeout: u64) -> Result {
    idx: s32;
    return waitObjects(*idx, *w, 1, timeout);
}

/**
 * @brief Waits for a single kernel synchronization object, optionally with a timeout.
 * @param[in] h \ref Handle of the object.
 * @param[in] timeout Timeout (in nanoseconds).
 */
waitSingleHandle :: inline (h: Handle, timeout: u64) -> Result {
    idx: s32;
    return waitHandles(*idx, *h, 1, timeout);
}

/** fence.h **/

nvMultiFenceCreate :: inline (mf: *NvMultiFence, fence: *NvFence) {
    mf.num_fences = 1;
    mf.fences[0] = fence.*;
}

nvGpuChannelGetSyncpointId :: inline (c: NvGpuChannel) -> u32 {
    return c.fence.id;
}

/** gpu_channel.h **/

nvGpuChannelGetFence :: inline (c: *NvGpuChannel, fence_out: *NvFence) {
    fence_out.id = c.fence.id;
    fence_out.value = c.fence.value + c.fence_incr;
}

nvGpuChannelIncrFence :: inline (c: *NvGpuChannel) {
    c.fence_incr += 1;
}

/** map.h **/

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

/** acc.h **/

accountUidIsValid :: inline (Uid: *AccountUid) -> bool {
    return Uid.uid[0] != 0 || Uid.uid[1] != 0;
}

/** applet.h **/

/**
 * @brief Gets the LibraryApplet StateChangedEvent.
 * @param h AppletHolder object.
 */
appletHolderGetExitEvent :: inline (h: *AppletHolder) -> *Event {
    return *h.StateChangedEvent;
}

/** audren.h **/

audrenGetMemPoolCount :: inline (config: AudioRendererConfig) -> s32 {
    return config.num_effects + 4 * config.num_voices;
}

audrenGetInputParamSize :: inline (config: AudioRendererConfig) -> size_t {
    size: size_t = 0;
    size += xx (size_of(AudioRendererUpdateDataHeader));
    size += xx (size_of(AudioRendererBehaviorInfoIn));
    size += xx (size_of(AudioRendererMemPoolInfoIn) * audrenGetMemPoolCount(config));
    size += xx (size_of(AudioRendererChannelInfoIn) * config.num_voices);
    size += xx (size_of(AudioRendererVoiceInfoIn) * config.num_voices);
    // todo: effects, splitters
    size += xx (size_of(AudioRendererMixInfoIn) * config.num_mix_objs);
    size += xx (size_of(AudioRendererSinkInfoIn) * config.num_sinks);
    size += xx (size_of(AudioRendererPerformanceBufferInfoIn));
    return size;
}

audrenGetOutputParamSize :: inline (config: AudioRendererConfig) -> size_t {
    size: size_t = 0;
    size += xx (size_of(AudioRendererUpdateDataHeader));
    size += xx (size_of(AudioRendererMemPoolInfoOut) * audrenGetMemPoolCount(config));
    size += xx (size_of(AudioRendererVoiceInfoOut) * config.num_voices);
    // todo: effects
    size += xx (size_of(AudioRendererSinkInfoOut) * config.num_sinks);
    size += xx (size_of(AudioRendererPerformanceBufferInfoOut));
    size += xx (size_of(AudioRendererBehaviorInfoOut));
    return size;
}

/** caps.h **/

/// Gets the default start_datetime.
capsGetDefaultStartDateTime :: inline () -> CapsAlbumFileDateTime {
    return CapsAlbumFileDateTime.{year = 1970, month = 1, day = 1};
}

/// Gets the default end_datetime.
capsGetDefaultEndDateTime :: inline () -> CapsAlbumFileDateTime {
    return CapsAlbumFileDateTime.{year = 3000, month = 1, day = 1};
}

/// Convert a \ref CapsApplicationAlbumFileEntry to \ref CapsApplicationAlbumEntry.
capsConvertApplicationAlbumFileEntryToApplicationAlbumEntry :: inline (out: *CapsApplicationAlbumEntry, in: *CapsApplicationAlbumFileEntry) {
    out.* = in.entry;
}

/// Convert a \ref CapsApplicationAlbumEntry to \ref CapsApplicationAlbumFileEntry. Should only be used on [7.0.0+].
capsConvertApplicationAlbumEntryToApplicationAlbumFileEntry :: inline (out: *CapsApplicationAlbumFileEntry, in: *CapsApplicationAlbumEntry) {
    out.entry = in.*;
    out.datetime = in.v1.datetime;
    out.unk_x28 = 0;
}

/** friends.h **/

/**
 * @brief Gets an Event which is signaled when data is available with \ref friendsTryPopFriendInvitationNotificationInfo.
 * @note This is a wrapper for \ref appletGetFriendInvitationStorageChannelEvent, see that for the usage requirements.
 * @note The Event must be closed by the user once finished with it.
 * @param[out] out_event Output Event with autoclear=false.
 */
friendsGetFriendInvitationNotificationEvent :: inline (out_event: *Event) -> Result {
    return appletGetFriendInvitationStorageChannelEvent(out_event);
}

/** grc.h **/

/**
 * @brief Gets the \ref NWindow for the specified MovieMaker.
 * @param m \ref GrcMovieMaker
 */
grcMovieMakerGetNWindow :: inline (m: *GrcMovieMaker) -> *NWindow {
    return *m.win;
}


/** hid.h **/

/**
 * @brief Gets the state of a key in a \ref HidKeyboardState.
 * @param[in] state \ref HidKeyboardState.
 * @param[in] key \ref HidKeyboardKey.
 * @return true if the key is pressed, false if not.
 */
hidKeyboardStateGetKey :: inline (state: HidKeyboardState, key: HidKeyboardKey) -> bool {
    return (state.keys[key / 64] & ((cast(u64)1) << ((cast(u64)key) & (cast(u64)63)))) != 0;
}

/** irs.h **/

/**
 * Gets the default configuration for IrLedProcessor.
 */
irsGetIrLedProcessorDefaultConfig :: inline (config: *IrsIrLedProcessorConfig) {
    config.light_target = 0;
}

/** lp2p.h **/

/**
 * @brief Sets Lp2pGroupInfo::member_count_max.
 * @param info \ref Lp2pGroupInfo
 * @param[in] count MemberCountMax
 */
lp2pGroupInfoSetMemberCountMax :: inline (info: *Lp2pGroupInfo, count: size_t) {
    info.member_count_max = xx count;
}

/**
 * @brief Sets Lp2pGroupInfo::frequency and Lp2pGroupInfo::channel.
 * @param info \ref Lp2pGroupInfo
 * @param[in] frequency Lp2pGroupInfo::frequency
 * @param[in] channel Lp2pGroupInfo::channel
 */
lp2pGroupInfoSetFrequencyChannel :: inline (info: *Lp2pGroupInfo, frequency: u16, channel: s16) {
    info.frequency = frequency;
    info.channel   = channel;
}

/**
 * @brief Sets Lp2pGroupInfo::stealth_enabled.
 * @param info \ref Lp2pGroupInfo
 * @param[in] flag Lp2pGroupInfo::stealth_enabled
 */
lp2pGroupInfoSetStealthEnabled :: inline (info: *Lp2pGroupInfo, flag: bool) {
    info.stealth_enabled = xx flag;
}

/** ncm_types.h **/

/**
 * @brief Retrieves the content size from a \ref NcmContentInfo struct.
 * @param[in] info Pointer to \ref NcmContentInfo struct.
 * @param[out] out Output size.
 */
ncmContentInfoSizeToU64 :: inline (info: NcmContentInfo, out: *u64) {
    out.* = (cast(u64)info.size_high << 32) | info.size_low;
}

/**
 * @brief Updates the content size from a \ref NcmContentInfo struct.
 * @param[in] size Input size.
 * @param[out] out Pointer to \ref NcmContentInfo struct.
 */
ncmU64ToContentInfoSize :: inline (size: u64, info: *NcmContentInfo) {
    info.size_low = xx (size & 0xFFFFFFFF);
    info.size_high = cast(u8)(size >> 32);
}

/** notif.h **/

/**
 * @brief Sets whether the \ref NotifAlarmSetting is muted.
 * @note By default (\ref notifAlarmSettingCreate) this is false.
 * @param alarm_setting \ref NotifAlarmSetting
 * @param[in] flag Whether the alarm is muted (true = Alarm turned off, false = on).
 */
notifAlarmSettingSetIsMuted :: inline (alarm_setting: *NotifAlarmSetting, flag: bool) {
    alarm_setting.muted = xx flag;
}

/**
 * @brief Sets the \ref AccountUid for the \ref NotifAlarmSetting, see NotifAlarmSetting::uid.
 * @param alarm_setting \ref NotifAlarmSetting
 * @param[in] uid \ref AccountUid. If want to clear the uid after it was previously set, you can use an all-zero uid to reset to the default (\ref notifAlarmSettingCreate).
 */
notifAlarmSettingSetUid :: inline (alarm_setting: *NotifAlarmSetting, uid: AccountUid) {
    alarm_setting.uid = uid;
}


/**
 * @brief Gets an Event which is signaled when data is available with \ref notifTryPopNotifiedApplicationParameter.
 * @note This is a wrapper for \ref appletGetNotificationStorageChannelEvent, see that for the usage requirements.
 * @note Some official apps don't use this.
 * @note The Event must be closed by the user once finished with it.
 * @param[out] out_event Output Event with autoclear=false.
 */
notifGetNotificationSystemEvent :: inline (out_event: *Event) -> Result {
    return appletGetNotificationStorageChannelEvent(out_event);
}

/** pdm.h **/

/**
 * @brief Helper function which converts a Play timestamp from the Pdm*Event structs to POSIX.
 * @param[in] timestamp Input timestamp.
 */
pdmPlayTimestampToPosix :: inline (timestamp: u32) -> u64 {
    return (cast(u64)timestamp) * 60 + 946598400;
}

/** sm.h **/

/// Converts a service name into a 64-bit integer.
smServiceNameToU64 :: inline (name: SmServiceName) -> u64 {
    ret: u64 = 0;
    memcpy(*ret, *name, size_of(u64));
    return ret;
}

/// Converts a 64-bit integer into a service name.
smServiceNameFromU64 :: inline (name: u64) -> SmServiceName {
    ret: SmServiceName;
    memcpy(*ret, *name, size_of(SmServiceName));
    return ret;
}

/**
 * @brief Checks whether two service names are equal.
 * @param[in] a First name.
 * @param[in] b Second name.
 * @return Comparison result.
 */
smServiceNamesAreEqual :: inline (a: SmServiceName, b: SmServiceName) -> bool {
    return smServiceNameToU64(a) == smServiceNameToU64(b);
}

/**
 * @brief Encodes a service name string as a \ref SmServiceName structure.
 * @param[in] name Name of the service.
 * @return Encoded name.
 */
smEncodeName :: inline (name: string) -> SmServiceName {
    name_encoded: SmServiceName;

    memcpy(name_encoded.name.data, name.data, min(name.count, name_encoded.name.count));

    return name_encoded;
}

/**
 * @brief Requests a service from SM.
 * @param[out] service_out Service structure which will be filled in.
 * @param[in] name Name of the service to request (as a string).
 * @return Result code.
 */
smGetService :: inline (service_out: *Service, name: string) -> Result {
    return smGetServiceWrapper(service_out, smEncodeName(name));
}

/** usbhs.h **/

/// Returns whether the specified interface session was initialized.
usbHsIfIsActive :: inline (s: *UsbHsClientIfSession) -> bool {
    return serviceIsActive(*s.s);
}

/// Returns the ID which can be used for comparing with the ID in the output interfaces from \ref usbHsQueryAcquiredInterfaces.
usbHsIfGetID :: inline (s: *UsbHsClientIfSession) -> s32 {
    return s.ID;
}

/// Gets the Xfer Event which is signaled when PostBufferAsync finishes. This is only valid for [2.0.0+]. If using \ref eventWait with this, then \ref eventClear should be used if the event was signaled (since the autoclear is false).
usbHsEpGetXferEvent :: inline (s: *UsbHsClientEpSession) -> *Event {
    return *s.eventXfer;
}

/// Gets the buffer size to use with \ref usbHsEpShareReportRing.
usbHsEpGetReportRingSize :: inline (s: *UsbHsClientEpSession) -> u32 {
    max_reports := s.maxUrbCount * 0x21;
    size: u64 = size_of(UsbHsRingHeader) + max_reports*size_of(UsbHsXferReport);
    size = (size+0xFFF) & ~0xFFF;
    return xx size;
}

/** cmif.h **/


cmifGetAlignedDataStart :: inline (data_words: *u32, base: *void) -> *void {
    data_start: intptr_t = xx ((cast(*u8)data_words - cast(*u8)base + 15) &~ 15);
    return cast(*u8)base + data_start;
}

cmifMakeRequest :: (base: *void, fmt: CmifRequestFormat) -> CmifRequest {
    // First of all, we need to figure out what size we need.
    actual_size := 16;
    if fmt.object_id {
        actual_size += size_of(CmifDomainInHeader) + fmt.num_objects*size_of(u32);
    }
    actual_size += size_of(CmifInHeader) + fmt.data_size;
    actual_size = (actual_size + 1) &~ 1; // hword-align
    out_pointer_size_table_offset := actual_size;
    out_pointer_size_table_size := fmt.num_out_auto_buffers + fmt.num_out_pointers;
    actual_size += size_of(u16)*out_pointer_size_table_size;
    num_data_words: u32 = xx ((actual_size + 3) / 4);

    req: CmifRequest;
    req.hipc = hipcMakeRequestInline(base,
        type             = xx (ifx fmt._context then CmifCommandType.RequestWithContext else CmifCommandType.Request),
        num_send_statics = fmt.num_in_auto_buffers  + fmt.num_in_pointers,
        num_send_buffers = fmt.num_in_auto_buffers  + fmt.num_in_buffers,
        num_recv_buffers = fmt.num_out_auto_buffers + fmt.num_out_buffers,
        num_exch_buffers = fmt.num_inout_buffers,
        num_data_words   = num_data_words,
        num_recv_statics = out_pointer_size_table_size + fmt.num_out_fixed_pointers,
        send_pid         = fmt.send_pid,
        num_copy_handles = fmt.num_handles,
        num_move_handles = 0,
    );

    hdr: *CmifInHeader;
    start := cmifGetAlignedDataStart(req.hipc.data_words, base);
    if fmt.object_id {
        domain_hdr := cast(*CmifDomainInHeader)start;
        payload_size := cast(u32) (size_of(CmifInHeader) + fmt.data_size);
        domain_hdr.* = CmifDomainInHeader.{
            type           = xx CmifDomainRequestType.SendMessage,
            num_in_objects = cast(u8)fmt.num_objects,
            data_size      = cast(u16)payload_size,
            object_id      = fmt.object_id,
            padding        = 0,
            token          = fmt._context,
        };
        hdr = cast(*CmifInHeader)(domain_hdr+1);
        req.objects = cast(*u32)(cast(*u8)hdr + payload_size);
    } else {
        hdr = cast(*CmifInHeader)start;
    }

    hdr.* = CmifInHeader.{
        magic      = CMIF_IN_HEADER_MAGIC,
        version    = xx (ifx fmt._context then 1 else 0),
        command_id = fmt.request_id,
        token      = ifx fmt.object_id then 0 else fmt._context,
    };

    req.data = hdr+1;
    req.out_pointer_sizes = cast(*u16)cast(*void)(cast(*u8)cast(*void)req.hipc.data_words + out_pointer_size_table_offset);
    req.server_pointer_size = fmt.server_pointer_size;

    return req;
}

cmifMakeControlRequest :: inline (base: *void, request_id: u32, size: u32) -> *void {
    actual_size: u32 = xx (16 + size_of(CmifInHeader) + size);
    hipc := hipcMakeRequestInline(base,
        type = xx CmifCommandType.Control,
        num_data_words = (actual_size + 3) / 4,
    );
    hdr := cast(*CmifInHeader)cmifGetAlignedDataStart(hipc.data_words, base);
    hdr.* = CmifInHeader.{
        magic      = CMIF_IN_HEADER_MAGIC,
        version    = 0,
        command_id = request_id,
        token      = 0,
    };
    return hdr+1;
}

cmifMakeCloseRequest :: inline (base: *void, object_id: u32) {
    if object_id {
        hipc := hipcMakeRequestInline(base,
            type           = xx CmifCommandType.Request,
            num_data_words = (16 + size_of(CmifDomainInHeader)) / 4,
        );
        domain_hdr := cast(*CmifDomainInHeader)cmifGetAlignedDataStart(hipc.data_words, base);
        domain_hdr.* = CmifDomainInHeader.{
            type      = xx CmifDomainRequestType.Close,
            object_id = object_id,
        };
    } else {
        hipcMakeRequestInline(base,
            type = xx CmifCommandType.Close,
        );
    }
}

cmifRequestInBuffer :: inline (req: *CmifRequest, buffer: [] void, mode: HipcBufferMode) {
    req.hipc.send_buffers.* = hipcMakeBuffer(buffer, mode);
    req.hipc.send_buffers += 1;
}

cmifRequestOutBuffer :: inline (req: *CmifRequest, buffer: [] void, mode: HipcBufferMode) {
    req.hipc.recv_buffers.* = hipcMakeBuffer(buffer, mode);
    req.hipc.recv_buffers  += 1;
}

cmifRequestInOutBuffer :: inline (req: *CmifRequest, buffer: [] void, mode: HipcBufferMode) {
    req.hipc.exch_buffers.* = hipcMakeBuffer(buffer, mode);
    req.hipc.exch_buffers  += 1;
}

cmifRequestInPointer :: inline (req: *CmifRequest, buffer: [] void) {
    req.hipc.send_statics.*  = hipcMakeSendStatic(buffer, xx req.cur_in_ptr_id);
    req.hipc.send_statics   += 1;
    req.cur_in_ptr_id       += 1;
    req.server_pointer_size -= xx buffer.count;
}

cmifRequestOutFixedPointer :: inline (req: *CmifRequest, buffer: [] void) {
    req.hipc.recv_list.*     = hipcMakeRecvStatic(buffer);
    req.hipc.recv_list      += 1;
    req.server_pointer_size -= xx buffer.count;
}

cmifRequestOutPointer :: inline (req: *CmifRequest, buffer: [] void) {
    cmifRequestOutFixedPointer(req, buffer);
    req.out_pointer_sizes.* = xx buffer.count;
    req.out_pointer_sizes  += 1;
}

cmifRequestInAutoBuffer :: inline (req: *CmifRequest, buffer: [] void, mode: HipcBufferMode) {
    if req.server_pointer_size && buffer.count <= req.server_pointer_size {
        cmifRequestInPointer(req, buffer);
        cmifRequestInBuffer(req, .[], mode);
    } else {
        cmifRequestInPointer(req, .[]);
        cmifRequestInBuffer(req, buffer, mode);
    }
}

cmifRequestOutAutoBuffer :: inline (req: *CmifRequest, buffer: [] void, mode: HipcBufferMode) {
    if req.server_pointer_size && buffer.count <= req.server_pointer_size {
        cmifRequestOutPointer(req, buffer);
        cmifRequestOutBuffer(req, .[], mode);
    } else {
        cmifRequestOutPointer(req, .[]);
        cmifRequestOutBuffer(req, buffer, mode);
    }
}

cmifRequestObject :: inline (req: *CmifRequest, object_id: u32) {
    req.objects.* = object_id;
    req.objects  += 1;
}

cmifRequestHandle :: inline (req: *CmifRequest, handle: Handle) {
    req.hipc.copy_handles.* = handle;
    req.hipc.copy_handles  += 1;
}

cmifParseResponse :: (res: *CmifResponse, base: *void, is_domain: bool, size: u32) -> Result {
    hipc  := hipcParseResponse(base);
    start := cmifGetAlignedDataStart(hipc.data_words, base);

    hdr: *CmifOutHeader;
    objects: *u32;
    if is_domain {
        domain_hdr := cast(*CmifDomainOutHeader)start;
        hdr = cast(*CmifOutHeader)(domain_hdr+1);
        objects = cast(*u32)(cast(*u8)hdr + size_of(CmifOutHeader) + size);
    }
    else {
        hdr = cast(*CmifOutHeader)start;
    }

    if hdr.magic != CMIF_OUT_HEADER_MAGIC {
        return MAKERESULT(Module.Libnx, LibnxError.InvalidCmifOutHeader);
    }
    if R_FAILED(hdr.result) {
        return hdr.result;
    }

    res.* = CmifResponse.{
        data         = hdr+1,
        objects      = objects,
        copy_handles = hipc.copy_handles,
        move_handles = hipc.move_handles,
    };

    return 0;
}

cmifResponseGetObject :: inline (res: *CmifResponse) -> u32 {
    result := res.objects.*;
    res.objects += 1;
    return result;
}

cmifResponseGetCopyHandle :: inline (res: *CmifResponse) -> Handle {
    result := res.copy_handles.*;
    res.copy_handles += 1;
    return result;
}

cmifResponseGetMoveHandle :: inline (res: *CmifResponse) -> Handle {
    result := res.move_handles.*;
    res.move_handles += 1;
    return result;
}

cmifConvertCurrentObjectToDomain :: (h: Handle, out_object_id: *u32) -> Result {
    cmifMakeControlRequest(armGetTls(), 0, 0);
    rc := svcSendSyncRequest(h);
    if R_SUCCEEDED(rc) {
        resp: CmifResponse;
        rc = cmifParseResponse(*resp, armGetTls(), false, size_of(u32));
        if R_SUCCEEDED(rc) && out_object_id {
            out_object_id.* = (cast(*u32)resp.data).*;
        }
    }
    return rc;
}

cmifCopyFromCurrentDomain :: (h: Handle, object_id: u32, out_h: *Handle) -> Result {
    raw := cmifMakeControlRequest(armGetTls(), 1, size_of(u32));
    (cast(*u32)raw).* = object_id;
    rc := svcSendSyncRequest(h);
    if R_SUCCEEDED(rc) {
        resp: CmifResponse;
        rc = cmifParseResponse(*resp, armGetTls(), false, 0);
        if R_SUCCEEDED(rc) && out_h {
            out_h.* = resp.move_handles[0];
        }
    }
    return rc;
}

cmifCloneCurrentObject :: (h: Handle, out_h: *Handle) -> Result {
    cmifMakeControlRequest(armGetTls(), 2, 0);
    rc := svcSendSyncRequest(h);
    if R_SUCCEEDED(rc) {
        resp: CmifResponse;
        rc = cmifParseResponse(*resp, armGetTls(), false, 0);
        if R_SUCCEEDED(rc) && out_h {
            out_h.* = resp.move_handles[0];
        }
    }
    return rc;
}

cmifQueryPointerBufferSize :: (h: Handle, out_size: *u16) -> Result {
    cmifMakeControlRequest(armGetTls(), 3, 0);
    rc := svcSendSyncRequest(h);
    if R_SUCCEEDED(rc) {
        resp: CmifResponse;
        rc = cmifParseResponse(*resp, armGetTls(), false, size_of(u16));
        if R_SUCCEEDED(rc) && out_size {
            out_size.* = (cast(*u16)resp.data).*;
        }
    }
    return rc;
}

cmifCloneCurrentObjectEx :: (h: Handle, tag: u32, out_h: *Handle) -> Result {
    raw := cmifMakeControlRequest(armGetTls(), 4, size_of(u32));
    (cast(*u32)raw).* = tag;
    rc := svcSendSyncRequest(h);
    if R_SUCCEEDED(rc) {
        resp: CmifResponse;
        rc = cmifParseResponse(*resp, armGetTls(), false, 0);
        if R_SUCCEEDED(rc) && out_h {
            out_h.* = resp.move_handles[0];
        }
    }
    return rc;
}

/** hipc.h **/

HIPC_AUTO_RECV_STATIC :: U8_MAX;
HIPC_RESPONSE_NO_PID  :: U32_MAX;

hipcMakeSendStatic :: inline (buffer: [] void, index: u8) -> HipcStaticDescriptor {
    result: HipcStaticDescriptor;
    result.set_index        (*result, index);
    result.set_address_high (*result, cast(u32)((cast(uintptr_t)buffer.data) >> 36));
    result.set_address_mid  (*result, cast(u32)((cast(uintptr_t)buffer.data) >> 32));
    result.set_size         (*result, cast(u32)buffer.count);
    result.address_low      =         cast(u32)(cast(uintptr_t)buffer.data);
    return result;
}

hipcMakeBuffer :: inline (buffer: [] void, mode: HipcBufferMode) -> HipcBufferDescriptor {
    result: HipcBufferDescriptor;
    result.size_low         =         cast(u32)buffer.count;
    result.address_low      =         cast(u32)(cast(uintptr_t)buffer.data);
    result.set_mode         (*result, xx mode);
    result.set_address_high (*result, cast(u32)((cast(uintptr_t)buffer.data) >> 36));
    result.set_size_high    (*result, (cast(u32) buffer.count) >> 32);
    result.set_address_mid  (*result, cast(u32)((cast(uintptr_t)buffer.data) >> 32));
    return result;
}

hipcMakeRecvStatic :: inline (buffer: [] void) -> HipcRecvListEntry {
    result: HipcRecvListEntry;
    result.address_low     =         cast(u32)((cast(uintptr_t)buffer.data));
    result.set_address_high(*result, cast(u32)((cast(uintptr_t)buffer.data) >> 32));
    result.set_size        (*result, cast(u32)buffer.count);
    return result;
}

hipcGetStaticAddress :: inline (desc: HipcStaticDescriptor) -> *void {
    result: uintptr_t = desc.address_low;

    result |= desc.get_address_mid(desc)  << 32;
    result |= desc.get_address_high(desc) << 36;

    return cast(*void) result;
}

hipcGetStaticSize :: inline (desc: HipcStaticDescriptor) -> size_t {
    return desc.get_size(desc);
}

hipcGetBufferAddress :: inline (desc: HipcBufferDescriptor) -> *void {
    result: uintptr_t = desc.address_low;

    result |= desc.get_address_mid(desc)  << 32;
    result |= desc.get_address_high(desc) << 36;

    return cast(*void) result;
}

hipcGetBufferSize :: inline (desc: HipcBufferDescriptor) -> size_t {
    return desc.size_low | ((cast(size_t)desc.get_size_high(desc)) << 32);
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

    temp_header: HipcHeader;
    temp_header.set_type               (*temp_header, meta.type);
    temp_header.set_num_send_statics   (*temp_header, meta.num_send_statics);
    temp_header.set_num_send_buffers   (*temp_header, meta.num_send_buffers);
    temp_header.set_num_recv_buffers   (*temp_header, meta.num_recv_buffers);
    temp_header.set_num_exch_buffers   (*temp_header, meta.num_exch_buffers);
    temp_header.set_num_data_words     (*temp_header, meta.num_data_words);
    temp_header.set_recv_static_mode   (*temp_header, ifx meta.num_recv_statics then (ifx meta.num_recv_statics != HIPC_AUTO_RECV_STATIC then 2 + meta.num_recv_statics else 2) else 0);
    temp_header.set_padding            (*temp_header, 0);
    temp_header.set_recv_list_offset   (*temp_header, 0);
    temp_header.set_has_special_header (*temp_header, xx has_special_header);
    hdr.* = temp_header;

    // Write special header
    if has_special_header {
        sphdr: *HipcSpecialHeader = xx base;
        base = sphdr+1;
        temp_s_header: HipcSpecialHeader;
        temp_s_header.set_send_pid         (*temp_s_header, meta.send_pid);
        temp_s_header.set_num_copy_handles (*temp_s_header, meta.num_copy_handles);
        temp_s_header.set_num_move_handles (*temp_s_header, meta.num_move_handles);
        sphdr.* = temp_s_header;
        if meta.send_pid  base = (cast(*u8)base) + size_of(u64);
    }

    // Calculate layout
    return hipcCalcRequestLayout(meta, base);
}

hipcMakeRequestInline :: inline (
    base: *void,

    // Mirroring HipcMetadata
    type:             u32 = 0,
    num_send_statics: u32 = 0,
    num_send_buffers: u32 = 0,
    num_recv_buffers: u32 = 0,
    num_exch_buffers: u32 = 0,
    num_data_words:   u32 = 0,
    num_recv_statics: u32 = 0, // also accepts HIPC_AUTO_RECV_STATIC
    send_pid:         u32 = 0,
    num_copy_handles: u32 = 0,
    num_move_handles: u32 = 0
) -> HipcRequest {
    return hipcMakeRequest(
        base,
        HipcMetadata.{
            type             = xx type,
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
    memcpy(*hdr, base, size_of(type_of(hdr)));
    base = (cast(*u8)base) + size_of(type_of(hdr));
    num_recv_statics: u32 = 0;
    pid: u64 = 0;

    // Parse recv static mode
    recv_static_mode := hdr.get_recv_static_mode(hdr);
    if recv_static_mode {
        if      recv_static_mode == 2  num_recv_statics = HIPC_AUTO_RECV_STATIC;
        else if recv_static_mode >  2  num_recv_statics = recv_static_mode - 2;
    }

    // Parse special header
    sphdr: HipcSpecialHeader;
    if hdr.get_has_special_header(hdr) {
        memcpy(*sphdr, base, size_of(type_of(sphdr)));
        base = (cast(*u8)base) + size_of(type_of(sphdr));

        // Read PID descriptor
        if sphdr.get_send_pid(sphdr) {
            pid = (cast(*u64)base).*;
            base = (cast(*u8)base) + size_of(u64);
        }
    }

    meta := HipcMetadata.{
        type             = hdr.get_type(hdr),
        num_send_statics = hdr.get_num_send_statics(hdr),
        num_send_buffers = hdr.get_num_send_buffers(hdr),
        num_recv_buffers = hdr.get_num_recv_buffers(hdr),
        num_exch_buffers = hdr.get_num_exch_buffers(hdr),
        num_data_words   = hdr.get_num_data_words(hdr),
        num_recv_statics = num_recv_statics,
        send_pid         = sphdr.get_send_pid(sphdr),
        num_copy_handles = sphdr.get_num_copy_handles(sphdr),
        num_move_handles = sphdr.get_num_move_handles(sphdr),
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
    memcpy(*hdr, base, size_of(type_of(hdr)));
    base = (cast(*u8)base) + size_of(type_of(hdr));

    // Initialize response
    response: HipcResponse;
    response.num_statics = hdr.get_num_send_statics(hdr);
    response.num_data_words = hdr.get_num_data_words(hdr);
    response.pid = HIPC_RESPONSE_NO_PID;

    // Parse special header
    if hdr.get_has_special_header(hdr) {
        sphdr: HipcSpecialHeader;
        memcpy(*sphdr, base, size_of(type_of(sphdr)));
        base = (cast(*u8)base) + size_of(type_of(sphdr));

        // Update response
        response.num_copy_handles = sphdr.get_num_copy_handles(sphdr);
        response.num_move_handles = sphdr.get_num_move_handles(sphdr);

        // Parse PID descriptor
        if sphdr.get_send_pid(sphdr) {
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

/** service.h **/

/**
 * @brief Returns whether a service has been initialized.
 * @param[in] s Service object.
 * @return true if initialized.
 */
serviceIsActive :: inline (s: *Service) -> bool {
    return s.session != INVALID_HANDLE;
}

/**
 * @brief Returns whether a service is overriden in the homebrew environment.
 * @param[in] s Service object.
 * @return true if overriden.
 */
serviceIsOverride :: inline (s: *Service) -> bool {
    return serviceIsActive(s) && !s.own_handle && !s.object_id;
}

/**
 * @brief Returns whether a service is a domain.
 * @param[in] s Service object.
 * @return true if a domain.
 */
serviceIsDomain :: inline (s: *Service) -> bool {
    return serviceIsActive(s) && s.own_handle && s.object_id;
}

/**
 * @brief Returns whether a service is a domain subservice.
 * @param[in] s Service object.
 * @return true if a domain subservice.
 */
serviceIsDomainSubservice :: inline (s: *Service) -> bool {
    return serviceIsActive(s) && !s.own_handle && s.object_id;
}

/**
 * @brief For a domain/domain subservice, return the associated object ID.
 * @param[in] s Service object, necessarily a domain or domain subservice.
 * @return The object ID.
 */
serviceGetObjectId :: inline (s: *Service) -> u32 {
    return s.object_id;
}

/**
 * @brief Creates a service object from an IPC session handle.
 * @param[out] s Service object.
 * @param[in] h IPC session handle.
 */
serviceCreate :: inline (s: *Service, h: Handle) {
    s.session = h;
    s.own_handle = 1;
    s.object_id = 0;
    s.pointer_buffer_size = 0;
    cmifQueryPointerBufferSize(h, *s.pointer_buffer_size);
}

/**
 * @brief Creates a non-domain subservice object from a parent service.
 * @param[out] s Service object.
 * @param[in] parent Parent service.
 * @param[in] h IPC session handle for this subservice.
 */
serviceCreateNonDomainSubservice :: inline (s: *Service, parent: *Service, h: Handle) {
    if (h != INVALID_HANDLE) {
        s.session = h;
        s.own_handle = 1;
        s.object_id = 0;
        s.pointer_buffer_size = parent.pointer_buffer_size;
    } else {
        s.* = Service.{};
    }
}

/**
 * @brief Creates a domain subservice object from a parent service.
 * @param[out] s Service object.
 * @param[in] parent Parent service, necessarily a domain or domain subservice.
 * @param[in] object_id Object ID for this subservice.
 */
serviceCreateDomainSubservice :: inline (s: *Service, parent: *Service, object_id: u32) {
    if (object_id != 0) {
        s.session = parent.session;
        s.own_handle = 0;
        s.object_id = object_id;
        s.pointer_buffer_size = parent.pointer_buffer_size;
    } else {
        s.* = Service.{};
    }
}

/**
 * @brief Hints the compiler that a service will always contain a domain object.
 * @param[in] _s Service object.
 */
// @TODO
// #define serviceAssumeDomain(_s) do {
//     if (!(_s)->object_id)
//         __builtin_unreachable();
// } while(0)

/**
 * @brief Closes a service.
 * @param[in] s Service object.
 */
serviceClose :: inline (s: *Service) {
    // #if defined(NX_SERVICE_ASSUME_NON_DOMAIN)
    //     if (s.object_id)
    //         __builtin_unreachable();
    // #endif

    if s.own_handle || s.object_id {
        cmifMakeCloseRequest(armGetTls(), ifx s.own_handle then 0 else s.object_id);
        svcSendSyncRequest(s.session);
        if s.own_handle  svcCloseHandle(s.session);
    }
    s.* = Service.{};
}

/**
 * @brief Clones a service.
 * @param[in] s Service object.
 * @param[out] out_s Output service object.
 */
serviceClone :: inline (s: *Service, out_s: *Service) -> Result {
    // #if defined(NX_SERVICE_ASSUME_NON_DOMAIN)
    //     if (s.object_id)
    //         __builtin_unreachable();
    // #endif

    out_s.session             = 0;
    out_s.own_handle          = 1;
    out_s.object_id           = s.object_id;
    out_s.pointer_buffer_size = s.pointer_buffer_size;
    return cmifCloneCurrentObject(s.session, *out_s.session);
}

/**
 * @brief Clones a service with a session manager tag.
 * @param[in] s Service object.
 * @param[in] tag Session manager tag (unused in current official server code)
 * @param[out] out_s Output service object.
 */
serviceCloneEx :: inline (s: *Service, tag: u32, out_s: *Service) -> Result {
    // #if defined(NX_SERVICE_ASSUME_NON_DOMAIN)
    //     if (s.object_id)
    //         __builtin_unreachable();
    // #endif

    out_s.session             = 0;
    out_s.own_handle          = 1;
    out_s.object_id           = s.object_id;
    out_s.pointer_buffer_size = s.pointer_buffer_size;
    return cmifCloneCurrentObjectEx(s.session, tag, *out_s.session);
}

/**
 * @brief Converts a regular service to a domain.
 * @param[in] s Service object.
 * @return Result code.
 */
serviceConvertToDomain :: inline (s: *Service) -> Result {
    if !s.own_handle {
        // For overridden services, create a clone first.
        rc := cmifCloneCurrentObjectEx(s.session, 0, *s.session);
        if R_FAILED(rc) {
            return rc;
        }
        s.own_handle = 1;
    }

    return cmifConvertCurrentObjectToDomain(s.session, *s.object_id);
}

_serviceRequestFormatProcessBuffer :: inline (fmt: *CmifRequestFormat, attr: SfBufferAttr) {
    if !attr  return;
    is_in  := (attr & SfBufferAttr.In)  != 0;
    is_out := (attr & SfBufferAttr.Out) != 0;

    if (attr & SfBufferAttr.HipcAutoSelect) {
        if is_in   fmt.num_in_auto_buffers  += 1;
        if is_out  fmt.num_out_auto_buffers += 1;
    } else if (attr & SfBufferAttr.HipcPointer) {
        if is_in   fmt.num_in_pointers += 1;
        if is_out {
            if (attr & SfBufferAttr.FixedSize)  fmt.num_out_fixed_pointers += 1;
            else                                fmt.num_out_pointers       += 1;
        }
    } else if (attr & SfBufferAttr.HipcMapAlias) {
        if      is_in && is_out  fmt.num_inout_buffers += 1;
        else if is_in            fmt.num_in_buffers    += 1;
        else if is_out           fmt.num_out_buffers   += 1;
    }
}

_serviceRequestProcessBuffer :: inline (req: *CmifRequest, buf: *SfBuffer, attr: SfBufferAttr) {
    if !attr  return;
    is_in  := (attr & SfBufferAttr.In)  != 0;
    is_out := (attr & SfBufferAttr.Out) != 0;

    buf_array := to_array(buf);

    if (attr & SfBufferAttr.HipcAutoSelect) {
        mode := HipcBufferMode.Normal;
        if (attr & SfBufferAttr.HipcMapTransferAllowsNonSecure) {
            mode = HipcBufferMode.NonSecure;
        }
        if (attr & SfBufferAttr.HipcMapTransferAllowsNonDevice) {
            mode = HipcBufferMode.NonDevice;
        }
        if is_in   cmifRequestInAutoBuffer (req, buf_array, mode);
        if is_out  cmifRequestOutAutoBuffer(req, buf_array, mode);
    } else if (attr & SfBufferAttr.HipcPointer) {
        if is_in  cmifRequestInPointer(req, buf_array);
        if is_out {
            if (attr & SfBufferAttr.FixedSize) {
                cmifRequestOutFixedPointer(req, buf_array);
            }
            else {
                cmifRequestOutPointer(req, buf_array);
            }
        }
    } else if (attr & SfBufferAttr.HipcMapAlias) {
        mode := HipcBufferMode.Normal;
        if (attr & SfBufferAttr.HipcMapTransferAllowsNonSecure) {
            mode = HipcBufferMode.NonSecure;
        }
        if (attr & SfBufferAttr.HipcMapTransferAllowsNonDevice) {
            mode = HipcBufferMode.NonDevice;
        }

        if      is_in && is_out  cmifRequestInOutBuffer(req, buf_array, mode);
        else if is_in            cmifRequestInBuffer   (req, buf_array, mode);
        else if is_out           cmifRequestOutBuffer  (req, buf_array, mode);
    }
}

 serviceMakeRequest :: inline (
    s: *Service, request_id: u32, _context: u32, data_size: u32, send_pid: bool,
    buffer_attrs: SfBufferAttrs, buffers: *SfBuffer,
    objects: [] *Service,
    handles: [] Handle
) -> *void {
    // #if defined(NX_SERVICE_ASSUME_NON_DOMAIN)
    //     if (s.object_id)
    //         __builtin_unreachable();
    // #endif

    fmt: CmifRequestFormat;
    fmt.object_id           = s.object_id;
    fmt.request_id          = request_id;
    fmt._context            = _context;
    fmt.data_size           = data_size;
    fmt.server_pointer_size = s.pointer_buffer_size;
    fmt.num_objects         = xx objects.count;
    fmt.num_handles         = xx handles.count;
    fmt.send_pid            = xx send_pid;

    _serviceRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr0);
    _serviceRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr1);
    _serviceRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr2);
    _serviceRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr3);
    _serviceRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr4);
    _serviceRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr5);
    _serviceRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr6);
    _serviceRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr7);

    req := cmifMakeRequest(armGetTls(), fmt);

    if s.object_id {// TODO: Check behavior of input objects in non-domain sessions
        for objects {
            cmifRequestObject(*req, it.object_id);
        }
    }

    for handles {
        cmifRequestHandle(*req, it);
    }

    _serviceRequestProcessBuffer(*req, *buffers[0], xx buffer_attrs.attr0);
    _serviceRequestProcessBuffer(*req, *buffers[1], xx buffer_attrs.attr1);
    _serviceRequestProcessBuffer(*req, *buffers[2], xx buffer_attrs.attr2);
    _serviceRequestProcessBuffer(*req, *buffers[3], xx buffer_attrs.attr3);
    _serviceRequestProcessBuffer(*req, *buffers[4], xx buffer_attrs.attr4);
    _serviceRequestProcessBuffer(*req, *buffers[5], xx buffer_attrs.attr5);
    _serviceRequestProcessBuffer(*req, *buffers[6], xx buffer_attrs.attr6);
    _serviceRequestProcessBuffer(*req, *buffers[7], xx buffer_attrs.attr7);

    return req.data;
}

_serviceResponseGetHandle :: inline (res: *CmifResponse, type: SfOutHandleAttr, out: *Handle) {
    if #complete type == {
        case .None;
        case .HipcCopy;
            out.* = cmifResponseGetCopyHandle(res);
        case .HipcMove;
            out.* = cmifResponseGetMoveHandle(res);
    }
}

serviceParseResponse :: (
    s: *Service, out_size: u32, out_data: **void,
    out_objects: [] Service,
    out_handle_attrs: SfOutHandleAttrs, out_handles: [] Handle
) -> Result {
    // #if defined(NX_SERVICE_ASSUME_NON_DOMAIN)
    //     if (s.object_id)
    //         __builtin_unreachable();
    // #endif

    res: CmifResponse;
    is_domain := s.object_id != 0;
    rc := cmifParseResponse(*res, armGetTls(), is_domain, out_size);
    if R_FAILED(rc)  return rc;

    if out_size  out_data.* = res.data;

    for * out_objects {
        if is_domain {
            serviceCreateDomainSubservice(it, s, cmifResponseGetObject(*res));
        }
        else { // Output objects are marshalled as move handles at the beginning of the list.
            serviceCreateNonDomainSubservice(it, s, cmifResponseGetMoveHandle(*res));
        }
    }

    _serviceResponseGetHandle(*res, out_handle_attrs.attr0, *out_handles[0]);
    _serviceResponseGetHandle(*res, out_handle_attrs.attr1, *out_handles[1]);
    _serviceResponseGetHandle(*res, out_handle_attrs.attr2, *out_handles[2]);
    _serviceResponseGetHandle(*res, out_handle_attrs.attr3, *out_handles[3]);
    _serviceResponseGetHandle(*res, out_handle_attrs.attr4, *out_handles[4]);
    _serviceResponseGetHandle(*res, out_handle_attrs.attr5, *out_handles[5]);
    _serviceResponseGetHandle(*res, out_handle_attrs.attr6, *out_handles[6]);
    _serviceResponseGetHandle(*res, out_handle_attrs.attr7, *out_handles[7]);

    return 0;
}

serviceDispatchImpl :: (
    s: *Service, request_id: u32,
    in_data: *void, in_data_size: int,
    out_data: *void, out_data_size: int,

    // Intended to mostly match SfDispatchParams
    target_session:   Handle,
    _context:         u32,
    buffer_attrs:     SfBufferAttrs,
    buffers:          [] SfBuffer,
    in_send_pid:      bool,
    in_objects:       [] *Service,
    in_handles:       [] Handle,
    out_objects:      [] Service,
    out_handle_attrs: SfOutHandleAttrs,
    out_handles:      [] Handle
) -> Result {
    // Make a copy of the service struct, so that the compiler can assume that it won't be modified by function calls.
    // @TODO: This was the original comment. Is this needed in a Jai version?
    srv := s.*;

    in := serviceMakeRequest(
        *srv, request_id, _context,
        xx in_data_size, in_send_pid,
        buffer_attrs, buffers.data,
        in_objects,
        in_handles
    );

    if in_data_size {
        memcpy(in, in_data, xx in_data_size);
    }

    rc := svcSendSyncRequest(ifx target_session == INVALID_HANDLE then s.session else target_session);
    if R_SUCCEEDED(rc) {
        out: *void;
        rc = serviceParseResponse(
            *srv,
            xx out_data_size, *out,
            out_objects,
            out_handle_attrs, out_handles
        );

        if R_SUCCEEDED(rc) && out_data_size {
            memcpy(out_data, out, out_data_size);
        }
    }

    return rc;
}

serviceDispatch :: inline (
    s: *Service, request_id: u32,

    // Intended to mostly match SfDispatchParams
    target_session:   Handle           = 0,
    _context:         u32              = 0,
    buffer_attrs:     SfBufferAttrs    = .{},
    buffers:          [] SfBuffer      = .[],
    in_send_pid:      bool             = false,
    in_objects:       [] *Service      = .[],
    in_handles:       [] Handle        = .[],
    out_objects:      [] Service       = .[],
    out_handle_attrs: SfOutHandleAttrs = .{},
    out_handles:      [] Handle        = .[]
) -> Result {
    return serviceDispatchImpl(
        s, request_id, null, 0, null, 0,
        target_session   = target_session,
        _context         = _context,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_objects       = in_objects,
        in_handles       = in_handles,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

serviceDispatchIn :: inline (
    s: *Service, request_id: u32,
    in_data: *$I,

    // Intended to mostly match SfDispatchParams
    target_session:   Handle           = 0,
    _context:         u32              = 0,
    buffer_attrs:     SfBufferAttrs    = .{},
    buffers:          [] SfBuffer      = .[],
    in_send_pid:      bool             = false,
    in_objects:       [] *Service      = .[],
    in_handles:       [] Handle        = .[],
    out_objects:      [] Service       = .[],
    out_handle_attrs: SfOutHandleAttrs = .{},
    out_handles:      [] Handle        = .[]
) -> Result {
    return serviceDispatchImpl(
        s, request_id, in_data, size_of(I), null, 0,
        target_session   = target_session,
        _context         = _context,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_objects       = in_objects,
        in_handles       = in_handles,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

serviceDispatchOut :: inline (
    s: *Service, request_id: u32,
    out_data: *$O,

    // Intended to mostly match SfDispatchParams
    target_session:   Handle           = 0,
    _context:         u32              = 0,
    buffer_attrs:     SfBufferAttrs    = .{},
    buffers:          [] SfBuffer      = .[],
    in_send_pid:      bool             = false,
    in_objects:       [] *Service      = .[],
    in_handles:       [] Handle        = .[],
    out_objects:      [] Service       = .[],
    out_handle_attrs: SfOutHandleAttrs = .{},
    out_handles:      [] Handle        = .[]
) -> Result {
    return serviceDispatchImpl(
        s, request_id, null, 0, out_data, size_of(O),
        target_session   = target_session,
        _context         = _context,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_objects       = in_objects,
        in_handles       = in_handles,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

serviceDispatchInOut :: inline (
    s: *Service, request_id: u32,
    in_data: *$I,
    out_data: *$O,

    // Intended to mostly match SfDispatchParams
    target_session:   Handle           = 0,
    _context:         u32              = 0,
    buffer_attrs:     SfBufferAttrs    = .{},
    buffers:          [] SfBuffer      = .[],
    in_send_pid:      bool             = false,
    in_objects:       [] *Service      = .[],
    in_handles:       [] Handle        = .[],
    out_objects:      [] Service       = .[],
    out_handle_attrs: SfOutHandleAttrs = .{},
    out_handles:      [] Handle        = .[]
) -> Result {
    return serviceDispatchImpl(
        s, request_id,
        in_data, size_of(I),
        out_data, size_of(O),
        target_session   = target_session,
        _context         = _context,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_objects       = in_objects,
        in_handles       = in_handles,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

/** sessionmgr.h **/

sessionmgrGetClientSession :: inline (mgr: *SessionMgr, slot: s32) -> Handle {
    return mgr.sessions[slot];
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
    hipcMakeRequestInline(armGetTls(), type = xx TipcCommandType.Close);
    svcSendSyncRequest(s.session);
    svcCloseHandle(s.session);
    s.* = TipcService.{};
}

tipcRequestInBuffer :: inline (req: *HipcRequest, buffer: [] void, mode: HipcBufferMode) {
    req.send_buffers.* = hipcMakeBuffer(buffer, mode);
    req.send_buffers  += 1;
}

tipcRequestOutBuffer :: inline (req: *HipcRequest, buffer: [] void, mode: HipcBufferMode) {
    req.recv_buffers.* = hipcMakeBuffer(buffer, mode);
    req.recv_buffers  += 1;
}

tipcRequestInOutBuffer :: inline (req: *HipcRequest, buffer: [] void, mode: HipcBufferMode) {
    req.exch_buffers.* = hipcMakeBuffer(buffer, mode);
    req.exch_buffers  += 1;
}

tipcRequestHandle :: inline (req: *HipcRequest, handle: Handle) {
    req.copy_handles.* = handle;
    req.copy_handles  += 1;
}

_tipcRequestFormatProcessBuffer :: (fmt: *TipcRequestFormat, attr: SfBufferAttr) {
    if !attr return;
    is_in  := (attr & SfBufferAttr.In)  != 0;
    is_out := (attr & SfBufferAttr.Out) != 0;

    if attr & SfBufferAttr.HipcMapAlias {
        if      is_in && is_out  fmt.num_inout_buffers += 1;
        else if is_in            fmt.num_in_buffers    += 1;
        else if is_out           fmt.num_out_buffers   += 1;
    }
}

_tipcRequestProcessBuffer :: (req: *HipcRequest, buf: *SfBuffer, attr: SfBufferAttr) {
    if !attr return;
    is_in  := (attr & SfBufferAttr.In);
    is_out := (attr & SfBufferAttr.Out);

    if attr & SfBufferAttr.HipcMapAlias {
        mode := HipcBufferMode.Normal;
        if attr & SfBufferAttr.HipcMapTransferAllowsNonSecure {
            mode = .NonSecure;
        }
        if attr & SfBufferAttr.HipcMapTransferAllowsNonDevice {
            mode = .NonDevice;
        }

        if      is_in && is_out  tipcRequestInOutBuffer(req, to_array(buf), mode);
        else if is_in            tipcRequestInBuffer   (req, to_array(buf), mode);
        else if is_out           tipcRequestOutBuffer  (req, to_array(buf), mode);
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
    fmt.send_pid = xx send_pid;

    _tipcRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr0);
    _tipcRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr1);
    _tipcRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr2);
    _tipcRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr3);
    _tipcRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr4);
    _tipcRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr5);
    _tipcRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr6);
    _tipcRequestFormatProcessBuffer(*fmt, xx buffer_attrs.attr7);

    req := hipcMakeRequestInline(armGetTls(),
        type             = xx fmt.request_id,
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

    _tipcRequestProcessBuffer(*req, *buffers[0], xx buffer_attrs.attr0);
    _tipcRequestProcessBuffer(*req, *buffers[1], xx buffer_attrs.attr1);
    _tipcRequestProcessBuffer(*req, *buffers[2], xx buffer_attrs.attr2);
    _tipcRequestProcessBuffer(*req, *buffers[3], xx buffer_attrs.attr3);
    _tipcRequestProcessBuffer(*req, *buffers[4], xx buffer_attrs.attr4);
    _tipcRequestProcessBuffer(*req, *buffers[5], xx buffer_attrs.attr5);
    _tipcRequestProcessBuffer(*req, *buffers[6], xx buffer_attrs.attr6);
    _tipcRequestProcessBuffer(*req, *buffers[7], xx buffer_attrs.attr7);

    return req.data_words;
}

tipcResponseGetCopyHandle :: inline (res: *HipcResponse) -> Handle {
    result := res.copy_handles.*;
    res.copy_handles += 1;
    return result;
}

tipcResponseGetMoveHandle :: inline(res: *HipcResponse) -> Handle {
    result := res.move_handles.*;
    res.move_handles += 1;
    return result;
}

_tipcResponseGetHandle :: (res: *HipcResponse, type: SfOutHandleAttr, out: *Handle) {
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
    out_handle_attrs: SfOutHandleAttrs, out_handles: [] Handle
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
    in_data: *void, in_data_size: int,
    out_data: *void, out_data_size: int,

    buffer_attrs:     SfBufferAttrs,
    buffers:          [] SfBuffer,
    in_send_pid:      bool,
    in_handles:       [] Handle,
    out_objects:      [] TipcService,
    out_handle_attrs: SfOutHandleAttrs,
    out_handles:      [] Handle
) -> Result {
    in := tipcMakeRequest(request_id,
        xx in_data_size, in_send_pid,
        buffer_attrs, buffers.data,
        in_handles);

    if in_data_size  memcpy(in, in_data, xx in_data_size);

    rc := svcSendSyncRequest(s.session);
    if R_SUCCEEDED(rc) {
        out: *void;
        rc = tipcParseResponse(xx out_data_size, *out,
            out_objects,
            out_handle_attrs, out_handles);

        if R_SUCCEEDED(rc) && out_data && out_data_size {
            memcpy(out_data, out, out_data_size);
        }
    }

    return rc;
}

// @Crappy: I was trying to replicate the experience the C headers were going for, but this seems kind of messy.
//          They were doing named optional parameters in C by using the SfDispatchParams struct and macro magic.

tipcDispatch :: inline (
    s: *TipcService, request_id: u32,

    buffer_attrs:     SfBufferAttrs    = .{},
    buffers:          [] SfBuffer      = .[],
    in_send_pid:      bool             = false,
    in_handles:       [] Handle        = .[],
    out_objects:      [] TipcService   = .[],
    out_handle_attrs: SfOutHandleAttrs = .{},
    out_handles:      [] Handle        = .[]
) -> Result {
    return tipcDispatchImpl(
        s, request_id, null, 0, null, 0,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_handles       = in_handles,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

tipcDispatchIn :: inline (
    s: *TipcService, request_id: u32,
    in_data: *$I,

    buffer_attrs:     SfBufferAttrs    = .{},
    buffers:          [] SfBuffer      = .[],
    in_send_pid:      bool             = false,
    in_handles:       [] Handle        = .[],
    out_objects:      [] TipcService   = .[],
    out_handle_attrs: SfOutHandleAttrs = .{},
    out_handles:      [] Handle        = .[]
) -> Result {
    return tipcDispatchImpl(
        s, request_id, in_data, size_of(I), null, 0,
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_handles       = in_handles,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

tipcDispatchOut :: inline (
    s: *TipcService, request_id: u32,
    out_data: *$O,

    buffer_attrs:     SfBufferAttrs    = .{},
    buffers:          [] SfBuffer      = .[],
    in_send_pid:      bool             = false,
    in_handles:       [] Handle        = .[],
    out_objects:      [] TipcService   = .[],
    out_handle_attrs: SfOutHandleAttrs = .{},
    out_handles:      [] Handle        = .[]
) -> Result {
    return tipcDispatchImpl(
        s, request_id, null, 0, out_data, size_of(O),
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_handles       = in_handles,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

tipcDispatchInOut :: inline (
    s: *TipcService, request_id: u32,
    in_data: *$I,
    out_data: *$O,

    buffer_attrs:     SfBufferAttrs    = .{},
    buffers:          [] SfBuffer      = .[],
    in_send_pid:      bool             = false,
    in_handles:       [] Handle        = .[],
    out_objects:      [] TipcService   = .[],
    out_handle_attrs: SfOutHandleAttrs = .{},
    out_handles:      [] Handle        = .[]
) -> Result {
    return tipcDispatchImpl(
        s, request_id, in_data, size_of(I), out_data, size_of(O),
        buffer_attrs     = buffer_attrs,
        buffers          = buffers,
        in_send_pid      = in_send_pid,
        in_handles       = in_handles,
        out_objects      = out_objects,
        out_handle_attrs = out_handle_attrs,
        out_handles      = out_handles,
    );
}

#scope_module

#import "Basic";
#import "Bitfields";
#import "Math";
#import "POSIX";
#import "Socket";