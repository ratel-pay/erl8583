%% Author: carl
%% Created: 02 Apr 2011
%% Description: TODO: Add description to erl8583_marshaller
-module(erl8583_marshaller).

%%
%% Include files
%%

%%
%% Records
%%
-record(marshal_options, {field_marshaller, 
						  bitmap_marshaller,
						  mti_marshaller, 
						  wrapping_marshaller, 
						  encoding_rules}).

%%
%% Exported Functions
%%
-export([marshal/2, unmarshal/2]).

%%
%% API Functions
%%
marshal(Message, Options) ->
	OptionsRecord = parse_options(Options, #marshal_options{}),
	Marshalled1 = encode_mti(OptionsRecord, Message),
	Marshalled2 = Marshalled1 ++ encode_bitmap(OptionsRecord, Message),
	Marshalled3 = Marshalled2 ++ encode_fields(OptionsRecord, Message),
	wrap_message(OptionsRecord, Message, Marshalled3).

unmarshal(Marshalled, Options) ->
	OptionsRecord = parse_options(Options, #marshal_options{}),
	{Message0, Marshalled1} = unwrap_message(OptionsRecord, erl8583_message:new(), Marshalled),
	{Message1, Marshalled2} = decode_mti(OptionsRecord, Marshalled1, Message0),
	{FieldIds, Marshalled3} = decode_bitmap(OptionsRecord, Marshalled2),
	decode_fields(FieldIds, Message1, OptionsRecord, Marshalled3).

%%
%% Local Functions
%%
parse_options([], OptionsRecord) ->
	OptionsRecord;
parse_options([{field_marshaller, Marshaller}|Tail], OptionsRecord) ->
	parse_options(Tail, OptionsRecord#marshal_options{field_marshaller=Marshaller});
parse_options([{bitmap_marshaller, Marshaller}|Tail], OptionsRecord) ->
	parse_options(Tail, OptionsRecord#marshal_options{bitmap_marshaller=Marshaller});
parse_options([{mti_marshaller, Marshaller}|Tail], OptionsRecord) ->
	parse_options(Tail, OptionsRecord#marshal_options{mti_marshaller=Marshaller});
parse_options([{wrapping_marshaller, Marshaller}|Tail], OptionsRecord) ->
	parse_options(Tail, OptionsRecord#marshal_options{wrapping_marshaller=Marshaller});
parse_options([{encoding_rules, Rules}|Tail], OptionsRecord) ->
	parse_options(Tail, OptionsRecord#marshal_options{encoding_rules=Rules}).

get_encoding_rules(Options, Message) ->
	if
		Options#marshal_options.encoding_rules =/= undefined ->
			Options#marshal_options.encoding_rules;
		Options#marshal_options.encoding_rules =:= undefined ->
			case erl8583_message:get_fields(Message) of
				[0|_Fields] ->
					Mti = erl8583_message:get(0, Message),
					[Version|_MtiRest] = Mti,
					case Version of
						$0 ->
							erl8583_fields;
						$1 ->
							erl8583_fields_1993;
						$2 ->
							erl8583_fields_2003
					end;
				_ ->
					undefined
			end
	end.

encode_mti(Options, Message) ->
	MtiMarshalModule = Options#marshal_options.mti_marshaller,
	if
		MtiMarshalModule =:= undefined ->
			[];
		MtiMarshalModule =/= undefined ->
			case erl8583_message:get_fields(Message) of
				[0|_Fields] ->
					MtiMarshalModule:marshal_mti(erl8583_message:get(0,Message));
				_ ->
					[]
			end
	end.

decode_mti(Options, Marshalled, Message) ->
	MtiMarshalModule = Options#marshal_options.mti_marshaller,
	if
		MtiMarshalModule =:= undefined ->
			{Message, Marshalled};
		MtiMarshalModule =/= undefined ->
			{FieldValue, Rest} = MtiMarshalModule:unmarshal_mti(Marshalled),
			{erl8583_message:set(0, FieldValue, Message), Rest}
	end.
	
encode_bitmap(Options, Message) ->
	BitmapMarshalModule = Options#marshal_options.bitmap_marshaller,
	Fields = erl8583_message:get_fields(Message) -- [0],
	if
		BitmapMarshalModule =:= undefined ->
			[];
		BitmapMarshalModule =/= undefined ->			
			BitmapMarshalModule:marshal_bitmap(Fields)
	end.

decode_bitmap(Options, Marshalled) ->
	BitmapMarshalModule = Options#marshal_options.bitmap_marshaller,
	if
		BitmapMarshalModule =:= undefined ->
			{[], Marshalled};
		BitmapMarshalModule =/= undefined ->			
			BitmapMarshalModule:unmarshal_bitmap(Marshalled)
	end.

encode_fields(Options, Message) ->
	Fields = erl8583_message:get_fields(Message) -- [0],
	EncodingRules = get_encoding_rules(Options, Message),
	FieldMarshalModule = Options#marshal_options.field_marshaller,
	if
		FieldMarshalModule =:= undefined ->
			[];
		FieldMarshalModule =/= undefined ->
			encode(Fields, Message, FieldMarshalModule, EncodingRules) 
	end.
	
encode(Fields, Msg, FieldMarshaller, EncodingRules) ->
	encode(Fields, Msg, [], FieldMarshaller, EncodingRules).

encode([], _Msg, Result, _FieldMarshaller, _EncodingRules) ->
	lists:reverse(Result);
encode([FieldId|Tail], Msg, Result, FieldMarshaller, EncodingRules) ->
	Value = erl8583_message:get(FieldId, Msg),
	EncodedValue = FieldMarshaller:marshal_field(FieldId, Value, EncodingRules),
	encode(Tail, Msg, lists:reverse(EncodedValue) ++ Result, FieldMarshaller, EncodingRules).

decode_fields([], Message, _OptionsRecord, _Marshalled) ->
	Message;
decode_fields([FieldId|Tail], Message, Options, Marshalled) ->
	EncodingRules = get_encoding_rules(Options, Message),
	FieldMarshalModule = Options#marshal_options.field_marshaller,
	if
		FieldMarshalModule =:= undefined ->
			Message;
		FieldMarshalModule =/= undefined ->
			{FieldValue, Rest} = FieldMarshalModule:unmarshal_field(FieldId, Marshalled, EncodingRules),
			decode_fields(Tail, erl8583_message:set(FieldId, FieldValue, Message), 
						  Options, Rest) 
	end.

wrap_message(Options, Message, Marshalled) ->
	WrapperMarshalModule = Options#marshal_options.wrapping_marshaller,
	if
		WrapperMarshalModule =:= undefined ->
			Marshalled;
		WrapperMarshalModule =/= undefined ->
			WrapperMarshalModule:marshal_wrapping(Message, Marshalled) 
	end.

unwrap_message(Options, Marshalled, Message) ->
	WrapperMarshalModule = Options#marshal_options.wrapping_marshaller,
	if
		WrapperMarshalModule =:= undefined ->
			{Marshalled, Message};
		WrapperMarshalModule =/= undefined ->
			WrapperMarshalModule:unmarshal_wrapping(Marshalled, Message) 
	end.
