#!/usr/bin/env escript

main(_) ->
	io:format("Generating edocs~n"),
	{ok, Files} = file:list_dir("./src"),
	ErlPred = fun(F) -> is_erl_file(F) end,
	ErlFiles = lists:filter(ErlPred, Files),
	Modules = ["src/" ++ F || F <- ErlFiles],
        edoc:files(Modules, [{dir, "erl8583/doc"}]).

is_erl_file(FileName) when length(FileName) >= 4 ->
	Length = length(FileName),
	lists:sublist(FileName, Length-3, 4) =:= ".erl";
is_erl_file(_FileName) ->
	false.


