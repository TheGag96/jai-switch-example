#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "Process";
#import "Sort";
#import "String";

#if OS == .WINDOWS {
  #import "Windows";
}
else {
  #import "POSIX";
}

PROJECT_NAME     :: "jai-switch";
APP_TITLE        :: "Jai program for Switch";
APP_AUTHOR       :: "Your name here";
APP_VERSION      :: "1.0.0";

OPTIMIZED_BUILD  :: false;
BUILD_FOR_TARGET :: false;

// @Note: I was having trouble building a cross compiling GCC for the Pi with the correct GlibC version, so without
// having that, the easiest way to make a full executable is just to compile the Jai side on the host and link on the
// target. If you have a working cross-compiler, this should do the trick if you fill out the constants below.
LINK_TARGET_EXECUTABLE_ON_THIS_MACHINE :: true;

devkitpro: string;

build :: () {
  w := compiler_create_workspace(name = "switch");
  if !w {
    log_error("Couldn't create workspace!\n");
    return;
  }

  devkitpro_env := getenv("DEVKITPRO");
  if devkitpro_env {
    devkitpro = from_c_string(devkitpro_env);
  }
  else {
    if OS == .WINDOWS {
      devkitpro = "C:/devkitPro";
    } else if (OS == .LINUX) || (OS == .MACOS) {
      devkitpro = "/opt/devkitpro";
    }
    log("Warning: The environment variable DEVKITPRO isn't defined, so we don't really know where devkitPro is installed. Going to assume this default path:\n  %", devkitpro);
  }

  target_options := get_build_options(w);

  build_for_target := BUILD_FOR_TARGET;

  for target_options.compile_time_command_line {
    if it == "target" {
      build_for_target = true;
      break;
    }
  }

  if build_for_target {
    log("Building for the target hardware.");
  }
  else {
    log("Building for this PC.");
  }

  link_target_executable_on_this_machine := build_for_target && LINK_TARGET_EXECUTABLE_ON_THIS_MACHINE;

  target_options.output_executable_name                = PROJECT_NAME;

  if build_for_target {
    target_options.backend                             = .LLVM;
    target_options.output_type                         = ifx link_target_executable_on_this_machine then .EXECUTABLE else .OBJECT_FILE;
    target_options.output_flags                       |= .INCLUDE_SYSTEM_ENTRY_POINT_IN_NON_EXECUTABLE_OUTPUT;
    target_options.backtrace_on_crash                  = .OFF;   // @TODO: Can we enable this?
    target_options.os_target                           = .NN_SWITCH;
    target_options.cpu_target                          = .ARM64;
    target_options.llvm_options.target_system_triple   = "aarch64-nintendo-switch-freestanding";
    target_options.llvm_options.target_system_cpu      = "cortex-a57";
    target_options.llvm_options.target_system_features = "+crc,+crypto";
    target_options.llvm_options.command_line           = string.["llvm", "--relocation-model=pic"];
    target_options.use_custom_link_command             = link_target_executable_on_this_machine;
    target_options.llvm_options.output_bitcode         = true;
    target_options.llvm_options.enable_split_modules   = false;
  }
  else {
    target_options.backend                             = .X64;
  }

  make_directory_if_it_does_not_exist("romfs");

  #if OPTIMIZED_BUILD {
    set_optimization(*target_options, .OPTIMIZED);
    target_options.llvm_options.code_gen_optimization_level = 3;
    target_options.llvm_options.enable_tail_calls           = true;
    target_options.llvm_options.enable_loop_unrolling       = true;
    target_options.llvm_options.enable_slp_vectorization    = true;
    target_options.llvm_options.enable_loop_vectorization   = true;
    target_options.llvm_options.disable_inlining            = false;
  }

  import_paths: [..] string;
  array_add(*import_paths, ..target_options.import_path);
  array_add(*import_paths, "modules");

  target_options.import_path = import_paths;
  set_build_options(target_options, w);

  set_build_options_dc(.{do_output = false});

  compile_shaders();

  compiler_begin_intercept(w);

  add_build_file("src/main.jai", w);
  // add_build_file("src/main_deko3d.jai", w);
  if link_target_executable_on_this_machine  custom_link(w);
  // hacky_inline_asm_removal(w);

  compiler_end_intercept(w);
}

