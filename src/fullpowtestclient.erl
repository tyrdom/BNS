-module (fullpowtestclient).
-compile(export_all).


start_clients() -> %开一个线程连接socket  fullpowtestclient:start_clients().
	spawn_link(fun() -> client_start(2222) end).

client_start(Port) ->
	{ok,Socket} =
		gen_tcp:connect("PC-TIANHAO",Port,[binary,{packet,0}]),
	%start_send_tick()
	loop(Socket).

loop(Socket) ->
	receive
		{tcp,Socket,Bin} ->
			<<Code:1/binary,Msg/binary>> = Bin,
			case Code of
				 <<4>> -> Back = fullpow_pb:decode_accountloginresp(Msg),
				io:format("client recieve ~p ~n",[Back]),
				loop(Socket);
				Other->io:format("client recieve ~p ~n",[Other])
end
	after 3000 ->
			Account = "cddd",
			Password ="dddd",
			SendCode = <<3>>,
			BinData = fullpow_pb:encode({accountloginreq,Account,Password}),
			Pack = list_to_binary([SendCode,BinData]),
			io:format("client goto send =~p~n",[Pack]),
			ok = gen_tcp:send(Socket,Pack),
			loop(Socket)
	end.