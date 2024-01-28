AT_COMPILE_TIME :: false;

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

bitfield_structs: String_Builder;

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

  init_string_builder(*bitfield_structs);

  output_filename: string;
  options: Generate_Bindings_Options;
  {
    using options;

    array_add(*system_library_names, "libnx");
    output_filename  = "modules/Nx/autogen.jai";
    array_add(*system_library_paths, tprint("%/libnx/lib", devkitpro));

    array_add(*extra_clang_arguments, "-nostdinc", "--target=aarch64-nintendo-switch-freestanding", "-march=armv8-a+crc+crypto", "-mtune=cortex-a57");
    array_add(
      *source_files,
      tprint("%/libnx/include/switch.h",                devkitpro),
    );
    array_add(*include_paths, tprint("%/libnx/include", devkitpro));

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

  {
    using options;

    array_reset_keeping_memory(*system_library_names);
    array_add(*system_library_names, "libdeko3d");
    output_filename  = "modules/Deko3d/autogen.jai";

    array_reset_keeping_memory(*source_files);
    array_add(*source_files, tprint("%/libnx/include/deko3d.h", devkitpro));

    // will_print_bindings = () {
    //     context.generator.libraries[0].name = "libdeko3d";
    // };
  }
  print("Generating Deko3d bindings...\n");
  result = result && generate_one_binding(options, output_filename);

  return result;
}

generate_one_binding :: (options: Generate_Bindings_Options, output_filename: string) -> bool {
  bindings_builder, success := generate_bindings(options, log_results = true);
  if !success return false;

  print_to_builder(*bindings_builder, "\n#scope_export\n\n");
  print_to_builder(*bindings_builder, builder_to_string(*bitfield_structs));

  // @Hack: I need the manual part of the bindings to be able to see the library declaration, but I can't just tell
  //        the Bindings Generator to do #scope_module instead. Just crappily replace it.
  temp_bindings  := builder_to_string(*bindings_builder);
  final_bindings := replace(temp_bindings, "#scope_file", "#scope_module");

  success = write_entire_file(output_filename, final_bindings);
  if !success {
    log_error("Could not write generated output to \"%\"\n", output_filename);
    return false;
  }
  log("\nOK! generated '%'\n", output_filename);

  return true;
}

is_anon_struct :: (ctype: *CType) -> bool {
  return ctype && ctype.type_of_struct && ctype.type_of_struct.flags & .IS_ANON;
}

is_anon_struct_decl_for_field :: (decls: [] *Declaration, index: int) -> bool {
  if index < decls.count - 1 {
    it   := decls[index];
    next := decls[index+1];

    return it.kind == .STRUCT &&
           ( it.type.type_of_struct == next.type.type_of_struct ||
             ( next.type.array_element_type &&
               it.type.type_of_struct == next.type.array_element_type.type_of_struct ) );
  }

  return false;
}

switch_visitor :: (decl: *Declaration, parent_decl: *Declaration) -> Declaration_Visit_Result {
  if decl.kind == .ENUM {
    // @Speed: Linear lookup
    if array_find(FLAG_ENUMS, decl.name) {
      (cast(*Enum) decl).flags |= .IS_ENUM_FLAGS;
    }
  }
  else if decl.kind == .FUNCTION {
  }
  else if decl.kind == .STRUCT {
    decl_struct := cast(*Struct) decl;

    anon_struct_count := 0;

    if struct_has_bitfields(decl_struct) && !array_find(BITFIELDS_EXCLUDE, decl.output_name) {
      for decl_struct.declarations {

        // @Hack: Skip anonymous struct declarations that are to be used immediately next as a struct member
        if is_anon_struct_decl_for_field(decl_struct.declarations, it_index) {
          continue;
        }

        // Emit anonymous structs prior to the outer one. Assume this goes only one level deep...
        if it.kind == .STRUCT ||
           is_anon_struct(it.type) ||
           is_anon_struct(it.type.array_element_type)
        {
          anon_name: string;
          if it.name.count {
            anon_name = tprint("__%_anon_%", decl.output_name, it.output_name);
          }
          else {
            anon_name = tprint("__%_anon_%", decl.output_name, anon_struct_count);
          }

          field_anon_type := ifx it.type.array_element_type then it.type.array_element_type.type_of_struct
                                                            else it.type.type_of_struct;

          // The inner struct may have bitfields! Assuming one level deep.
          if struct_has_bitfields(field_anon_type) {
            print_bitfield_struct(*bitfield_structs, field_anon_type, anon_name);
          }
          else {
            print_to_builder(*bitfield_structs, "% :: ", anon_name);
            print_declaration_to_builder(*bitfield_structs, field_anon_type, decl);
            print_to_builder(*bitfield_structs, "\n\n");
          }

          anon_struct_count += 1;
        }
      }

      print_bitfield_struct(*bitfield_structs, decl, decl.output_name);

      decl.decl_flags |= .OMIT_FROM_OUTPUT;
      return .STOP;
    }
  }

  return .RECURSE;
}

struct_has_bitfields :: (decl_struct: Struct) -> bool {
  for decl_struct.declarations {
    if it.bitfield_width != -1 {
      return true;
    }
  }
  return false;
}

print_bitfield_struct :: (builder: *String_Builder, decl: *Declaration, name: string) {
  anon_struct_count := 0;

  print_to_builder(builder, "#insert #run bitfields_struct(\n");
  print_to_builder(builder, "    \"%\",\n", name);

  num_dummy_fields := 0;

  decl_struct := cast(*Struct) decl;
  for decl_struct.declarations {
    if is_anon_struct_decl_for_field(decl_struct.declarations, it_index) {
      continue;
    }

    field_size      := ifx it.bitfield_width == -1 then 0 else it.bitfield_width;

    if it.output_name.count {
      print_to_builder(builder, "    .{ \"%\", ", it.output_name);
    }
    else {
      // This is an anonymous padding bitfield, so assign it some dummy name
      print_to_builder(builder, "    .{ \"__padding_%\", ", num_dummy_fields);
      num_dummy_fields += 1;
    }

    print_using := false;
    if it.kind == .STRUCT ||
       is_anon_struct(it.type) ||
       is_anon_struct(it.type.array_element_type)
    {
      if it.type.array_element_type {
        // Work around compiler bug printing non-simple types
        print_to_builder(builder, "#type [%] ", it.type.array_element_count);
      }

      if it.name.count {
        print_to_builder(builder, "__%_anon_%", name, it.output_name);
      }
      else {
        print_to_builder(builder, "__%_anon_%", name, anon_struct_count);
      }
      anon_struct_count += 1;
      print_using = it.kind == .STRUCT;
    }
    else {
      print_to_builder(builder, "#type ");  // Work around compiler bug printing non-simple types
      print_type_to_builder(builder, it.type, decl);
    }

    print_to_builder(builder, ", %, % },\n", field_size, ifx print_using then ".USING" else ".NONE");
  }
  print_to_builder(builder, ");\n\n");
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

BITFIELDS_EXCLUDE :: string.[
  // This is a linked list type, and my bitfields library doesn't handle the self-reference yet.
  // Also, its one bitfield is used to make an enum field 8 bits large, which the generator turns into a u8 anyway.
  "AudioDriverWaveBuf",

  // This is defined in the autogen'd bindings for the Socket module. Having proper access to this struct is not very
  // important.
  "pthread_rwlock_t",
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
#import "Debug";
#import "File";
#import "String";

#if OS == .WINDOWS {
  #import "Windows";
}
else {
  #import "POSIX";
}