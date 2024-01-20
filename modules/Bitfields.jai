// Tries to implement bitfields in the most ergonomic way I can think of.
// Inspired in part by what D's standard library did before the language supported bitfields.

Bitfield_Flags :: enum_flags u32 {
  NONE;
  AS;
  USING; // Needed to emulate C structs containing anonymous structs, including those with bitfields inside
}

Bitfield_Def :: struct {
  name:  string;
  type:  Type;
  size:  int;
  flags: Bitfield_Flags;
}

// A bit superfluous, but for the purpose of not needing to specify all of the members of Bitfield_Defs
bf :: (name: string, type: Type, size: int = 0, flags: Bitfield_Flags = .NONE) -> Bitfield_Def {
  return .{ name = name, type = type, size = size, flags = flags };
}

bitfields_struct :: (type_name: string, defs: ..Bitfield_Def, post_defs: string = "") -> string {
  builder: String_Builder;
  init_string_builder(*builder);

  // Allow anonymous structs to be generated
  if type_name.count {
    print_to_builder(*builder, "% :: struct {\n", type_name);
  }
  else {
    print_to_builder(*builder, "struct {\n");
  }

  total_bits           := 0;
  largest_align        := 1;
  bitfield_array_count := 0;
  bitfield_block_start := -1;

  for defs {
    ti := cast(*Type_Info) it.type;
    base_type_byte_size := ti.runtime_size;
    base_type_bit_size  := base_type_byte_size * 8;

    base_is_valid_type := ti.type == .INTEGER || ti.type == .BOOL || ti.type == .ENUM;
    size_is_normal     := !base_is_valid_type || it.size == 0 || it.size == base_type_bit_size;

    if !base_is_valid_type && it.size != 0 {
      compiler_report(tprint("The base type of bitfield '%' is not an integer, bool, or enum (%).", it.name, it.type), mode = .ERROR);
      return "";
    }
    else if base_is_valid_type && it.size > base_type_bit_size {
      compiler_report(tprint("Field '%' was given a bit size larger than its base type (%).", it.name, it.type), mode = .ERROR);
      return "";
    }

    if size_is_normal {
      // Finish preceding block of bitfields if need be
      if bitfield_block_start != -1 {
        emit_bitfield_block(
          *builder, type_name, array_view(defs, bitfield_block_start, it_index - bitfield_block_start),
          *bitfield_array_count, *total_bits, *largest_align,
        );
        bitfield_block_start = -1;
      }

      // Emit field by itself
      print_to_builder(
        *builder, "  %0%0%: %;\n",
        ifx it.flags &.AS    then "#as "   else "",
        ifx it.flags &.USING then "using " else "",
        it.name, it.type
      );
      total_bits += base_type_bit_size;
    }
    else if bitfield_block_start == -1 {
      bitfield_block_start = it_index;
    }

    // Emit the block of bitfields at the end of the definiton list
    if it_index == defs.count-1 && bitfield_block_start != -1 && !size_is_normal {
      emit_bitfield_block(
        *builder, type_name, array_view(defs, bitfield_block_start, it_index - bitfield_block_start + 1),
        *bitfield_array_count, *total_bits, *largest_align,
      );
    }
  }

  // If supplied, insert some desired extra code into the struct
  // Indentation won't be great, however...
  if post_defs.count {
    print_to_builder(*builder, "  %\n", post_defs);
  }

  // Force the struct to be aligned to at least the largest type in all bitfield blocks
  print_to_builder(*builder, "  __%_align: void #align %;\n", type_name, largest_align);
  print_to_builder(*builder, "}\n");

  return builder_to_string(*builder);
}

emit_bitfield_block :: (
  builder: *String_Builder, containing_type: string, defs: [] Bitfield_Def,
  bitfield_array_count: *int, total_bits: *int, largest_align: *int
) {
  block_bits  := 0;
  block_align := 1;

  for defs {
    base_type_byte_size := (cast(*Type_Info) it.type).runtime_size;
    base_type_bit_size  := base_type_byte_size * 8;

    if base_type_byte_size > block_align  block_align = base_type_byte_size;

    // If this bitfield would be placed straddling the boundary of its base type's alignment, pad things out a bit
    if (total_bits.* + block_bits) % base_type_bit_size + it.size > base_type_bit_size {
      block_bits = ((total_bits.* + block_bits + base_type_bit_size - 1) & ~(base_type_bit_size - 1)) - total_bits.*;
    }

    cur_bit_block  := block_bits;
    cur_byte_block := cur_bit_block / 8;
    print_to_builder(builder, #string DONE
      set_%1 :: inline (t: *%2, val: %3) {
        bitfield_set(t.__bitfields_%2_%4, %5, %6, val);
      }

      get_%1 :: inline (t: %2) -> %3 {
        return bitfield_get(t.__bitfields_%2_%4, %5, %6, %3);
      }

DONE, it.name, containing_type, it.type,
      bitfield_array_count.*, cur_bit_block, it.size,
);

    block_bits += it.size;
  }

  bytes_needed := (block_bits + 8 - 1) / 8;

  print_to_builder(builder, "  __bitfields_%_%: [%] u8;\n", containing_type, bitfield_array_count.*, bytes_needed);

  if block_align > largest_align.*  largest_align.* = block_align;
  total_bits.* += block_bits;
  bitfield_array_count.* += 1;
}