custom_link :: (w: Workspace) {
  resulting_object_files: [] string;

  while true {
    message := compiler_wait_for_message();

    if message.kind == {
      case .PHASE; {
        phase := cast(*Message_Phase) message;

        if phase.phase == .READY_FOR_CUSTOM_LINK_COMMAND {
          out_map  := tprint("%.map",  PROJECT_NAME);
          out_nacp := tprint("%.nacp", PROJECT_NAME);
          out_elf  := tprint("%.elf",  PROJECT_NAME);
          out_nro  := tprint("%.nro",  PROJECT_NAME);

          args: [..] string;
          array_add(*args, tprint("%/devkitA64/bin/aarch64-none-elf-gcc", devkitpro));
          array_add(*args, ..phase.compiler_generated_object_files);
          // array_add(*args, ..phase.support_object_files);
          // array_add(*args, ..phase.system_libraries);
          array_add(*args, ..phase.user_libraries);
          array_add(
            *args,
            tprint("-specs=%/libnx/switch.specs", devkitpro), "-g", "-march=armv8-a+crc+crypto", "-mtune=cortex-a57",
            "-mtp=soft", "-fPIE", tprint("-Wl,-Map,%", out_map),
            tprint("-L%/portlibs/switch/lib", devkitpro), tprint("-L%/libnx/lib", devkitpro), "-ldeko3d", "-lnx",
            "-o", out_elf
          );

          // print("Link command: %\n", args);
          run_command(..args);

          array_reset_keeping_memory(*args);
          array_add(*args, tprint("%/tools/bin/nacptool", devkitpro), "--create", APP_TITLE, APP_AUTHOR, APP_VERSION, out_nacp);
          run_command(..args);

          array_reset_keeping_memory(*args);
          array_add(
            *args,
            tprint("%/tools/bin/elf2nro", devkitpro),
            out_elf, out_nro,
            tprint("--icon=%/libnx/default_icon.jpg", devkitpro), tprint("--nacp=%", out_nacp),
            "--romfsdir=romfs",
          );
          // print("elf2nro command: %\n", args);
          run_command(..args);

          compiler_custom_link_command_is_complete(w);
        }
      }

      case .COMPLETE; {
        break;
      }
    }
  }
}

compile_shaders :: () {
  log("Compiling shaders...");
  make_directory_if_it_does_not_exist("romfs/shaders");

  uam := tprint("%/tools/bin/uam", devkitpro);

  visit_files("src", recursive = true, *uam, (info: *File_Visit_Info, uam: *string) {
    if !ends_with(info.short_name, ".glsl") {
      return;
    }

    shader_stage: string;
    if      ends_with(info.short_name, "_vsh.glsl") {
      shader_stage = "vert";
    }
    else if ends_with(info.short_name, "_tcsh.glsl") {
      shader_stage = "tess_ctrl";
    }
    else if ends_with(info.short_name, "_tesh.glsl") {
      shader_stage = "tess_eval";
    }
    else if ends_with(info.short_name, "_gsh.glsl") {
      shader_stage = "geom";
    }
    else if ends_with(info.short_name, "_fsh.glsl") {
      shader_stage = "frag";
    }
    else {
      shader_stage = "comp";
    }

    out_file := tprint("romfs/shaders/%.dksh", basename(info.short_name));

    args: [..] string;
    array_add(*args, uam.*, "-o", out_file, info.full_name, "-s", shader_stage);

    log("%", info.short_name);
    run_command(..args);
  });
}

from_c_string :: inline (ptr: *u8) -> string {
  result: string = ---;

  result.data  = ptr;
  result.count = 0;

  my_ptr := ptr;
  while my_ptr.* != 0 {
    result.count += 1;
    my_ptr       += 1;
  }

  return result;
}

#run build();