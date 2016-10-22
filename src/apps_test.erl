%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 20. 十月 2016 20:21
%%%-------------------------------------------------------------------
-module(apps_test).
-author("Administrator").
-include("test_pb.hrl").
%% API
-export([encode/0,encode2/0,decode/0,decode2/1,msqtry/0]).

encode() -> %test apps_test:encode().
  Person = #person{age=25, name="John"},
  iolist_to_binary(test_pb:encode(Person)).

decode() -> %test apps_test:encode(data).
  Data = encode(),

  test_pb:decode(Data).

encode2() -> %test apps_test:encode2().
  RepeatData =
    [
      #person{age=25, name="John"},
      #person{age=23, name="Lucy"},
      #person{age=2, name="Tony"}
    ],
  Family = #family{person=RepeatData},
  iolist_to_binary(test_pb:encode_family(Family)).

decode2(Data) -> %test test5_go:start().

  test_pb:decode_family(Data).

msqtry() ->
  {ok, Pid} = mysql:start_link([{host, "192.168.1.243"}, {user, "root"},
    {password, "caiwei"}, {database, "tianhao"}]),
  {ok,ColumnNames,Rows} =
    mysql:query(Pid, <<"SELECT daily_regist FROM fishnet_daily_base WHERE id = ?">>, [63]),
  io:format("~p~n",[ColumnNames]),
  io:format("~p~n",[Rows]).