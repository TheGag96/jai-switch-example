// Bindings for deko3d, devkitPro's Switch homebrew graphics library.
// This file contains all the bindings that had to be manually written - mainly for inline functions and such.
#import "Bitfields";
#import "Nx";

// Load the file that contains all the stuff Bindings_Generator was able to do.
// It won't be able to work on its own without the stuff in this file.
#load "autogen.jai";

dkDeviceMakerDefaults :: inline (maker: *DkDeviceMaker) {
    maker.userData = null;
    maker.cbDebug  = null;
    maker.cbAlloc  = null;
    maker.cbFree   = null;
    maker.flags    = xx DkDeviceFlags.DepthZeroToOne | DkDeviceFlags.OriginUpperLeft;
}

dkImageLayoutMakerDefaults :: inline (maker: *DkImageLayoutMaker, device: DkDevice) {
    maker.device        = device;
    maker.type          = DkImageType._2D;
    maker.flags         = 0;
    maker.format        = DkImageFormat.None;
    maker.msMode        = DkMsMode._1x;
    maker.dimensions[0] = 0;
    maker.dimensions[1] = 0;
    maker.dimensions[2] = 0;
    maker.mipLevels     = 1;
    maker.pitchStride   = 0;
}

dkShaderMakerDefaults :: inline (maker: *DkShaderMaker, codeMem: DkMemBlock, codeOffset: u32) {
    maker.codeMem    = codeMem;
    maker.control    = null;
    maker.codeOffset = codeOffset;
    maker.programId  = 0;
}

dkMemBlockMakerDefaults :: inline (maker: *DkMemBlockMaker, device: DkDevice, size: u32) {
    maker.device  = device;
    maker.size    = size;
    maker.flags   = xx DkMemBlockFlags.CpuUncached | DkMemBlockFlags.GpuCached;
    maker.storage = null;
}

dkSwapchainMakerDefaults :: inline (maker: *DkSwapchainMaker, device: DkDevice, nativeWindow: *void, pImages: [] *DkImage) {
    maker.device       = device;
    maker.nativeWindow = nativeWindow;
    maker.pImages      = pImages.data;
    maker.numImages    = xx pImages.count;
}

dkCmdBufMakerDefaults :: inline (maker: *DkCmdBufMaker, device: DkDevice) {
    maker.device   = device;
    maker.userData = null;
    maker.cbAddMem = null;
}

dkImageViewDefaults :: inline (obj: *DkImageView, pImage: *DkImage) {
    obj.pImage         = pImage;
    obj.type           = .None; // no override
    obj.format         = .None; // no override
    obj.swizzle[0]     = .Red;
    obj.swizzle[1]     = .Green;
    obj.swizzle[2]     = .Blue;
    obj.swizzle[3]     = .Alpha;
    obj.dsSource       = .Depth;
    obj.layerOffset    = 0;
    obj.layerCount     = 0; // no override
    obj.mipLevelOffset = 0;
    obj.mipLevelCount  = 0; // no override
}

dkRasterizerStateDefaults :: inline (state: *DkRasterizerState) {
    state.set_rasterizerEnable        (state, 1);
    state.set_depthClampEnable        (state, 0);
    state.set_fillRectangleEnable     (state, 0);
    state.set_polygonModeFront        (state, .Fill);
    state.set_polygonModeBack         (state, .Fill);
    state.set_cullMode                (state, .Back);
    state.set_frontFace               (state, .CCW);
    state.set_provokingVertex         (state, .Last);
    state.set_polygonSmoothEnableMask (state, 0);
    state.set_depthBiasEnableMask     (state, 0);
}

dkColorStateDefaults :: inline (state: *DkColorState) {
    state.set_blendEnableMask (state, 0x00);
    state.set_logicOp         (state, .Copy);
    state.set_alphaCompareOp  (state, .Always);
}

