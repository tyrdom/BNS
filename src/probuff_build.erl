%%%-------------------------------------------------------------------
%%% @author Administrator
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 20. 十月 2016 20:17
%%%-------------------------------------------------------------------
-module(probuff_build).
-author("Administrator").

%% API
-export([start/0]).

start() -> %test probuff_build:start().
  A="priv/test.proto",
  OutIncludeDir ="include",
  OutBeamDir = "_build/default/lib/tBNS/ebin",
%%--------------------------------------------------------------------
%% @doc Generats a built .beam file and header file .hrl
%%      Considerd option properties: output_include_dir,
%%                                   output_ebin_dir,
%%                                   imports_dir
%%--------------------------------------------------------------------
  B= protobuffs_compile:scan_file(A,[{output_include_dir,OutIncludeDir},{output_ebin_dir,OutBeamDir}]),
  io:format("~p~n",[B]).
