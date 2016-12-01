%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 18. 十一月 2016 10:51
%%%-------------------------------------------------------------------
-author("Administrator").
-record(sock_pid_account_info,{account_id, socket,special_status}).
-record(bank_state, {accountBank, sock_pid_account_table,mysqlPid}).
-record(account_info,{account_login,account_check}).

-record(account_login, {
  socket ,
  sPid ,
  password_in_db
}).
-record(account_check,{
  nickname,
  gold,
  rank
}).

-record(room_info,{type,player_num,allow_players,average_rank,info}).

-define(ROOM_MAX,8).

-record(sock_pid_battle_info,{movement,lost_tick,r_times,seat}).
-record(seat_info,{seat,sock_pid,rank}).