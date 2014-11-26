-module(tag_riak_serv).
-behaviour(gen_server).
%% ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/0]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
          code_change/3, terminate/2]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

%Where Pid is the pid of the requesting process (hopefully)
start_link() ->
  gen_server:start_link(?MODULE, [], []).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

%% Starts a link to riak, stores it in state.
init([]) ->
  {ok, Pid} = riakc_pb_socket:start_link("127.0.0.1", 8087),
  {ok, Pid}.

%% Here is where you can add functionaility by making another handle_call function head.
%% Remember to include the API call in tag_riak for any functionaility you want to access

handle_call(update_taglist, _From, SocketPid) ->
	Taglist = case riakc_pb_socket:get(SocketPid, <<"taglistbucket">>, <<"taglist">>) of
        {ok, CurrentTaglist} -> 
          FinalTaglist = binary_to_term(riakc_obj:get_value(CurrentTaglist)),  
          Taglist1 = jiffy:encode({[{<<"tags">>, FinalTaglist}]}),
          Taglist1;
        {error,_} ->
          Taglist1 = jiffy:encode({[{<<"tags">>, <<"Bad List">>}]}),
          Taglist1
  end,
	{reply, Taglist, SocketPid};

%handle_call({setkey, Data}, _From, SocketPid) ->
%	DataMap = jiffy:decode(Data, [return_maps]), 
	%%ProfileImage
%	UserId = maps:get(<<"user_id">>, DataMap, not_found),
%	AuthKey = maps:get(<<"key">>, DataMap, not_found),
%	if AuthKey == not_found, UserId == not_found
%		-> 
%		{reply, bad_request, SocketPid};
%	true 		->
%		Result = riakc_pb_socket:get(SocketPid, <<"users">>, term_to_binary(UserId)),
%		if Result =:= {error, notfound} 
%				 ->     UserMap = #{}; %% put profile image
						%% in ^ "profileimage" => ProfileImage^^
%			true -> 
%				{ok, Object} = Result,
%				UserMap = binary_to_term(riakc_obj:get_value(Object))
%		end,
%		NewUserMap = maps:put("authkey", binary_to_list(AuthKey), UserMap),
%		RiakObj = riakc_obj:new(<<"users">>, term_to_binary(UserId), NewUserMap),
%		riakc_pb_socket:put(SocketPid, RiakObj),
%		{reply, binary_to_list(AuthKey), SocketPid}
%	end;
	%application:ensure_all_started(tw_data_server).

