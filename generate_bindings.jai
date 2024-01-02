AT_COMPILE_TIME :: true;

#if AT_COMPILE_TIME {
  #run {
    set_build_options_dc(.{do_output = false});
    if !generate_bindings() {
      compiler_set_workspace_status(.FAILED);
    }
  };
} else {
  #import "System";

  main :: () {
    set_working_directory(path_strip_filename(get_path_of_running_executable()));
    if !generate_bindings() {
      exit(1);
    }
  }
}

omit_list :: string.[];

generate_bindings :: () -> bool {
  result := true;

  devkitpro: string;
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

  output_filename: string;
  options: Generate_Bindings_Options;
  {
    using options;

    array_add(*system_library_names, "libnx");
    output_filename  = "modules/Nx/autogen.jai";
    array_add(*system_library_paths, tprint("%/libnx/lib", devkitpro));

    array_add(*extra_clang_arguments, "--target=aarch64-nintendo-switch-freestanding", "-march=armv8-a+crc+crypto", "-mtune=cortex-a57");
    array_add(*source_files, tprint("%/libnx/include/switch.h", devkitpro));

    // @TODO: Deal with the fact that the GCC version will change over time
    array_add(*system_include_paths, tprint("%/devkitA64/aarch64-none-elf/include", devkitpro));
    array_add(*system_include_paths, tprint("%/devkitA64/lib/gcc/aarch64-none-elf/13.2.0/include", devkitpro));
    array_add(*system_include_paths, tprint("%/devkitA64/aarch64-none-elf/include/c++/13.2.0", devkitpro));

    // will_print_bindings = () {
    //     context.generator.libraries[0].name = "libnx";
    // };

    visitor = switch_visitor;
    add_generator_command = false;
    alias_original_enum_names = false;
    log_stripped_declarations = false;
    generate_compile_time_struct_checks = false;
  }
  print("Generating libnx bindings...\n");
  result = result && generate_one_binding(options, output_filename);

  return result;
}

generate_one_binding :: (options: Generate_Bindings_Options, output_filename: string) -> bool {
  bindings_builder, success := generate_bindings(options, log_results = true);
  if !success return false;

  success = write_entire_file(output_filename, *bindings_builder);
  if !success {
    log_error("Could not write generated output to \"%\"\n", output_filename);
    return false;
  }
  log("\nOK! generated '%'\n", output_filename);

  return true;
}

struct_type_decl: *Enum;

switch_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
  if decl.kind == .ENUM {
    // @Speed: Linear lookup
    if array_find(FLAG_ENUMS, decl.name) {
      (cast(*Enum) decl).flags |= .IS_ENUM_FLAGS;
    }
  }
  else if decl.kind == .FUNCTION {
  }

  return .RECURSE;
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

FLAG_ENUMS :: string.[
  "HidDebugPadButton",
  "HidMouseButton",
  "HidKeyboardModifier",
  "HidKeyboardLockKeyEvent",
  "HidNpadStyleTag",
  "HidNpadButton",
  "HidNpadAttribute",
  "HidDebugPadAttribute",
  "HidTouchAttribute",
  "HidMouseAttribute",
  "HidSixAxisSensorAttribute",
  "HidGestureAttribute",
];

Function_Remap :: struct {
  name: string;

  remaps: [] struct {
    param: string;
    new_type: string;
  };
}

FUNC_REMAPS :: Function_Remap.[

];

#import "Basic";
#import "Bindings_Generator";
#import "Compiler";
#import "File";
#import "String";

#if OS == .WINDOWS {
  #import "Windows";
}
else {
  #import "POSIX";
}