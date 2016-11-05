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
-export([encode/0,encode2/0,decode/1,decode2/1,msqtry/0,msqinst/0]).

encode() -> %test apps_test:encode().
  Person = #person{age=25, name="John"},
  iolist_to_binary(test_pb:encode_person(25,"jjj")).

decode(Data) -> %test apps_test:decode(data).


  test_pb:decode_person(Data).

encode2() -> %test apps_test:encode2().
  RepeatData =
    [
      #person{age=25, name="John"},
      #person{age=23, name="Lucy"},
      #person{age=2, name="Tony"}
    ],
  Family = #family{person=RepeatData},
  iolist_to_binary(test_pb:encode_family(Family)).

decode2(Data) -> %test apps_test:dncode2(Data).

  test_pb:decode_family(Data).

msqtry() -> %apps_test:msqtry().
  {ok, Pid} = mysql:start_link([{host, "192.168.1.243"}, {user, "root"},
    {password, "caiwei"}, {database, "tianhao"}]),
  PasswordInDB =accountBank:md5_string("dddd"),

%%  {ok, _ColumnNames, Rows} =
%%    mysql:query(Pid, <<"SELECT account_id,password,up_time FROM account_auth WHERE account_id = ? AND password= ?">>, ["cccc",PasswordInDB]),
  {ok, _ColumnNames, Rows} =
    mysql:query(Pid, <<"SELECT id,globe_in,globe_out FROM cacula_globe WHERE id = ? ">>, [1]),

  Rows.

msqinst() -> %apps_test:msqinst().
  {ok, Pid} = mysql:start_link([{host, "192.168.1.243"}, {user, "root"},
    {password, "caiwei"}, {database, "tianhao"}]),
  PS = accountBank:md5_string("dddd"),
  ok = mysql:query(Pid, "INSERT INTO account_auth (account_id, password) VALUES (?, ?)", ["cccc", PS]).
