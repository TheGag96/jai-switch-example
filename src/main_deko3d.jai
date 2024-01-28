#import "Basic";
#import "Nx";
#import "Deko3d";
#import "POSIX";

// Define the desired number of framebuffers
FB_NUM :: 2;

// Define the desired framebuffer resolution (here we set it to 720p).
FB_WIDTH  :: 1280;
FB_HEIGHT :: 720;

CODEMEMSIZE :: 64*1024;
CMDMEMSIZE  :: 16*1024;

g_device: DkDevice;
g_framebufferMemBlock: DkMemBlock;
g_framebuffers: [FB_NUM]DkImage;
g_swapchain: DkSwapchain;

g_codeMemBlock: DkMemBlock;
g_codeMemOffset: u32;
g_vertexShader: DkShader;
g_fragmentShader: DkShader;

g_cmdbufMemBlock: DkMemBlock;
g_cmdbuf: DkCmdBuf;
g_cmdsBindFramebuffer: [FB_NUM]DkCmdList;
g_cmdsRender: DkCmdList;

g_renderQueue: DkQueue;

// Simple function for loading a shader from the filesystem
loadShader :: (pShader: *DkShader, path: *u8)
{
    // Open the file, and retrieve its size
    f := fopen(path, "rb");
    fseek(f, 0, SEEK_END);
    size := ftell(f);
    rewind(f);

    // Look for a spot in the code memory block for loading this shader. Note that
    // we are just using a simple incremental offset; this isn't a general purpose
    // allocation algorithm.
    codeOffset := g_codeMemOffset;
    g_codeMemOffset += xx (size + DK_SHADER_CODE_ALIGNMENT - 1) &~ (DK_SHADER_CODE_ALIGNMENT - 1);

    // Read the file into memory, and close the file
    fread(cast(*u8)dkMemBlockGetCpuAddr(g_codeMemBlock) + codeOffset, xx size, 1, f);
    fclose(f);

    // Initialize the user provided shader object with the code we've just loaded
    shaderMaker: DkShaderMaker;
    dkShaderMakerDefaults(*shaderMaker, g_codeMemBlock, codeOffset);
    dkShaderInitialize(pShader, *shaderMaker);
}

