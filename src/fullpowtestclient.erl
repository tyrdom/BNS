-module (fullpowtestclient).
-compile(export_all).
-include("net_settings.hrl").

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
%%			<<_Code:1/binary,Msg/binary>> = Bin,
%%			 Back = fullpow_pb:decode_accountloginresp(Msg),
				io:format("client recieve ~p ~n",[Bin]),
				loop(Socket);
		{error,closed} -> io:format("client recieve error ~n"),loop(Socket)

	after 3000 ->
%%			Account = "cddd",
%%			Password ="dddd",
%%			SendCode = <<3>>,
%%			BinData = fullpow_pb:encode({accountloginreq,Account,Password}),
%%			Pack = list_to_binary([SendCode,BinData]),
%%			io:format("client goto send =~p~n",[Pack]),
			ok = gen_tcp:send(Socket,<<"3333">>),
			loop(Socket)
	end.