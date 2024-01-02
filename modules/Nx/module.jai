// Bindings for libnx, devkitPro's  Switch homebrew userland support library.
// This file contains all the bindings that had to be manually written - mainly for inline functions and such.

// Load the file that contains all the stuff Bindings_Generator was able to do.
// It won't be able to work on its own without the stuff in this file.
#load "autogen.jai";

size_t   :: u64;
ssize_t  :: s64;
off_t    :: s64;

__uintptr_t :: u64;

_LOCK_T :: s32;
_LOCK_RECURSIVE_T :: s32;

BIT :: (x: $T) -> T {
  return (cast(T)1) << x;
}

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
