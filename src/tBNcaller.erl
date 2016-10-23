%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 22. 十月 2016 17:33
%%%-------------------------------------------------------------------
-module(tBNcaller).
-author("Administrator").

%% API
-export([call/3]).

call(Data,Socket,Pid) ->
	<<Number:1/binary,Msg/binary>> = Data,
	case Number of
		<<3>> ->
			{accountLoginReq,Account,Password}=fullpow_pb:decode(accountLoginReq,Msg),
			accountBank:login(binary_to_list(Account),binary_to_list(Password),Socket,Pid);
		_Other -> unknown
	end;


call(_,_,_) ->ok.