-module(ml_glue).
-export([iso_8859_1_to_string/1]).

iso_8859_1_to_string(Data) ->
    case unicode:characters_to_binary(Data, latin1) of
        String when is_binary(String) -> {ok, String};
        _else -> {error, nil}
    end.
