package main

import "core:bytes"
import "core:fmt"

@(private)
SEGMENT_BITS: int : 0x7F
@(private)
CONTINUE_BIT: int : 0x80

read_var_int :: proc(buffer: ^bytes.Buffer) -> int {

	value: int = 0
	position: uint = 0

	for {
		currentByte, err := bytes.buffer_read_byte(buffer)
		if err != nil {
			fmt.panicf("cant read var int: %s", err)
		}

		value |= (int(currentByte) & SEGMENT_BITS) << position

		if (currentByte & u8(CONTINUE_BIT)) == 0 {
			break
		}

		position += 7

		if position >= 32 {
			fmt.panicf("VarInt too big")
		}

	}

	return value

}
write_var_int :: proc(buffer: ^bytes.Buffer, value: int) -> uint {

	val := value
	length: uint = 1

	for {
		if (val & ~SEGMENT_BITS) == 0 {
			bytes.buffer_write_byte(buffer, u8(val))
			return length
		}
		bytes.buffer_write_byte(buffer, u8((val & SEGMENT_BITS) | CONTINUE_BIT))

		val >>= uint(7)
		length += 1
	}

}

write_string :: proc(buffer: ^bytes.Buffer, value: string) -> uint {

	length := uint(len(value))
	len := write_var_int(buffer, int(length))
	for i in 0 ..< length {
		bytes.buffer_write_byte(buffer, (transmute([]u8)value)[i])
	}
	return len + length
}

read_string :: proc(buffer: ^bytes.Buffer) -> string {

	len := read_var_int(buffer)


	data: []u8 = make([]u8, len)

	for i in 0 ..< len {
		byte, err := bytes.buffer_read_byte(buffer)
		if err != nil {
			fmt.panicf("error reading string: %s", err)
		}
		data[i] = byte
	}

	return string(data)
}

@(private)
reverse_slice :: proc(slice: []$I) -> []I {
	reversed := make([]I, len(slice))
	for i in 0 ..< len(slice) {
		reversed[len(slice) - 1 - i] = slice[i]
	}
	return reversed
}

read_bytes :: proc(buffer: ^bytes.Buffer, length: u32) -> []u8 {

	data: [dynamic]u8

	for i in 0 ..< length {
		temp_data, _ := bytes.buffer_read_byte(buffer)
		append(&data, temp_data)
	}


	return data[:]
}

read_long :: proc(buffer: ^bytes.Buffer) -> i64 {

	val: u64 = 0
	pos: u16 = 7 * 8

	for i in 0 ..< 8 {
		temp, err := bytes.buffer_read_byte(buffer)
		if err != nil {
			fmt.panicf("error reading long: %s", err)
		}

		val |= u64(temp) << pos

		pos -= 8
	}


	return i64(val)
}

write_long :: proc(buffer: ^bytes.Buffer, value: i64) -> uint {


	transmuted: [8]u8 = (transmute([8]u8)value)

	// Convert the array to a slice if needed
	slice := transmuted[:]
	val := (transmute(i64)(transmuted))
	fmt.printfln("transmuted val %i", val)


	bytes.buffer_write(buffer, slice)
	return 8
}

read_short :: proc(buffer: ^bytes.Buffer) -> u16 {

	val: u16 = 0
	pos: u16 = 1 * 8

	for i in 0 ..< 2 {
		temp, err := bytes.buffer_read_byte(buffer)
		if err != nil {
			fmt.panicf("error reading short: %s", err)
		}

		val |= u16(temp) << pos

		pos -= 8
	}

	return val
}
