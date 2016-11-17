%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 22. 十月 2016 17:33
%%%-------------------------------------------------------------------
-module(tBN_proto_trans).
-author("Administrator").

%% API
-export([call/4,reply/2]).

call(Status,Data,Socket,Pid) ->
	<<Number:32,Msg/binary>> = Data,

	call(Status,Number,Msg,Socket,Pid).

call(unknown,3,Msg,Socket,Pid) ->

			 {accountloginreq,Account,Password} = fullpow_pb:decode_accountloginreq(Msg),
									account_bank:login(Account,Password,Socket,Pid),
									login;

call(unknown,1,Msg,Socket,Pid) ->

				{accountcreatereq,Account,Password} = fullpow_pb:decode_accountcreatereq(Msg),
				account_bank:create(Account,Password,Socket,Pid),
				create;
%%//5 客户端请求查看账户信息 此时状态为 access
%%message AccountCheckReq {
%%}
call(access,5,Msg,Socket,Pid) ->
				{accountcheckreq} = fullpow_pb:decode_accountcheckreq(Msg),
				account_bank:check(Socket,Pid),
 			check;

call(_Other,_Number,_Msg,_Socket,_Pid) ->
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

reply(Status,Msg) ->
	{NewS,Code,Bin} = reply_bin(Status,Msg),
	{NewS,<<Code:32,Bin/binary>>}.

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




reply_bin(_Other,Msg) -> error,
			Code = 0,
	{Bin,NewS} =
			case Msg of
						status_error ->		{iolist_to_binary(fullpow_pb:encode({errorresp,1})),
															warning};
						other ->					{iolist_to_binary(fullpow_pb:encode({errorresp,2})),
															warning};
						_Other       -> 	{iolist_to_binary(fullpow_pb:encode({errorresp,0})),
															warning}
			end,
			{NewS,Code,Bin}.


