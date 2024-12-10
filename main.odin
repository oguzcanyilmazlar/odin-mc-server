package main

import "core:bytes"
import "core:fmt"
import "core:mem"
import "core:mem/virtual"
import "core:net"
import "core:strings"
import "core:sync"
import "core:thread"

clientData :: struct {
	client_socket: net.TCP_Socket,
	waitgroupdata: ^sync.Wait_Group,
}

main :: proc() {

	default_allocator := context.allocator
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, default_allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
		err := false

		for _, val in a.allocation_map {
			fmt.printf("%v leaked:%v bytes \n", val.location, val.size)
			err := true
		}
		mem.tracking_allocator_clear(a)
		return err
	}
	defer reset_tracking_allocator(&tracking_allocator)

	wg: sync.Wait_Group
	threadPool := make([dynamic]^thread.Thread, 0, 20)
	defer delete(threadPool)

	// setting up socket for our server
	listen_socket, listen_err := net.listen_tcp(
		net.Endpoint{port = 25565, address = net.IP4_Loopback},
	)
	if listen_err != nil {
		fmt.panicf("listen error : %s", listen_err)
	}

	// setting up socket for the client to connect to

	for {
		sync.wait_group_add(&wg, 1)
		client_soc, client_endpoint, accept_err := net.accept_tcp(listen_socket)
		if accept_err != nil {
			fmt.panicf("%s", accept_err)
		}
		thr := thread.create(handleClient)
		thr.data = &clientData{client_socket = client_soc, waitgroupdata = &wg}
		append(&threadPool, thr)
		thread.start(thr)
	}
	sync.wait_group_wait(&wg)

	fmt.println("Program Ended")

	// fmt.println("Hellope!")

	// listen_socket, listen_err := net.listen_tcp(
	// 	net.Endpoint{port = 25565, address = net.IP4_Loopback},
	// )

	// if listen_err != nil {
	// 	fmt.panicf("listen err: %s", listen_err)
	// }

	// fmt.printfln("listening on port %i", 25565)

	// client_socket, client_endpoint, accept_err := net.accept_tcp(listen_socket)

	// if accept_err != nil {
	// 	fmt.panicf("accept conn err: %s", accept_err)
	// }


	// fmt.printfln("got connection from %s", net.address_to_string(client_endpoint.address))

	// handleClient(client_socket)

}

MAX_PACKET_LEN :: 1024


PlayerConnection :: struct {
	socket: net.TCP_Socket,
	state:  PacketState,
}

PacketState :: enum {
	HANDSHAKE,
	STATUS,
	LOGIN,
	CONFIGURATION,
	TRANSFER,
	PLAY,
}

handleClient :: proc(t: ^thread.Thread) {

	client_data := (cast(^clientData)t.data)
	client := client_data.client_socket

	state := PacketState.HANDSHAKE

	playerConnection := PlayerConnection {
		socket = client,
		state  = .HANDSHAKE,
	}

	for {

		temp: [MAX_PACKET_LEN]u8
		readBytes, err := net.recv_tcp(client, temp[:])
		if err != nil {
			fmt.panicf("recv_tcp err: %s", err)
		}
		if readBytes == 0 {
			continue
		}
		data: []u8 = temp[:readBytes]
		buffer := bytes.Buffer{}
		bytes.buffer_init(&buffer, data)

		length := read_var_int(&buffer)
		packet_id := read_var_int(&buffer)

		#partial switch state {
		case .HANDSHAKE:
			handle_handshake(&playerConnection, &buffer, packet_id, &state)
		case .STATUS:
			handle_status(&playerConnection, &buffer, packet_id, &state)
		case .LOGIN:
			handle_login(&playerConnection, &buffer, packet_id, &state)
		case .CONFIGURATION:
			handle_configuration(&playerConnection, &buffer, packet_id, &state)
		case .PLAY:
			handle_play(&playerConnection, &buffer, packet_id, &state)
		}

		fmt.printfln(
			"read(%i):\n\tlength:%i\n\tpacket_id:%i\n\tbytes: %X\n\tstring: %s",
			len(data),
			length,
			packet_id,
			buffer.buf[:],
			buffer.buf[:],
		)
		// if packet_id == 0x0 {
		// 	read_handshake(&buffer)
		// }

	}

	fmt.println("yo ended")

}
