%%%-------------------------------------------------------------------
%% @doc BNS public API
%% @end
%%%-------------------------------------------------------------------

-module(tBNS_app).

-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).
-include("net_settings.hrl").
%%====================================================================
%% API
%%====================================================================

start(_StartType, _StartArgs) -> % tBNS_app:start(a,b).
    tcp_server_app:start(?PORT),accountBank:start_link(),zone:start_link().

%%--------------------------------------------------------------------
stop(_State) ->
    ok.

%%====================================================================
%% Internal functions
%%====================================================================
