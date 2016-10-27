%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 21. 十月 2016 9:44
%%%-------------------------------------------------------------------

-module(tcp_server_handler).
-behaviour(gen_server).
%%API
-export([start_link/1,send/4]).
%%gen_server
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	terminate/2, code_change/3]).
-record(state, {lsock, socket, addr}).
-define(Timeout, 120*1000).

start_link(LSock) ->
	io:format("tcp handler start link~n"),
	gen_server:start_link(?MODULE, [LSock], []).

init([LSock]) ->
	io:format("tcp handler init ~p ~n",[self()]),
	inet:setopts(LSock, [{active, once}]), % HINT change once to true
	gen_server:cast(self(), tcp_accept),
	{ok, #state{lsock = LSock}}.



handle_call({send,Socket,{Code,Resp}},_From,State) ->
%	inet:setopts(Socket, [{active, once}]),
	io:format("~p server want send ~p ~p ~n",[self(),Code,Resp]),
	BinaryData = iolist_to_binary(fullpow_pb:encode(Resp)),
	Pack= list_to_binary([Code,BinaryData]),

	Reply = gen_tcp:send(Socket, Pack),

	{reply,{ok, Reply} , State};


handle_call(Msg, _From, State) ->
	io:format("tcp handler call ~p~n", [Msg]),
	{reply, {ok, Msg}, State}.

handle_cast(tcp_accept, #state{lsock = LSock} = State) ->
	{ok, CSock} = gen_tcp:accept(LSock),
	io:format("tcp handler info accept client ~p~n", [CSock]),
	{ok, {IP, _Port}} = inet:peername(CSock),
	start_server_listener(self()),
	{noreply, State#state{socket=CSock, addr=IP}, ?Timeout};

handle_cast(stop, State) ->
	{stop, normal, State}.

handle_info({tcp, Socket, Data}, State) ->
	inet:setopts(Socket, [{active, once}]), % HINT change once to true
	io:format("tcp handler info ~p got message ~p~n", [self(), Data]),

	tBNcaller:call(Data,Socket,self()),
	{noreply, State, ?Timeout};

handle_info({send,Socket,{Code,Resp}}, State) ->
	inet:setopts(Socket, [{active, once}]),
 	io:format("~p server want send ~p ~p ~n",[self(),Code,Resp]),
 	BinaryData = iolist_to_binary(fullpow_pb:encode(Resp)),
 	Pack= list_to_binary([Code,BinaryData]),
 	gen_tcp:send(Socket, Pack),
	{noreply, State};

handle_info({tcp_closed, _Socket}, #state{addr=Addr} = State) ->
	io:format("tcp handler info ~p client ~p disconnected~n", [self(), Addr]),
	{stop, normal, State};

handle_info(timeout, State) ->
	io:format("tcp handler info ~p client connection timeout~n", [self()]),
	{stop, normal, State};

handle_info(_Info, State) ->
	io:format("tcp handler info ingore ~p~n", [_Info]),
	{noreply, State}.

terminate(_Reason, #state{socket=Socket}) ->
	io:format("tcp handler terminate ~p~n", [_Reason]),
	(catch gen_tcp:close(Socket)),
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

start_server_listener(Pid) ->
	gen_server:cast(tcp_server_listener, {tcp_accept, Pid}).



%handle_call({send,Socket,{Code,Resp}},_From,State)
send(Spid,Socket,CMDCode,Resp)
		->Spid!{send,Socket,{CMDCode,Resp}}.