// @Speed: How well will the compiler optimize these when the arguments are runtime? Should they be compile-time?

bitfield_set :: inline (bytes: [] u8, pos: int, size: int, value: $V) #no_aoc #no_abc {
  #if V == bool {
    Write_Type :: u8;
  }
  else {
    Write_Type :: V;
  }

  val_ptr := (cast(*Write_Type) bytes.data) + (pos / (size_of(V) * 8));
  old_whole: Write_Type = val_ptr.*;

  mask: Write_Type = xx ((1 << size) - 1);

  pos_in_whole := pos % (size_of(Write_Type) * 8);
  value_masked: Write_Type = ((cast(Write_Type)value) & mask);

  #if OVERFLOW_CHECK_BEHAVIOR != .OFF {
    #if #run is_signed(V) {
      if sign_extend(value_masked, size-1) != value {
        // Should these setters and getters be macros so I can do #file and #line of the calling code?
        // @Bug: No matter what I set the type size in pre_flags and post_flags, the error message won't be right.
        // So, just set the signedness and don't bother with the rest, I guess...
        bitfield_panic(xx,no_check value, true, size);
      }
    }
    else #if V != bool {
      if value_masked != value {
        bitfield_panic(xx,no_check value, false, size);
      }
    }
  }

  val_ptr.* = xx,no_check (old_whole & ~(mask << pos_in_whole)) | (value_masked << pos_in_whole);
}

bitfield_get :: inline (bytes: [] u8, pos: int, size: int, $V: Type) -> V #no_aoc #no_abc {
  // Because the bitfield must never cross the alignment of its base type, we can do a single read of the base type's
  // size and simply mask/shift what we don't need.
  val_ptr := (cast(*V) bytes.data) + (pos / (size_of(V) * 8));
  whole_value: V = val_ptr.*;

  pos_in_whole: u64 = xx (pos % (size_of(V) * 8));
  temp: u64 = ((cast(u64) whole_value) >> pos_in_whole) & (cast(u64) (1 << size) - 1);

  #if #run is_signed(V) {
    temp = xx,no_check sign_extend(cast,no_check(s64) temp, size-1);
  }

  return xx,no_check temp;
}

// Modified from __cast_bounds_check_fail
bitfield_panic :: (value: s64, signed: bool, size: int, line_number: int = #line, filename: string = #file) #no_context {
  write_string("Bitfield bounds check failed.  Number must be in [", to_standard_error = true);

  if signed {
    high_value := (1 << (size - 1)) - 1;
    low_value  := ~high_value;
    write_number(low_value, to_standard_error = true);
    write_string(", ", to_standard_error = true);
    write_number(high_value, to_standard_error = true);
  } else {
    high_value: u64;
    if size == 64 {
      high_value = 0xffff_ffff_ffff_ffff;
    } else {
      high_value = ((cast(u64)1) << size) - 1;
    }

    write_string("0, ", to_standard_error = true);
    write_nonnegative_number(high_value, to_standard_error = true);
  }

  write_string("]; it was ", to_standard_error = true);

  if signed {
    write_number(value, to_standard_error = true);
  } else {
    write_nonnegative_number(cast,no_check(u64) value, to_standard_error = true);
  }

  write_string(".  Site is ", to_standard_error = true);

  write_string(filename, to_standard_error = true);
  write_string(":", to_standard_error = true);
  write_number(line_number, to_standard_error = true);
  write_string(".\n", to_standard_error = true);

  if OVERFLOW_CHECK_BEHAVIOR == .FATAL  {
    write_string("Panic.\n", to_standard_error = true);
    debug_break();
  }
}

#scope_file

OVERFLOW_CHECK_BEHAVIOR :: #run get_build_options().cast_bounds_check;

is_signed :: (t: Type) -> bool {
  ti := cast(*Type_Info) t;
  if ti.type != .INTEGER  return false;

  return (cast(*Type_Info_Integer) ti).signed;
}

sign_extend :: inline (val: $T, bit_index: int) -> T {
  result := val;
  sign_bits: s64 = (((1 << bit_index) & (cast(s64) val))
                       << (64 - (bit_index+1))) >> (64 - (bit_index+1));
  result |= xx,no_check sign_bits;
  return result;
}

#import "Basic";
#import "Compiler";
#import "String";