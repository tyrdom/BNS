%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 18. 十一月 2016 10:51
%%%-------------------------------------------------------------------
-author("Administrator").
-record(s_pid_info,{account_id, socket,special_status}).
-record(bank_state, {accountBank, sock_pid_account_table,mysqlPid,zonePid}).
-record(account_info,{account_login,account_check}).

-record(account_login, {
  socket ,
  sPid ,
  password_in_db
}).
-record(account_check,{
  nickname,
  gold
}).

