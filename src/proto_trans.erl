%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 22. 十月 2016 17:33
%%%-------------------------------------------------------------------
-module(proto_trans).
-author("Administrator").
-include("fullpow_pb.hrl").
%% API
-export([call/3,call/4, co_call/5,reply/2,ac_call/4]).
ac_call({battle,RoomPid},AcMsg,_Socket,SPid) -> ok,
		room:do_movement(RoomPid, SPid,	AcMsg).

call(exc_quit,Socket,Pid) ->
	co_call(quit,7,exception,Socket,Pid).

call(Status,<<1:8,AcMsg/binary>>,Socket,Pid) ->


	ac_call(Status,AcMsg,Socket,Pid);

call(Status,<<Number:32,Msg/binary>>,Socket,Pid) ->


	co_call(Status,Number,Msg,Socket,Pid).

co_call(unknown,3,Msg,Socket,Pid) ->

			 {accountloginreq,Account,Password} = fullpow_pb:decode_accountloginreq(Msg),
									account_bank:login(Account,Password,Socket,Pid),
									login;

co_call(unknown,1,Msg,Socket,Pid) ->

				{accountcreatereq,Account,Password} = fullpow_pb:decode_accountcreatereq(Msg),
				account_bank:create(Account,Password,Socket,Pid),
				create;
%%//5 客户端请求查看账户信息 此时状态为 access
%%message AccountCheckReq {
%%}
co_call(access,5,Msg,Socket,Pid) ->
				{accountcheckreq} = fullpow_pb:decode_accountcheckreq(Msg),
				account_bank:check(Socket,Pid),
 				check;
%%
%%//7 客户端请求退出账户 此时状态为 任意
%%message AccountQuitReq {
%%
%%}
co_call(_Any,7,Msg,Socket,Pid) ->

	account_bank:quit(Socket,Pid,Msg),
	quit;

co_call(access,15,Msg,Socket,SPid) ->

				{join,undefine};

co_call(_Other,_Number,_Msg,_Socket,_Pid) ->
	error.


%%CMDCode = <<4>>,
%%Resp = {accountloginresp,1},
%%io:format("bank send resp ~n"),
%%tcp_server_handler:send(SPid,Socket,CMDCode,Resp);
%% BinaryData = iolist_to_binary(fullpow_pb:encode(Resp)),
%%Pack= list_to_binary([Code,BinaryData]),
%%%TODO In startzone
%%message AccountCreateResp {
%%repeated int32 reply = 1; //0：其他异常 1：正常 2：账号已存在
%%}

reply(StatusOrType,Msg) ->
	{NewS,Code,Bin} = reply_bin(StatusOrType,Msg),
	case  Bin of
		nil ->	<<Code:32>>;
		_Other ->{NewS,<<Code:32,Bin/binary>>}
	end.

%%
%%//10 服务器发送的心跳信息，保持socket连接不超时
%%message BeatResp {
%%repeated int32  = 1;
%%}




reply_bin(beat,Msg) ->
  Code = 10,
  {Bin,NewS} = {iolist_to_binary(fullpow_pb:encode({beatresp,Msg})),
                keep},
  {NewS,Code,Bin};


%%//12 服务端回复退出账户  此时状态为 join 成功状态更新为{battle,RoomPid} 不成功更新为 access
%%message AccountJoinResp {
%%repeated int32 reply = 1; //1成功，2人满 3超时
%%}
reply_bin({join,RoomPid},Msg) ->
	Code = 12,
	{Bin,NewS} =
		case Msg of
				ok ->		 		{iolist_to_binary(fullpow_pb:encode({accountjoinresp,1})),
										{battle,RoomPid}};
				full -> 		{iolist_to_binary(fullpow_pb:encode({accountjoinresp,2})),
										access};
				timeout ->	{iolist_to_binary(fullpow_pb:encode({accountjoinresp,3})),
										access}
		end,
	{NewS,Code,Bin};
reply_bin(create,Msg) ->


					Code = 2,
				{Bin,NewS} =
					case Msg of
						ok -> { iolist_to_binary(fullpow_pb:encode({accountcreateresp,1})),
								unknown};
						same -> { iolist_to_binary(fullpow_pb:encode({accountcreateresp,2})),
								unknown};
						_Other ->{iolist_to_binary(fullpow_pb:encode({accountcreateresp,0})),
								unknown}
					end,
			{NewS,Code,Bin};
%%//4 服务端回复登录 此时状态为login
%%message AccountLoginResp {
%%repeated int32 reply = 1;
%%// 0：其他异常 状态变为unknown 1：正常 状态变为access 2：账号不存在 状态变为unknown
%%// 3：密码错误 状态变为unknown 4: 换socket登录 状态变为access
%%}
reply_bin(login,Msg) ->

					Code = 4,
				{Bin,NewS} =
					case Msg of
									ok -> 			{iolist_to_binary(fullpow_pb:encode({accountloginresp,1})),
															access};
									not_exist ->{iolist_to_binary(fullpow_pb:encode({accountloginresp,2})),
															unknown};
									wrong_ps -> {iolist_to_binary(fullpow_pb:encode({accountloginresp,3})),
															unknown};
									other -> 		{iolist_to_binary(fullpow_pb:encode({accountloginresp,4})),
															access};
									_Other -> 	{iolist_to_binary(fullpow_pb:encode({accountloginresp,0})),
															unknown}
					end,

			{NewS,Code,Bin};
%%//6 服务端回复查看账户信息 此时状态为 check
%%message AccountCheckResp {
%%
%%repeated string nickname = 1;
%%repeated int32 gold = 2;
%%}

reply_bin(check,Msg) ->
			Code = 6,
	{Nickname,Gold} =Msg,
	{Bin,NewS} = {iolist_to_binary(fullpow_pb:encode({#accountcheckmoneyresp{nickname = Nickname,money = Gold}})),access},
	{NewS,Code,Bin};

%%
%%//8 服务端回复退出账户 状态更新为 unknown
%%message AccountQuitResp {
%%
%%}

reply_bin(quit,_Msg) ->
	Code = 8,
	{Bin,NewS} ={nil,unknown},
	{NewS,Code,Bin};



reply_bin(_Other,Msg) ->
			Code = 0,
	{Bin,NewS} =
			case Msg of
						status_error ->		{iolist_to_binary(fullpow_pb:encode({errorresp,1})),
															warning};
						other ->					{iolist_to_binary(fullpow_pb:encode({errorresp,2})),
															warning};
						afk ->            {iolist_to_binary(fullpow_pb:encode({errorresp,3})),
															warning};
						too_much ->       {iolist_to_binary(fullpow_pb:encode({errorresp,4})),
															warning};
						_SomeOther    -> 	{iolist_to_binary(fullpow_pb:encode({errorresp,0})),
															warning}
			end,
			{NewS,Code,Bin}.