handle_call({setkey, Data}, _From, SocketPid) ->
	DataMap = jiffy:decode(Data, [return_maps]), 
	%%ProfileImage
	UserId = case extract(<<"user_id">>, TestInfo1) of			
	 not_found ->  
		{reply, bad_request, SocketPid};
	true 		->
		Result = riakc_pb_socket:get(SocketPid, <<"users">>, term_to_binary(UserId)),
		if Result =:= {error, notfound} 
				 ->     
				 Object = riakc_obj:new(<<"users">>, term_to_binary(UserId), <<"">>), 
				 %create a new key + values for it Ill add them later
			true -> 
				{ok, Object} = Result,
				User = binary_to_term(riakc_obj:get_value(Object))
		end,
		NewUser = riakc_obj:update_value(SocketPid, binary_to_list(AuthKey), binary_to_list(riakc_obj:get_value(Object)),
		RiakObj = riakc_obj:new(<<"users">>, term_to_binary(UserId), NewUser),
		riakc_pb_socket:put(SocketPid, RiakObj),
		{reply, binary_to_list(AuthKey), SocketPid};
	
	end;
	 
	%application:ensure_all_started(tw_data_server).

handle_call({getuserinfo, Data}, _From, SocketPid) ->
	DataMap = jiffy:decode(Data, [return_maps]), 
	UserId = maps:get(<<"user_id">>, DataMap, not_found),
	AuthKey = maps:get(<<"key">>, DataMap, not_found),
	
	%application:ensure_all_started(tw_data_server).

	
handle_call({testpost, TestInfo}, _From, SocketPid) ->
  {TestInfo1} = jiffy:decode(TestInfo),
  Result = case extract(<<"testid">>, TestInfo1) of
    {found, Val} -> 
      Obj = riakc_obj:new(<<"testpost">>,
        Val,
        term_to_binary(TestInfo1)),
      Result1 = riakc_pb_socket:put(SocketPid, Obj),
      Result1;
    not_found -> bad_request
  end, 
  {reply, Result, SocketPid};

handle_call({gettag, Tag}, _From, SocketPid) ->
  {Distribution, Cotags} = case riakc_pb_socket:get_index_range(
            SocketPid,
            <<"tags">>, %% bucket name
            {integer_index, "timestamp"}, %% index name
            oldTimeStamp(), timeStamp() %% origin timestamp should eventually have some logic attached
          ) of
    {ok, {_,Keys,_,_}} ->
      AllKeys = lists:reverse(lists:sort(Keys)),
      if
        length(AllKeys) >= 20 ->
          {NewKeys,_} = lists:split(20, AllKeys),
          Objects = lists:map(fun(Key) -> {ok, Obj} = riakc_pb_socket:get(SocketPid, <<"tags">>, Key), Obj end, NewKeys),
          Tagset = lists:map(fun(Object) -> Value = binary_to_term(riakc_obj:get_value(Object)), case dict:find(Tag, Value) of {ok, Tagged} -> Tagged; error -> {0, sets:new(),sets:new()} end end, Objects),
          {Distribution1, Cotags1} = loopThrough(Tagset, [], sets:new()),
          {Distribution1, Cotags1};
        (length(AllKeys) >= 2) and (length(AllKeys) rem 2 =:= 0) ->
          Objects = lists:map(fun(Key) -> {ok, Obj} = riakc_pb_socket:get(SocketPid, <<"tags">>, Key), Obj end, AllKeys),
          Tagset = lists:map(fun(Object) -> Value = binary_to_term(riakc_obj:get_value(Object)), case dict:find(Tag, Value) of {ok, Tagged} -> Tagged; error -> {0, sets:new(),sets:new()} end end, Objects),
          {Distribution1, Cotags1} = loopThrough(Tagset, [], sets:new()),
          {Distribution1, Cotags1};
        length(AllKeys) >= 2 ->
          [_|NewKeys] = AllKeys,
          Objects = lists:map(fun(Key) -> {ok, Obj} = riakc_pb_socket:get(SocketPid, <<"tags">>, Key), Obj end, NewKeys),
          Tagset = lists:map(fun(Object) -> Value = binary_to_term(riakc_obj:get_value(Object)), case dict:find(Tag, Value) of {ok, Tagged} -> Tagged; error -> {0, sets:new(),sets:new()} end end, Objects),
          {Distribution1, Cotags1} = loopThrough(Tagset, [], sets:new()),
          {Distribution1, Cotags1};
        true ->
          {[{[{<<"numtags">>, 0}, {<<"tweets">>, ""}]}],[]}
      end;
    {error, _} ->
      {[{[{<<"numtags">>, 0}, {<<"tweets">>, ""}]}],[]}
  end,
  Response = jiffy:encode({[{<<"tag">>, Tag},
  {<<"cotags">>, Cotags},
  {<<"distribution">>, 
    Distribution}]}),

{reply, Response, SocketPid}.

handle_cast(terminate, State) ->
  {noreply, State}.

handle_info(_Msg, State) ->
    {noreply, State}.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

terminate(_Reason, _State) ->
    ok.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

loopThrough([], L, Cotags) -> {L, sets:to_list(Cotags)};
loopThrough(Tagset, L, OldCotags) ->
  {NewKeys,OldKeys} = lists:split(2, Tagset),
  [{Num, Cotags, Tweets}, {Num2, Cotags2, Tweets2}] = NewKeys,
  L2 = [{[{<<"numtags">>, Num + Num2}, {<<"tweets">>, sets:to_list(sets:union([Tweets, Tweets2]))}]}|L],
  NewCotags = sets:union([Cotags, Cotags2, OldCotags]),
  loopThrough(OldKeys, L2, NewCotags).

timeStamp() ->
  {Mega, Secs, Micro} = erlang:now(),
  Mega*1000*1000*1000*1000 + Secs * 1000 * 1000 + Micro.

oldTimeStamp() ->
  {Mega, Secs, Micro} = erlang:now(),
  Mega*1000*1000*1000*1000 + ((Secs - 2400) * 1000 * 1000) + Micro.

extract(K, L) ->
  case lists:keyfind(K, 1, L) of
    {_, M} -> {found, M};
    false  -> not_found
  end.
