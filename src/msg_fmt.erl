%%%-------------------------------------------------------------------
%%% @author Feather.et.ELF <fledna@qq.com>
%%% @copyright (C) 2012, Feather.et.ELF
%%% @doc
%%% hi msg format
%%% @end
%%% Created : 14 Jul 2012 by Feather.et.ELF <fledna@qq.com>
%%%-------------------------------------------------------------------
-module(msg_fmt).

%% API
-export([img_tag/1, make_imgdata/1]).

%%%===================================================================
%%% API
%%%===================================================================
make_imgdata(Data) ->
    Md5 = util:to_hex_string(crypto:md5(Data)),
    ImageData = base64:encode_to_string(Data),
    {ok, Md5, ImageData}.

img_tag({imgdata, Type, Data}) ->
    {ok, Md5, ImageData} = make_imgdata(Data),
    {img, [{md5, Md5}, {t, Type}, {n, lists:sublist(Md5, 8)}],
     [{image, [{imagedata, ImageData}], []}]}.



%%--------------------------------------------------------------------
%% @doc
%% @spec
%% @end
%%--------------------------------------------------------------------

%%%===================================================================
%%% Internal functions
%%%===================================================================