dkQueueMakerDefaults :: inline (maker: *DkQueueMaker, device: DkDevice) {
    maker.device = device;
    maker.flags = xx
        DkQueueFlags.Graphics | DkQueueFlags.Compute | DkQueueFlags.MediumPrio |
        DkQueueFlags.EnableZcull;
    maker.commandMemorySize = DK_QUEUE_MIN_CMDMEM_SIZE;
    maker.flushThreshold = DK_QUEUE_MIN_CMDMEM_SIZE/8;
    maker.perWarpScratchMemorySize = 4*DK_PER_WARP_SCRATCH_MEM_ALIGNMENT;
    maker.maxConcurrentComputeJobs = DK_DEFAULT_MAX_COMPUTE_CONCURRENT_JOBS;
}

dkColorWriteStateDefaults :: inline (state: *DkColorWriteState)
{
    state.masks = 0xFFFFFFFF;
}

dkTimestampToNs :: inline (ts: u64) -> u64 {
    return (ts * 625) / 384;
}

dkNsToTimestamp :: inline (ns: u64) -> u64 {
    return (ns * 384) / 625;
}

dkCmdBufBindUniformBuffer :: inline (obj: DkCmdBuf, stage: DkStage, id: u32, bufAddr: DkGpuAddr, bufSize: u32) {
    ext := DkBufExtents.{ bufAddr, bufSize };
    dkCmdBufBindUniformBuffers(obj, stage, id, *ext, 1);
}

dkCmdBufBindStorageBuffer :: inline (obj: DkCmdBuf, stage: DkStage, id: u32, bufAddr: DkGpuAddr, bufSize: u32) {
    ext = DkBufExtents.{ bufAddr, bufSize };
    dkCmdBufBindStorageBuffers(obj, stage, id, *ext, 1);
}

dkCmdBufBindTexture :: inline (obj: DkCmdBuf, stage: DkStage, id: u32, handle: DkResHandle) {
    dkCmdBufBindTextures(obj, stage, id, *handle, 1);
}

dkCmdBufBindImage :: inline (obj: DkCmdBuf, stage: DkStage, id: u32, handle: DkResHandle) {
    dkCmdBufBindImages(obj, stage, id, *handle, 1);
}

dkCmdBufBindRenderTarget :: inline (obj: DkCmdBuf, colorTarget: *DkImageView, depthTarget: *DkImageView) {
    dkCmdBufBindRenderTargets(obj, *colorTarget, 1, depthTarget);
}

dkCmdBufBindBlendState :: inline (obj: DkCmdBuf, id: u32, state: *DkBlendState) {
    dkCmdBufBindBlendStates(obj, id, state, 1);
}

dkCmdBufBindVtxBuffer :: inline (obj: DkCmdBuf, id: u32, bufAddr: DkGpuAddr, bufSize: u32) {
    ext = DkBufExtents.{ bufAddr, bufSize };
    dkCmdBufBindVtxBuffers(obj, id, *ext, 1);
}

dkCmdBufClearColorFloat :: inline (obj: DkCmdBuf, targetId: u32, clearMask: u32, red: float, green: float, blue: float, alpha: float) {
    data := float.[red, green, blue, alpha];
    dkCmdBufClearColor(obj, targetId, clearMask, data.data);
}

dkCmdBufClearColorSint :: inline (obj: DkCmdBuf, targetId: u32, clearMask: u32, red: s32, green: s32, blue: s32, alpha: s32) {
    data := s32.[red, green, blue, alpha];
    dkCmdBufClearColor(obj, targetId, clearMask, data.data);
}

dkCmdBufClearColorUint :: inline (obj: DkCmdBuf, targetId: u32, clearMask: u32, red: u32, green: u32, blue: u32, alpha: u32) {
    data := u32.[red, green, blue, alpha];
    dkCmdBufClearColor(obj, targetId, clearMask, data.data);
}

dkImageGetLayout :: inline (obj: *DkImage) -> *DkImageLayout {
    return xx obj;
}