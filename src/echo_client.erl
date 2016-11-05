%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 31. 十月 2016 19:08
%%%-------------------------------------------------------------------
-module(echo_client).
-author("Administrator").

%% API

-export([send/1]).

send(BinMsg) -> %echo_client:send(<<"2323">>).
  SomeHostInNet = "PC-TIANHAO",
  {ok, Sock} = gen_tcp:connect(SomeHostInNet, 2222,
    [binary, {packet, 4}]),
  ok = gen_tcp:send(Sock, BinMsg),
  receive
    {tcp,Socket,String} ->
      io:format("Client received = ~p~n",[String]),
      gen_tcp:close(Socket)
  after 10000 ->
    exit
  end,
  ok = gen_tcp:close(Sock).