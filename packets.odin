package main

import "core:bytes"
import "core:encoding/json"
import "core:encoding/uuid"
import "core:fmt"
import "core:net"

handle_handshake :: proc(
	conn: ^PlayerConnection,
	buffer: ^bytes.Buffer,
	packet_id: int,
	state: ^PacketState,
) {
	switch packet_id {
	case 0:
		read_handshake(buffer, state)
	}
}

ServerPing :: struct {
	version:     struct {
		name: string,
	},
	description: struct {
		text: string,
	},
}

read_handshake :: proc(buffer: ^bytes.Buffer, state: ^PacketState) {
	protocol_version := read_var_int(buffer)
	server_addr := read_string(buffer)
	port := read_short(buffer)
	next_state := read_var_int(buffer)

	fmt.printfln(
		"protocol: %i\nserver_addr: %s\nport: %i\nnext_state: %i",
		protocol_version,
		server_addr,
		port,
		next_state,
	)

	state^ = PacketState(next_state)
}

handle_status :: proc(
	conn: ^PlayerConnection,
	buffer: ^bytes.Buffer,
	packet_id: int,
	state: ^PacketState,
) {
	switch packet_id {
	case 0:
		read_status(conn)
	case 1:
		read_ping(buffer, conn)
	case:
		fmt.printfln("got packet id %i", packet_id)
	}
}


read_ping :: proc(buffer: ^bytes.Buffer, conn: ^PlayerConnection) {
	value := read_long(buffer)
	fmt.printfln("got ping %i", value)
	buffer := send_server_pong(value)
	send_packet(conn, 1, buffer.buf[:])

}

send_server_pong :: proc(ping: i64) -> bytes.Buffer {
	buffer := bytes.Buffer{}
	write_long(&buffer, ping)
	return buffer

}

read_status :: proc(conn: ^PlayerConnection) {
	fmt.println("state is status")
	buffer := send_server_list_ping()
	send_packet(conn, 0, buffer.buf[:])
}

send_packet :: proc(conn: ^PlayerConnection, packet_id: uint, data: []u8) {

	temp := bytes.Buffer{}

	length := write_var_int(&temp, int(packet_id))
	length = length + len(data)

	buffer := bytes.Buffer{}
	write_var_int(&buffer, int(length))
	write_var_int(&buffer, int(packet_id))
	bytes.buffer_write(&buffer, data)

	_, err := net.send_tcp(conn.socket, buffer.buf[:])
	if err != nil {
		fmt.panicf("err sending server list ping: %s", err)
	}
}


send_server_list_ping :: proc() -> bytes.Buffer {
	buffer := bytes.Buffer{}
	data, err := json.marshal(
		ServerPing{version = {name = "sa"}, description = {text = "deneme 1 2"}},
	)
	if err != nil {
		fmt.panicf("err marshaling server list ping: %s", err)
	}
	write_string(&buffer, string(data))
	return buffer

}

handle_login :: proc(
	conn: ^PlayerConnection,
	buffer: ^bytes.Buffer,
	packet_id: int,
	state: ^PacketState,
) {
	switch packet_id {
	case 0:
		read_login_start(buffer, conn)
	case 3:
		fmt.println("login ack, switching state to configuration")
		state^ = .CONFIGURATION
	}
}


read_login_start :: proc(buffer: ^bytes.Buffer, conn: ^PlayerConnection) {
	player_name := read_string(buffer)
	read_long(buffer)
	read_long(buffer)
	fmt.printfln("playername: %s", player_name)
	data := write_login_success(conn, &player_name).buf
	send_packet(conn, 0x02, data[:])
}

write_login_success :: proc(conn: ^PlayerConnection, playerName: ^string) -> bytes.Buffer {
	buffer := bytes.Buffer{}
	player_uuid := uuid.generate_v8_hash_string(
		uuid.Namespace_X500,
		fmt.aprintf("PlayerOffline:%s", playerName),
		.SHA256,
	)
	bytes.buffer_write(&buffer, player_uuid[:])
	write_string(&buffer, playerName^)
	write_var_int(&buffer, 0)
	return buffer
}

handle_configuration :: proc(
	conn: ^PlayerConnection,
	buffer: ^bytes.Buffer,
	packet_id: int,
	state: ^PacketState,
) {
	switch packet_id {
	case 0:
		handle_client_information(conn, buffer)
	case 2:
		handle_plugin_message(conn, buffer)
	case 3:
		state^ = .PLAY
		fmt.println("changed state to play")
	}
}

handle_client_information :: proc(conn: ^PlayerConnection, buffer: ^bytes.Buffer) {
	locale := read_string(buffer)
	view_distance, _ := bytes.buffer_read_byte(buffer)
	chat_mode := read_var_int(buffer)
	chat_colors, _ := bytes.buffer_read_byte(buffer)
	skin_parts, _ := bytes.buffer_read_byte(buffer)
	main_hand := read_var_int(buffer)
	text_filtering, _ := bytes.buffer_read_byte(buffer)
	server_listing, _ := bytes.buffer_read_byte(buffer)
	fmt.printfln("locale: %s, server_listing: %i", locale, server_listing)
	data: [0]u8
	send_packet(conn, 0x03, data[:])
}

send_finish_configuration :: proc(conn: ^PlayerConnection) {

}

handle_plugin_message :: proc(conn: ^PlayerConnection, buffer: ^bytes.Buffer) {
	channel_name := read_string(buffer)
	data_len := bytes.buffer_length(buffer)
	fmt.printfln("channel_name: %s", channel_name)
	switch channel_name {
	case "minecraft:brand":
		brand_name := read_string(buffer)
		fmt.printfln("got brand name %s", brand_name)
	}
}

handle_play :: proc(
	conn: ^PlayerConnection,
	buffer: ^bytes.Buffer,
	packet_id: int,
	state: ^PacketState,
) {


}
