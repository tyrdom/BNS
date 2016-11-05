%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 31. 十月 2016 18:29
%%%-------------------------------------------------------------------
-module(ranc_tcp).
-author("Administrator").
-include("net_settings.hrl").
%% API
-export([start/0]).

start () -> %ranc_tcp:start().
  application:start(ranch,permanent),
  {ok, _Pid}  = ranch:start_listener(tcp_reverse, 6,
ranch_tcp, [{port, ?PORT},{max_connections, 1024}], ranc_client, []),
  ranc_sup:start_link().