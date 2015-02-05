  defmodule Tds.Types do

  import Tds.BinaryUtils
  import Tds.Utils

  alias Timex.Date
  alias Tds.Parameter

  require Logger

  @gd_epoch :calendar.date_to_gregorian_days({2000, 1, 1})
  @gs_epoch :calendar.datetime_to_gregorian_seconds({{2000, 1, 1}, {0, 0, 0}})
  @datetime Date.from {{1900, 1, 1}, {0, 0, 0}}
  @days_in_month 30
  @secs_in_day 24 * 60 * 60
  @numeric_base 10_000

  @tds_data_type_null           0x1F
  @tds_data_type_tinyint        0x30
  @tds_data_type_bit            0x32
  @tds_data_type_smallint       0x34
  @tds_data_type_int            0x38
  @tds_data_type_smalldatetime  0x3A
  @tds_data_type_real           0x3B
  @tds_data_type_money          0x3C
  @tds_data_type_datetime       0x3D
  @tds_data_type_float          0x3E
  @tds_data_type_smallmoney     0x7A
  @tds_data_type_bigint         0x7F

  @fixed_data_types [
    @tds_data_type_null,
    @tds_data_type_tinyint,
    @tds_data_type_bit,
    @tds_data_type_smallint,
    @tds_data_type_int,
    @tds_data_type_smalldatetime,
    @tds_data_type_real,
    @tds_data_type_money,
    @tds_data_type_datetime,
    @tds_data_type_float,
    @tds_data_type_smallmoney,
    @tds_data_type_bigint
  ]

  @tds_data_type_uniqueidentifier 0x24
  @tds_data_type_intn             0x26
  @tds_data_type_decimal          0x37
  @tds_data_type_numeric          0x3F
  @tds_data_type_bitn             0x68
  @tds_data_type_decimaln         0x6A
  @tds_data_type_numericn         0x6C
  @tds_data_type_floatn           0x6D
  @tds_data_type_moneyn           0x6E
  @tds_data_type_datetimen        0x6F
  @tds_data_type_daten            0x28
  @tds_data_type_timen            0x29
  @tds_data_type_datetime2n       0x2A
  @tds_data_type_datetimeoffsetn  0x2B
  @tds_data_type_char             0x2F
  @tds_data_type_varchar          0x27
  @tds_data_type_binary           0x2D
  @tds_data_type_varbinary        0x25
  @tds_data_type_bigvarbinary     0xA5
  @tds_data_type_bigvarchar       0xA7
  @tds_data_type_bigbinary        0xAD
  @tds_data_type_bigchar          0xAF
  @tds_data_type_nvarchar         0xE7
  @tds_data_type_nchar            0xEF
  @tds_data_type_xml              0xF1
  @tds_data_type_udt              0xF0
  @tds_data_type_text             0x23
  @tds_data_type_image            0x22
  @tds_data_type_ntext            0x63
  @tds_data_type_variant          0x62

  @variable_data_types [
    @tds_data_type_uniqueidentifier,
    @tds_data_type_intn,
    @tds_data_type_decimal,
    @tds_data_type_numeric,
    @tds_data_type_bitn,
    @tds_data_type_decimaln,
    @tds_data_type_numericn,
    @tds_data_type_floatn,
    @tds_data_type_moneyn,
    @tds_data_type_datetimen,
    @tds_data_type_daten,
    @tds_data_type_timen,
    @tds_data_type_datetime2n,
    @tds_data_type_datetimeoffsetn,
    @tds_data_type_char,
    @tds_data_type_varchar,
    @tds_data_type_binary,
    @tds_data_type_varbinary,
    @tds_data_type_bigvarbinary,
    @tds_data_type_bigvarchar,
    @tds_data_type_bigbinary,
    @tds_data_type_bigchar,
    @tds_data_type_nvarchar,
    @tds_data_type_nchar,
    @tds_data_type_xml,
    @tds_data_type_udt,
    @tds_data_type_text,
    @tds_data_type_image,
    @tds_data_type_ntext,
    @tds_data_type_variant
  ]

  @tds_plp_marker 0xffff
  @tds_plp_null 0xffffffffffffffff
  @tds_plp_unknown 0xfffffffffffffffe

  #
  #  Data Type Decoders
  #

  def decode_info(<<data_type_code::unsigned-8, tail::binary>>) when data_type_code in @fixed_data_types do
    cond do
      data_type_code == @tds_data_type_null -> length = 0
      data_type_code in [
        @tds_data_type_tinyint,
        @tds_data_type_bit
      ] -> length = 1
      data_type_code == @tds_data_type_smallint -> length = 2
      data_type_code in [
        @tds_data_type_int,
        @tds_data_type_smalldatetime,
        @tds_data_type_real,
        @tds_data_type_smallmoney
      ] -> length = 4
      data_type_code in [
        @tds_data_type_datetime,
        @tds_data_type_float,
        @tds_data_type_money,
        @tds_data_type_bigint
      ] -> length = 8
    end
    {%{data_type: :fixed, data_type_code: data_type_code, length: length},tail}
  end

  def decode_info(<<data_type_code::unsigned-8, tail::binary>>) when data_type_code in @variable_data_types do  
    col_info = %{data_type: :variable, data_type_code: data_type_code}
    cond do
      data_type_code == @tds_data_type_daten ->
        length = 3
        col_info = col_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)
      data_type_code in [
        @tds_data_type_timen,
        @tds_data_type_datetime2n,
        @tds_data_type_datetimeoffsetn
      ] ->
        <<scale::unsigned-8, tail::binary>> = tail
        cond do
          scale in [1, 2] ->
            length = 3
          scale in [3, 4] ->
            length = 4
          scale in [5, 6, 7] ->
            length = 5
          true -> 
            Logger.debug "Invalid Scale"
        end
        col_info = col_info
          |> Map.put(:scale, scale)

        case data_type_code do
          @tds_data_type_datetime2n -> length = length + 3
          @tds_data_type_datetimeoffsetn -> length = length + 5
        end
        col_info = col_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)
      data_type_code in [
        @tds_data_type_uniqueidentifier,
        @tds_data_type_intn,
        @tds_data_type_decimal,
        @tds_data_type_decimaln,
        @tds_data_type_numeric,
        @tds_data_type_numericn,
        @tds_data_type_bitn,
        @tds_data_type_floatn,
        @tds_data_type_moneyn,
        @tds_data_type_datetimen,
        @tds_data_type_char,
        @tds_data_type_varchar,
        @tds_data_type_binary,
        @tds_data_type_varbinary
      ] -> 
        <<length::little-unsigned-8, tail::binary>> = tail
        if data_type_code in [
            @tds_data_type_numericn,
            @tds_data_type_decimaln
          ] do
          <<precision::unsigned-8, scale::unsigned-8, tail::binary>> = tail
          col_info = col_info
            |> Map.put(:precision, precision)
            |> Map.put(:scale, scale)
        end
        col_info = col_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)
      data_type_code == @tds_data_type_xml ->
        <<schema::unsigned-8, tail::binary>> = tail
        if schema == 1 do
          # TODO
          # BVarChar dbname
          # BVarChar owning schema
          # USVarChar xml schema collection
        end
        col_info = col_info
          |> Map.put(:data_reader, :plp)
      data_type_code in [
        @tds_data_type_bigvarbinary,
        @tds_data_type_bigvarchar,
        @tds_data_type_bigbinary,
        @tds_data_type_bigchar,
        @tds_data_type_nvarchar,
        @tds_data_type_nchar,
        @tds_data_type_udt
      ] ->
        <<length::little-unsigned-16, tail::binary>> = tail
        if data_type_code in [
          @tds_data_type_bigvarchar,
          @tds_data_type_bigchar,
          @tds_data_type_nvarchar,
          @tds_data_type_nchar
          ] do
          <<collation::binary-size(5), tail::binary>> = tail
          col_info = col_info
              |> Map.put(:collation, collation)
          if length == 0xFFFF do
            col_info = col_info
              |> Map.put(:data_reader, :plp)
          else
            col_info = col_info
          |> Map.put(:data_reader, :shortlen)
          end
          col_info = col_info
              |> Map.put(:length, length)
        end
      @data_type_code in [
        @tds_data_type_text,
        @tds_data_type_image,
        @tds_data_type_ntext,
        @tds_data_type_variant 
      ] ->
        <<length::signed-32, tail::binary>> = tail
        col_info = col_info
          |> Map.put(:length, length)
        cond do
          @data_type_code in [@tds_data_type_text, @tds_data_type_ntext] ->
            <<collation::binary-size(5), tail::binary>> = tail
            col_info = col_info
              |> Map.put(:collation, collation)
              |> Map.put(:data_reader, :longlen)
            # TODO NumParts Reader
          @data_type_code == @tds_data_type_image ->
            # TODO NumBarts Reader
            col_info = col_info
              |> Map.put(:data_reader, :bytelen)
          @data_type_code == @tds_data_type_variant ->
            col_info = col_info
              |> Map.put(:data_reader, :variant)
          true -> Logger.debug "Not Implemented"
        end


    end
    {col_info,tail}
  end

  #
  #  Data Decoders
  #

  def decode_data(%{data_type: :fixed, data_type_code: data_type_code, length: length}, <<tail::binary>>) do
    #Logger.debug "Decoding Fixed Length Data: #{data_type_code}"
    <<value_binary::binary-size(length)-unit(8), tail::binary>> = tail
    value = case data_type_code do
      @tds_data_type_null -> 
        nil
      @tds_data_type_bit -> 
        value_binary != <<0x00>>
      @tds_data_type_smalldatetime -> decode_smalldatetime(value_binary)
      @tds_data_type_smallmoney -> decode_smallmoney(value_binary)
      @tds_data_type_real ->
        <<value::little-float-size(32)>> = value_binary
        Float.round value, 4
      @tds_data_type_datetime -> decode_datetime(value_binary)
      @tds_data_type_float -> 
        <<value::little-float-size(64)>> = value_binary
        Float.round value, 8
      @tds_data_type_money -> decode_money(value_binary)
      _ -> <<value::little-signed-size(length)-unit(8)>> = value_binary
        value
    end
    {value, tail}
  end

  # ByteLength Types
  def decode_data(%{data_reader: :bytelen}, <<0x00, tail::binary>>), do: {nil, tail}
  def decode_data(%{data_type_code: data_type_code, data_reader: :bytelen, length: length} = data_info, <<size::unsigned-8, data::binary-size(size), tail::binary>>) do
      #Logger.debug "Decoding Byte Length Data: #{data_type_code}"
      value = cond do
        data_type_code == @tds_data_type_daten -> decode_date(data)
        data_type_code == @tds_data_type_timen -> decode_time(data_info[:scale], data)
        data_type_code == @tds_data_type_datetime2n -> decode_datetime2(data_info[:scale], data)
        data_type_code == @tds_data_type_datetimeoffsetn -> decode_datetimeoffset(data_info[:scale], data)
        data_type_code == @tds_data_type_uniqueidentifier -> decode_uuid(data)
        data_type_code == @tds_data_type_intn ->
          data = data <> tail
          case length do
            1 -> <<value::unsigned-8, tail::binary>> = data
            2 -> <<value::little-signed-16, tail::binary>> = data
            4 -> <<value::little-signed-32, tail::binary>> = data
            8 -> <<value::little-signed-64, tail::binary>> = data
          end
          value
        data_type_code in [
          @tds_data_type_decimal,
          @tds_data_type_numeric,
          @tds_data_type_decimaln,
          @tds_data_type_numericn
        ] ->
          decode_decimal(data_info[:precision], data_info[:scale], data)
        data_type_code == @tds_data_type_bitn ->
          data != <<0x00>>
        data_type_code == @tds_data_type_floatn ->
          data = data <> tail
          case length do
            4 -> <<value::little-float-size(32), tail::binary>> = data
            8 -> <<value::little-float-size(64), tail::binary>> = data
          end
          value
        data_type_code == @tds_data_type_moneyn ->
          case length do
            4 -> decode_smallmoney(data)
            8 -> decode_money(data)
          end
        data_type_code == @tds_data_type_datetimen ->
          case length do
            4 -> decode_smalldatetime(data)
            8 -> decode_datetime(data)
          end
        data_type_code in [
          @tds_data_type_char,
          @tds_data_type_varchar
        ] -> decode_char(data_info[:collation], data)
        data_type_code in [
          @tds_data_type_binary,
          @tds_data_type_varbinary
        ] -> data
      end
      {value, tail}
  end

  # ShortLength Types
  def decode_data(%{data_reader: :shortlen}, <<0xFFFF, tail::binary>>), do: {nil, tail}
  def decode_data(%{data_type_code: data_type_code, data_reader: :shortlen} = data_info, <<size::little-unsigned-16, data::binary-size(size), tail::binary>>) do
    #Logger.debug "Decoding Short Length Data: #{data_type_code}"
    value = cond do
      data_type_code in [
        @tds_data_type_bigvarchar,
        @tds_data_type_bigchar
      ] ->
        decode_char(data_info[:collation], data)
      data_type_code in [
        @tds_data_type_bigvarbinary,
        @tds_data_type_bigbinary
      ] ->
        data
      data_type_code in [
        @tds_data_type_nvarchar,
        @tds_data_type_nchar
      ] ->
        decode_nchar(data)
      data_type_code == @tds_data_type_udt ->
        decode_udt(data_info, data)
    end
    {value, tail}
  end

  # TODO LongLen Types

  # TODO Variant Types

  # TODO PLP TYpes
  # ShortLength Types
  def decode_data(%{data_reader: :plp}, <<@tds_plp_null, tail::binary>>), do: {nil, tail}
  def decode_data(%{data_type_code: data_type_code, data_reader: :plp} = data_info, <<_size::little-unsigned-64, tail::binary>>) do
    #Logger.debug "Decoding PLP Data: #{data_type_code}"
    {data, tail} = decode_plp_chunk(tail, <<>>)    

    value = cond do
      data_type_code == @tds_data_type_xml ->
        decode_xml(data_info, data)
      data_type_code in [
        @tds_data_type_bigvarchar,
        @tds_data_type_bigchar,
        @tds_data_type_text
      ] ->
        decode_char(data_info[:collation], data)
      data_type_code in [
        @tds_data_type_bigvarbinary,
        @tds_data_type_bigbinary,
        @tds_data_type_image
      ] ->
        data
      data_type_code in [
        @tds_data_type_nvarchar,
        @tds_data_type_nchar,
        @tds_data_type_ntext
      ] ->
        decode_nchar(data)
      data_type_code == @tds_data_type_udt ->
        decode_udt(data_info, data)
    end
    {value, tail}
  end

  def decode_plp_chunk(<<0x00, tail::binary>>, buf), do: {buf, tail}
  def decode_plp_chunk(<<chunksize::little-unsigned-32, chunk::size(chunksize), tail::binary>>, buf) do
    decode_plp_chunk(tail, buf <> chunk)
  end

  def decode_smalldatetime(<<days::little-unsigned-16, mins::little-unsigned-16>>) do
    date = Date.shift(@datetime, days: days)
     |> Date.shift(mins: mins)
     {{date.year, date.month, date.day},{date.hour, date.minute, date.second}}
  end

  def decode_smallmoney(<<money::little-signed-32>>) do
    money = pow10(money,(4 * -1))
    Float.round money, 4
  end
  
  def decode_datetime(<<days::little-signed-32, sec::little-unsigned-32>>) do
    date = Date.shift(@datetime, days: days)
    date = Date.shift(date, secs: (sec/300))
    {{date.year, date.month, date.day}, {date.hour, date.minute, date.second}}
  end

  def encode_datetime({{_,_,_},{_,_,_}} = date), do: encode_datetime(Date.from date)
  def encode_datetime(%Timex.DateTime{} = date) do
    #IO.inspect date
    days = Date.diff @datetime, date, :days
    d = Date.shift(@datetime, days: days)
    sec = Date.diff d, date, :secs
    sec = sec*300
    #IO.inspect sec
    <<days::little-signed-32, sec::little-unsigned-32>>
  end

  def decode_money(<<_money_m::little-signed-32, money_l::little-signed-32>>) do
    money = pow10(money_l,(4 * -1))
    Float.round money, 4
  end

  def decode_time(_scale, <<_time::binary>>) do
    # TODO
  end

  def decode_time_int() do
    # TODO
  end

  def decode_datetime2(_scale, <<_data::binary>>) do
    # TODO
  end

  def decode_datetimeoffset(_scale, <<_data::binary>>) do
    # TODO
  end

  def decode_date(<<days::little-size(3)-unit(8)>>) do
    date = Date.from {{1, 1, 1}, {0, 0, 0}}
    date = Date.shift(date, days: days)
    {date.year, date.month, date.day}
  end

  def decode_uuid(<<v1::little-signed-32, v2::little-signed-16, v3::little-signed-16, v4::signed-16, v5::signed-48>>) do
    <<v1::integer-32 , v2::integer-16, v3::integer-16, v4::integer-16, v5::integer-48>>
  end

  def decode_decimal(precision, scale, <<sign::int8, value::binary>>) do
    size = byte_size(value)
    <<value::little-size(size)-unit(8)>> = value
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: precision}
    Decimal.set_context d_ctx

    d = Decimal.new pow10(value,(scale * -1))
    value = pow10(d.coef, d.exp)

    case sign do
      0 -> value * -1
      _ -> value
    end
  end

  def decode_char(_collation, <<data::binary>>) do
    data
  end

  def decode_nchar(<<data::binary>>) do
    data |> :unicode.characters_to_binary({:utf16, :little}, :utf8)
  end

  def decode_xml(data_info, <<data::binary>>) do
    # TODO: Decode XML Data
    nil
  end

  def decode_udt(%{} = data_info, <<data::binary>>) do
    # TODO: Decode UDT Data 
    nil
  end

  #
  #  Data Type Encoders
  #

  def encode_data_type(nil) do
    data_type = %{data_type_code: @tds_data_type_nvarchar}
    {data_type, <<0xE7, 0xFFFF>>}
  end

  # NVarChar

  def encode_data_type(value) when is_binary(value) do
    data_type = %{data_type_code: @tds_data_type_nvarchar} #Enum.find(data_types, fn(x) -> x[:name] == :nvarchar end)
    value = value |> to_little_ucs2
    value_size = byte_size(value)
    collation = <<0x00, 0x00, 0x00, 0x00, 0x00>>
    case value_size do
      0 ->
        {data_type, <<0xE7, 0xFF, 0xFF>> <> collation}
      _ ->
        
        {data_type, <<0xE7, value_size::little-size(2)-unit(8)>> <> collation}
    end
    
  end

  #integers
  def encode_data_type(value) when is_integer(value) and value >= 0 do
    value = value 
      |> :binary.encode_unsigned(:little)
    value_size = byte_size(value)
    cond do
      value_size == 1 -> 
        data_type_code = @tds_data_type_tinyint #Enum.find(data_types, fn(x) -> x[:name] == :tinyint end)
        length = 1 
      value_size == 2 -> 
        data_type_code = @tds_data_type_smallint #Enum.find(data_types, fn(x) -> x[:name] == :smallint end)
        length = 2 
      value_size > 2 and value_size <= 4 -> 
        data_type_code = @tds_data_type_int #Enum.find(data_types, fn(x) -> x[:name] == :int end)
        length = 4
      value_size > 4 and value_size <= 8 ->
        data_type_code = @tds_data_type_bigint #Enum.find(data_types, fn(x) -> x[:name] == :bigint end)
        length = 8
    end
    {%{data_type_code: data_type_code, length: length}, <<0x26>> <> <<length::int8>>}
  end

  def encode_data_type(value) when is_float(value) or (is_integer(value) and value < 0) do
    encode_data_type(Decimal.new(value))
  end

  def encode_data_type(%Decimal{} = dec) do
    data_type = %{data_type_code: @tds_data_type_decimaln} #Enum.find(data_types, fn(x) -> x[:name] == :decimaln end)
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context d_ctx
    value_list = dec
      |> Decimal.abs
      |> Decimal.to_string(:normal)
      |> String.split(".")
      #IO.inspect value_list
    case value_list do
      [p,s] -> 
        #Logger.debug "p,s"
        precision = String.length(p) + String.length(s); scale = String.length(s)
      [p] -> 
        #Logger.debug "p"
        precision = String.length(p); scale = 0
    end

    #Logger.debug "Precision: #{precision}"

    dec_abs = dec 
      |> Decimal.abs 
    value = dec_abs.coef  
      |> :binary.encode_unsigned(:little)
    value_size = byte_size(value)
    
    padding = cond do
      precision <= 9 ->
        byte_len = 4 
        byte_len - value_size
      precision <= 19 -> 
        byte_len = 8
        byte_len - value_size
      precision <= 28 -> 
        byte_len = 12
        byte_len - value_size
      precision <= 38 -> 
        byte_len = 16
        byte_len - value_size
    end

    value_size = value_size + padding + 1

    data_type = data_type
      |> Map.put(:precision, precision)
      |> Map.put(:scale, scale)

    {data_type, <<data_type[:data_type_code], value_size, precision, scale>>}
  end

  # Date Time
  def encode_data_type({{_,_,_},{_,_,_}} = date) do
    data_type = %{data_type_code: @tds_data_type_datetimen}
    {data_type, <<data_type[:data_type_code], 0x08>>}
  end

  # # Date
  # def encode_data_type({month, day, year}) do

  # end

  #
  #  Param Descriptor Encoders
  #

  def encode_param_descriptor(%Parameter{name: name, value: nil}) do
    "#{name} nvarchar"
  end

  def encode_param_descriptor(%Parameter{name: name, value: {{_,_,_},{_,_,_}}}) do
    "#{name} datetime"
  end

  def encode_param_descriptor(%Parameter{name: name, value: value}) when is_integer(value) and value >= 0 do
    #Logger.debug "Value: #{value}"
    {data_type, _} = encode_data_type(value)
    #"#{name} #{Atom.to_string(data_type[:name])}"
    "#{name} bigint"
  end

  def encode_param_descriptor(%Parameter{name: name, value: value}) when is_integer(value) and value < 0 do
    #Logger.debug "Value: #{value}"
    precision = value 
      |> Integer.to_string
      |> String.length
    "#{name} decimal(#{precision-1}, 0)"
  end

  def encode_param_descriptor(%Parameter{name: name, value: %Decimal{} = dec}) do
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context d_ctx
    value_list = dec
      |> Decimal.abs
      |> Decimal.to_string(:normal)
      |> String.split(".")
    case value_list do
      [p,s] -> 
        #Logger.debug "p,s"
        precision = String.length(p) + String.length(s); scale = String.length(s)
      [p] -> 
        #Logger.debug "p"
        precision = String.length(p); scale = 0
    end

    "#{name} decimal(#{precision}, #{scale})"
  end

  def encode_param_descriptor(%Parameter{name: name, value: value}) when is_binary(value) do
    length = String.length(value)
    if length <= 0, do: length = 1
    #Logger.debug "#{name} nvarchar(#{length})"
    "#{name} nvarchar(#{length})"
  end

  #
  #  Data Encoders
  #
  def encode_data(%{data_type_code: @tds_data_type_nvarchar}, nil) do
    <<0x00::unsigned-64, 0x00::unsigned-32>>
  end
  def encode_data(%{data_type_code: @tds_data_type_nvarchar}, value) do
    value = value |> to_little_ucs2
    value_size = byte_size(value)
    case value_size do
      0 ->
        <<0x00::unsigned-64, 0x00::unsigned-32>>
      _ ->
        <<value_size::little-size(2)-unit(8)>> <> value
    end
  end

  def encode_data(%{data_type_code: data_type_code, length: length}, value) when is_integer(value) and value >= 0 do
    value = value
      |> :binary.encode_unsigned(:little)
    value_size = byte_size(value)
    padding = length - value_size
    Logger.info "ENCODE INTEGER"
    IO.inspect value
    <<length>> <> value <> <<0::size(padding)-unit(8)>>
  end

  def encode_data(%{data_type_code: @tds_data_type_decimaln, precision: precision, scale: _scale}, %Decimal{} = value) do
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context d_ctx

    d = value
      |> Decimal.to_string 
      |> Decimal.new
    sign = case d.sign do 1 -> 1; -1 -> 0 end
    
    d_abs = Decimal.abs d

    #Logger.debug "Value to be Encoded: #{value}"
    value = d_abs.coef
    #Logger.debug "Value to be Encoded: #{value}"

    value_binary = value  
      |> :binary.encode_unsigned(:little)
    value_size = byte_size(value_binary)
    #Logger.debug "Value Bin: #{Tds.Utils.to_hex_string(value_binary)}"
    #Logger.debug "Value Size: #{value_size}"
    padding = cond do
      precision <= 9 ->
        byte_len = 4 
        byte_len - value_size
      precision <= 19 -> 
        byte_len = 8
        byte_len - value_size
      precision <= 28 -> 
        byte_len = 12
        byte_len - value_size
      precision <= 38 -> 
        byte_len = 16
        byte_len - value_size
    end

    byte_len = byte_len + 1
    value_binary = value_binary <> <<0::size(padding)-unit(8)>>
    <<byte_len>> <> <<sign>> <> value_binary
  end

  def encode_data(%{data_type_code: @tds_data_type_decimaln} = data_type, value) do
    encode_data(data_type, Decimal.new(value))
  end

  def encode_data(%{data_type_code: @tds_data_type_datetimen}, value) do
    #Logger.info "Encode Datetime"
    data = encode_datetime(value)
    #Logger.info "DateTime: #{Tds.Utils.to_hex_string data}"
    <<0x08>> <> data
  end

end 