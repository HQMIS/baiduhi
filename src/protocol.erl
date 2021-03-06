%%%-------------------------------------------------------------------
%%% @author Feather.et.ELF <fledna@qq.com>
%%% @copyright (C) 2012, Feather.et.ELF
%%% @doc
%%%
%%% @end
%%% Created :  5 Jul 2012 by Feather.et.ELF <fledna@qq.com>
%%%-------------------------------------------------------------------
-module(protocol).

%% API
-export([decode_impacket/1, encode_impacket/1, build_dynamic_password/2]).
-export([make_packet/3, make_packet/1]).
-export([make_stage_data/1, make_stage_data/2]).

-include("const.hrl").

%%%===================================================================
%%% API
%%%===================================================================
make_stage_data(stage1) ->
    EPVer = 1,
    ConMethod = <<2, 0, 0, 0>>,
    <<EPVer:?UINT8, ConMethod:4/binary, 0:?UINT32, 0:?UINT32, 0:?UINT32>>.

make_stage_data(stage3, Data) ->
    <<0:?UINT32, 0:?UINT32, (byte_size(Data)):?UINT32, Data/binary>>.

make_packet(stage, ConFlag, Data) ->
    HeartBeat = 0,
    Compress = 0,
    Encrypt = 0,
    BinData = iolist_to_binary(Data),
    SrcDataLen = ZipDataLen = DestDataLen = byte_size(BinData),
    Category = 0,
    SendFlag = 0,
    _Packet = <<?BIN_PRO_VER_1_0:?UINT32, ?CT_TAG:?UINT32, % const
                0:2, HeartBeat:1, Compress:1, Encrypt:1, ConFlag:3, 0:24,
                SrcDataLen:?UINT32,
                ZipDataLen:?UINT32,
                DestDataLen:?UINT32,
                SendFlag:?UINT32, Category:?UINT32,       % no used
                0:?UINT32, 0:?UINT32,                     % padding
                BinData:SrcDataLen/binary>>;
make_packet(normal, Data, AESKey) ->
    HeartBeat = 0,
    Compress = 0,
    Encrypt = 1,
    SrcData = iolist_to_binary(Data),
    ZipData = SrcData,
    DestData = util:aes_encrypt(ZipData, AESKey),
    SrcDataLen = ZipDataLen = byte_size(SrcData),
    DestDataLen = byte_size(DestData),
    Category = 0,
    SendFlag = 0,
    _Packet = <<?BIN_PRO_VER_1_0:?UINT32, ?CT_TAG:?UINT32, % const
                0:2, HeartBeat:1, Compress:1, Encrypt:1, ?CT_FLAG_CON_OK:3,
                0:24,                           % padding
                SrcDataLen:?UINT32,
                ZipDataLen:?UINT32,
                DestDataLen:?UINT32,
                SendFlag:?UINT32, Category:?UINT32,       % no used
                0:?UINT32, 0:?UINT32,                     % padding
                DestData:DestDataLen/binary>>.
make_packet(heartbeat) ->
    HeartBeat = 1,
    Compress = 0,
    Encrypt = 0,
    SrcDataLen = ZipDataLen = DestDataLen = 0,
    Category = 0,
    SendFlag = 0,
    _Packet = <<?BIN_PRO_VER_1_0:?UINT32, ?CT_TAG:?UINT32, % const
                0:2, HeartBeat:1, Compress:1, Encrypt:1, ?CT_FLAG_KEEPALIVE:3,
                0:24,                           % padding
                SrcDataLen:?UINT32,
                ZipDataLen:?UINT32,
                DestDataLen:?UINT32,
                SendFlag:?UINT32, Category:?UINT32,
                0:?UINT32, 0:?UINT32>>.

encode_impacket({{Command, Version, Type, Seq}, Params, Body}) ->
    TypeChar = case Type of
                   ack -> "A";
                   notify -> "N";
                   request -> "R"
               end,
    Header = make_impacket_header(Command, Version, TypeChar, Seq),
    make_impacket(Header, Params, Body).

decode_impacket(IMPacket) ->
    Text = binary:bin_to_list(IMPacket),
    Index = case string:str(Text, "\r\n\r\n") of
                0 -> length(Text);
                _Index -> _Index
            end,
    Body = lists:takewhile(
             fun(C) -> (C =/= $\0) end,
             lists:dropwhile(fun(C) -> (C =:= $\r) or (C =:= $\n) end,
                             lists:nthtail(Index, Text))),
    FullHeader = lists:sublist(Text, 1, Index+1),  % full header
    %% first command line
    CommandLine = lists:takewhile(fun(C) -> C =/= $\r end, FullHeader),
    CommandTokens = string:tokens(CommandLine, " \r\n"),
    Command = list_to_atom(lists:nth(1, CommandTokens)),
    Version = lists:nth(2, CommandTokens),
    Type = case lists:nth(3, CommandTokens) of
               "A" -> ack;
               "R" -> request;
               "N" -> notify
           end,
    Seq = list_to_integer(lists:nth(4, CommandTokens)),
    %% header
    Header = string:strip(lists:dropwhile(fun(C) -> C =/= $\r end, FullHeader)),
    HeaderTokens = string:tokens(Header, "\r\n"),
    _HeaderAssoc = lists:map(fun(T) -> lists:splitwith(fun(C) -> C =/= $: end, T) end, HeaderTokens),
    _Params = lists:map(fun({Key, Val}) ->
                                _Key = list_to_atom(Key),
                                %% strip space, sometimes method: xxx
                                _Val = string:strip(lists:nthtail(1, Val)),
                                case string:to_integer(_Val) of
                                    {IntVal, ""} -> {_Key, IntVal};
                                    _            -> {_Key, _Val}
                                end
                        end, _HeaderAssoc),
    %% sort and make 'method' first elem
    Params = lists:sort(fun({Key1, _}, {Key2, _}) ->
                                case {Key1, Key2} of
                                    {method, _} -> true;
                                    {_, method} -> false;
                                    {code, _}   -> true;
                                    {_, code}   -> false;
                                    _           -> false
                                end
                        end, _Params),
    {{Command, Version, Type, Seq}, Params, Body}.


build_dynamic_password(Password, Seed) ->
    PassComb = util:to_hex_string(crypto:md5(Password)) ++ Seed,
    util:to_hex_string(crypto:md5(PassComb)).


%%%===================================================================
%%% Internal functions
%%%===================================================================
make_impacket_header(Command, Version, Type, Seq) ->
    io_lib:format("~s ~s ~s ~w", [Command, Version, Type, Seq]).
make_impacket(Header, Params, Body) ->
    _Params = lists:keymap(fun util:to_list/1, 2, Params),
    ParamLines = lists:map(fun({Key,Val}) ->
                                   io_lib:format("~s:~s", [util:to_list(Key),
                                                           util:to_list(Val)])
                           end, _Params),
    string:join([Header | ParamLines] ++ ["", Body], "\r\n").