// This function creates all the necessary graphical resources.
graphicsInitialize :: ()
{
    // Create the device, which is the root object
    deviceMaker: DkDeviceMaker;
    dkDeviceMakerDefaults(*deviceMaker);
    g_device = dkDeviceCreate(*deviceMaker);

    // Calculate layout for the framebuffers
    imageLayoutMaker: DkImageLayoutMaker;
    dkImageLayoutMakerDefaults(*imageLayoutMaker, g_device);
    imageLayoutMaker.flags = xx DkImageFlags.UsageRender | DkImageFlags.UsagePresent | DkImageFlags.HwCompression;
    imageLayoutMaker.format = DkImageFormat.RGBA8_Unorm;
    imageLayoutMaker.dimensions[0] = FB_WIDTH;
    imageLayoutMaker.dimensions[1] = FB_HEIGHT;

    // Calculate layout for the framebuffers
    framebufferLayout: DkImageLayout;
    dkImageLayoutInitialize(*framebufferLayout, *imageLayoutMaker);

    // Retrieve necessary size and alignment for the framebuffers
    framebufferSize  := dkImageLayoutGetSize(*framebufferLayout);
    framebufferAlign := dkImageLayoutGetAlignment(*framebufferLayout);
    framebufferSize = (framebufferSize + framebufferAlign - 1) &~ (framebufferAlign - 1);

    // Create a memory block that will host the framebuffers
    memBlockMaker: DkMemBlockMaker;
    dkMemBlockMakerDefaults(*memBlockMaker, g_device, xx (FB_NUM*framebufferSize));
    memBlockMaker.flags = xx DkMemBlockFlags.GpuCached | DkMemBlockFlags.Image;
    g_framebufferMemBlock = dkMemBlockCreate(*memBlockMaker);

    // Initialize the framebuffers with the layout and backing memory we've just created
    swapchainImages: [FB_NUM] * DkImage;
    for 0..cast(u64) (FB_NUM-1)
    {
        swapchainImages[it] = *g_framebuffers[it];
        dkImageInitialize(*g_framebuffers[it], *framebufferLayout, g_framebufferMemBlock, xx (it*framebufferSize));
    }

    // Create a swapchain out of the framebuffers we've just initialized
    swapchainMaker: DkSwapchainMaker;
    dkSwapchainMakerDefaults(*swapchainMaker, g_device, nwindowGetDefault(), swapchainImages);
    g_swapchain = dkSwapchainCreate(*swapchainMaker);

    // Create a memory block onto which we will load shader code
    dkMemBlockMakerDefaults(*memBlockMaker, g_device, CODEMEMSIZE);
    memBlockMaker.flags = xx DkMemBlockFlags.CpuUncached | DkMemBlockFlags.GpuCached | DkMemBlockFlags._Code;
    g_codeMemBlock = dkMemBlockCreate(*memBlockMaker);
    g_codeMemOffset = 0;

    // Load our shaders (both vertex and fragment)
    loadShader(*g_vertexShader, "romfs:/shaders/triangle_vsh.dksh");
    loadShader(*g_fragmentShader, "romfs:/shaders/color_fsh.dksh");

    // Create a memory block which will be used for recording command lists using a command buffer
    dkMemBlockMakerDefaults(*memBlockMaker, g_device, CMDMEMSIZE);
    memBlockMaker.flags = xx DkMemBlockFlags.CpuUncached | DkMemBlockFlags.GpuCached;
    g_cmdbufMemBlock = dkMemBlockCreate(*memBlockMaker);

    // Create a command buffer object
    cmdbufMaker: DkCmdBufMaker;
    dkCmdBufMakerDefaults(*cmdbufMaker, g_device);
    g_cmdbuf = dkCmdBufCreate(*cmdbufMaker);

    // Feed our memory to the command buffer so that we can start recording commands
    dkCmdBufAddMemory(g_cmdbuf, g_cmdbufMemBlock, 0, CMDMEMSIZE);

    // Generate a command list for each framebuffer, which will bind each of them as a render target
    for 0..FB_NUM-1
    {
        imageView: DkImageView;
        dkImageViewDefaults(*imageView, *g_framebuffers[it]);
        dkCmdBufBindRenderTarget(g_cmdbuf, *imageView, null);
        g_cmdsBindFramebuffer[it] = dkCmdBufFinishList(g_cmdbuf);
    }

    // Declare structs that will be used for binding state
    viewport := DkViewport.{ 0.0, 0.0, cast(float)FB_WIDTH, cast(float)FB_HEIGHT, 0.0, 1.0 };
    scissor  := DkScissor.{ 0, 0, FB_WIDTH, FB_HEIGHT };
    shaders  := (*DkShader).[ *g_vertexShader, *g_fragmentShader ];
    rasterizerState: DkRasterizerState;
    colorState: DkColorState;
    colorWriteState: DkColorWriteState;

    // Initialize state structs with the deko3d defaults
    dkRasterizerStateDefaults(*rasterizerState);
    dkColorStateDefaults(*colorState);
    dkColorWriteStateDefaults(*colorWriteState);

    // Generate the main rendering command list
    dkCmdBufSetViewports(g_cmdbuf, 0, *viewport, 1);
    dkCmdBufSetScissors(g_cmdbuf, 0, *scissor, 1);
    dkCmdBufClearColorFloat(g_cmdbuf, 0, xx DkColorMask.RGBA, 0.125, 0.294, 0.478, 1.0);
    dkCmdBufBindShaders(g_cmdbuf, xx DkStageFlag.GraphicsMask, shaders.data, xx shaders.count);
    dkCmdBufBindRasterizerState(g_cmdbuf, *rasterizerState);
    dkCmdBufBindColorState(g_cmdbuf, *colorState);
    dkCmdBufBindColorWriteState(g_cmdbuf, *colorWriteState);
    dkCmdBufDraw(g_cmdbuf, xx DkPrimitive.Triangles, 3, 1, 0, 0);
    g_cmdsRender = dkCmdBufFinishList(g_cmdbuf);

    // Create a queue, to which we will submit our command lists
    queueMaker: DkQueueMaker;
    dkQueueMakerDefaults(*queueMaker, g_device);
    queueMaker.flags = xx DkQueueFlags.Graphics;
    g_renderQueue = dkQueueCreate(*queueMaker);
}

// This function is to be called at each frame, and it is in charge of rendering.
graphicsUpdate :: ()
{
    // Acquire a framebuffer from the swapchain (and wait for it to be available)
    slot := dkQueueAcquireImage(g_renderQueue, g_swapchain);

    // Run the command list that binds said framebuffer as a render target
    dkQueueSubmitCommands(g_renderQueue, g_cmdsBindFramebuffer[slot]);

    // Run the main rendering command list
    dkQueueSubmitCommands(g_renderQueue, g_cmdsRender);

    // Now that we are done rendering, present it to the screen
    dkQueuePresentImage(g_renderQueue, g_swapchain, slot);
}

// This function destroys the graphical resources created by graphicsInitialize.
graphicsExit :: ()
{
    // Make sure the rendering queue is idle before destroying anything
    dkQueueWaitIdle(g_renderQueue);

    // Destroy all the resources we've created
    dkQueueDestroy(g_renderQueue);
    dkCmdBufDestroy(g_cmdbuf);
    dkMemBlockDestroy(g_cmdbufMemBlock);
    dkMemBlockDestroy(g_codeMemBlock);
    dkSwapchainDestroy(g_swapchain);
    dkMemBlockDestroy(g_framebufferMemBlock);
    dkDeviceDestroy(g_device);
}

// Main entrypoint
main :: ()
{
    romfsInit();
    graphicsInitialize();

    // Configure our supported input layout: a single player with standard controller styles
    padConfigureInput(1, xx HidNpadStyleTag.HidNpadStyleSet_NpadStandard);

    // Initialize the default gamepad (which reads handheld mode inputs as well as the first connected controller)
    pad: PadState;
    padInitializeDefault(*pad);

    while appletMainLoop()
    {
        padUpdate(*pad);

        kDown := padGetButtonsDown(*pad);
        if (kDown & HidNpadButton.Plus)
            break; // break in order to return to hbmenu

        graphicsUpdate();
    }

    graphicsExit();
    romfsExit();
}