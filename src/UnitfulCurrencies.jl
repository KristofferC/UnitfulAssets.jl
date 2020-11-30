__precompile__(true)
"""
    UnitfulCurrencies

Module extending Unitful.jl with currencies.

Currency dimensions are created for each currency, along with its reference
unit. All active currencies around the world are defined.

An `ExchangeMarket` type is also defined as an alias for
`Dict{Tuple{String,String},Real}`, in which the tuple key contains the
quote-ask currency pair (e.g. `("EUR", "USD")`) and the value is the
exchange rate for the pair.

Based on an given exchange market instance of `ExchangeMarket`, a conversion
can be made from the "quote" currency to the "base" currency. This conversion
is implemented as an extended dispatch for `Unitful.uconvert`.
"""
module UnitfulCurrencies

using Unitful, JSON
using Unitful: @dimension, @refunit
import Unitful: uconvert

export ExchangeMarket, @currency, generate_exchmkt

"""
    is_currency_code(code_string::String)::Bool

Return whether or not `code_string` refers to a valid currency.

`code_string` is expected to be a currency code abbr (a three-letter string
corresponding to the currency code symbol), like "EUR", or a currency
dimension abbr (the code abbr appended with "CURRENCY").

The function checks whether `code_string` is at least three-characters long
and whether it is all composed of ascii uppercase letters.

# Examples

```jldoctest
julia> is_currency_code("BRL")
true

julia> is_currency_code("USDCURRENCY")
true

julia> is_currency_code("euro")
false
```
"""
function is_currency_code(code_string::String)
    return length(code_string) >= 3 && all(c -> 'A' <= c <= 'Z', code_string)
end

"""
    CurrencyPair

Type for currency pairs.

Currency pairs are made of two String fields, a `base_curr` with the alphabetic
code ISO-4217 corresponding to the base currency and `quote_curr` with the
alphabetic code ISO-4217 corresponding to the quote currency.

The alphabetic codes are made of three-character long uppercase ascii letters,
so the structure's constructor checks whether this requirement is met,
otherwise an ArgumentError is thrown.

# Examples

```jldoctest
julia> CurrencyPair("EUR", "BRL")
CurrencyPair("EUR", "BRL")

julia> CurrencyPair("euro", "BRL")
ERROR: ArgumentError: The given code symbol pair ("euro", "BRL") is not allowed, both should be all in ascii uppercase letters and at least three-character long.
Stacktrace:
  ...
```
"""
struct CurrencyPair
    base_curr::String
    quote_curr::String
    CurrencyPair(base_curr, quote_curr) = is_currency_code(base_curr) && 
        is_currency_code(quote_curr) ? new(base_curr,quote_curr) : 
            throw(ArgumentError("The given code symbol pair "
                * "$((base_curr, quote_curr)) is not allowed, both should be all "
                * "in ascii uppercase letters and at least three-character long."))
end

"""
    Rate

Type for exchange rates.

An exchange rate is simply a positive Number.

The structure's constructor checks whether this requirement is met,
otherwise an ArgumentError is thrown.

# Examples

```jldoctest
julia> Rate(1.2)
Rate(1.2)

julia> Rate(-2)
ERROR: ArgumentError: The exchange rate must be a positive number
Stacktrace:
  ...
```
"""
struct Rate
    value::Number
    Rate(r) = r > 0 ? new(r) :
        throw(ArgumentError("The exchange rate must be a positive number"))
end

"""
    ExchangeMarket

Type used for a dictionary of exchange rates pair quotes.
    
It is given as a Dict{CurrencyPair,Rate}, where the keys are
currency pairs with the base and quote currencies and the value
is the exchange rate for this pair (i..e. how much in quote currency
is needed to buy one unit of the base currency).

For instance, the exchange market

    exchmkt = ExchangeMarket(CurrencyPair("EUR", "USD") => Rate(1.164151))

contains the pair `CurrencyPair("EUR", "USD")` and the exchange rate
`Rate(1.164151)`, which means that one can buy 1 EUR with 1.164151 USD.
"""
ExchangeMarket = Dict{CurrencyPair,Rate}

"""
    generate_exchmkt(d::Dict{Tuple{String,String},Float64})

Generates an instance of an ExchangeMarket from a dictionary of base-quote-value rates.

# Examples

```jldoctest
julia> generate_exchmkt(Dict(("EUR", "USD") => 1.164151))
Dict{CurrencyPair,Float64} with 1 entry:
  CurrencyPair("EUR", "USD") => Rate(1.16415)
```
"""
function generate_exchmkt(d::Dict{Tuple{String,String},Float64})
    return Dict([CurrencyPair(key[1], key[2]) => Rate(value) for (key,value) in d])
end

"""
    generate_exchmkt(a::Array{Pair{Tuple{String,String},Float64},1})

Generates an instance of ExchangeMarket from an array of base-quote-value rates.

# Examples

```jldoctest
julia> generate_exchmkt([("EUR","USD") => 1.19536, ("USD","EUR") => 0.836570])
Dict{CurrencyPair,Float64} with 2 entries:
  CurrencyPair("EUR", "USD") => Rate(1.19536)
  CurrencyPair("USD", "EUR") => Rate(0.83657)
```
"""
function generate_exchmkt(a::Array{Pair{Tuple{String,String},Float64},1})
    return Dict([CurrencyPair(key[1], key[2]) => Rate(value) for (key,value) in a])
end

"""
    generate_exchmkt(a::Array{Pair{Tuple{String,String},Float64},1})

Generates an instance of ExchangeMarket from a single of base-quote-value rate.

# Examples

```jldoctest
julia> generate_exchmkt(("EUR", "USD") => 1.164151)
Dict{CurrencyPair,Float64} with 1 entry:
  CurrencyPair("EUR", "USD") => Rate(1.16415)
```
"""
function generate_exchmkt(p::Pair{Tuple{String,String},Float64})
    return Dict(CurrencyPair(p[1][1], p[1][2]) => Rate(p[2]))
end

"""
    @currency code_symb name

Create a dimension and a reference unit for a currency.

The macros `@dimension` and `@refunit` are called with arguments derived
from `code_symb` and `name`.
"""
macro currency(code_symb, name)
    code_abbr = string(code_symb)
    if is_currency_code(code_abbr)
        gap = Int('𝐀') - Int('A')
        code_abbr_bold = join([Char(Int(c) + gap) for c in code_abbr])
        dimension = Symbol(code_abbr_bold)
        dim_abbr = string(code_symb) * "CURRENCY"
        dim_name = Symbol(code_abbr_bold * "𝐂𝐔𝐑𝐑𝐄𝐍𝐂𝐘")
        esc(quote
            Unitful.@dimension($dimension, $dim_abbr, $dim_name)
            Unitful.@refunit($code_symb, $code_abbr, $name, $dimension, true)
        end)
    else
        :(throw(ArgumentError("The given code symb is not allowed, it should be all in uppercase.")))
    end
end

include("pkgdefaults.jl")

"""
    uconvert(u::Units, x::Quantity, e::ExchangeMarket; mode::Int=1)

Convert between currencies, allowing for inverse and secondary rates.

If mode=1, which is the default, a direct conversion is attempted, i.e. 
if the given exchange market includes the conversion rate from `unit(x)`
to `u`, then the conversion takes place with this rate.

If mode=-1 and the given exchange market includes the exchange rate from
`u` to `unit(x)`, then the conversion of `x` to `u` is achieved with the rate
which is the multiplicative inverse of the exchange rate from `u` to `unit(x)`.

If mode=2, and the given exchange market includes the exchange rate from
`unit(x)` to an intermediate currency `v` and from  `v` to `u`, then 
the exchange takes place with the product of these two exchange rates.
If there is more than one intermediate currency available, then the first
one encountered in a nested loop in which the second pair is in the
inner loop is the one chosen.

If mode=-2, a combination of `-1` and `2` is used, i.e. an intermediate
currency is used for the inverse exchange rate from `u` to `unit(x)`.

An `ArgumentError` is thrown if mode is none of the above or if `u` or `x`
are not currencies, or if the necessary exchange rates cannot be accomplished
with the given exchange market.

# Examples

Assuming `forex_exchmkt["2020-11-01"]` ExchangeMarket contains the key-value
pair `("EUR","BRL") => 6.685598`, then the following exchange takes place:

```jldoctest
julia> uconvert(u"BRL", 1u"EUR", forex_exchmkt["2020-11-01"])
6.685598 BRL
julia> uconvert(u"BRL", 1u"BRL", forex_exchmkt["2020-11-01"], mode=-1)
0.149575251159283 EUR
```
"""
function uconvert(u::Unitful.Units, x::Unitful.Quantity, e::ExchangeMarket; mode::Int=1)
    u_curr_str = string(Unitful.dimension(u))
    x_curr_str = string(Unitful.dimension(x))
    if is_currency_code(u_curr_str) && is_currency_code(x_curr_str)
        u_curr = u_curr_str[1:3]
        x_curr = x_curr_str[1:3]
        pair = CurrencyPair(x_curr, u_curr)
        pairinv = CurrencyPair(u_curr, x_curr)
        if mode == 1 && pair in keys(e)
            rate = Main.eval(Meta.parse(string(e[pair].value) * "u\"" * u_curr * "/" * x_curr * "\""))
            return Unitful.uconvert(u, rate * x)
        elseif mode == -1 && pairinv in keys(e)
            rate = Main.eval(Meta.parse(string(1/e[pairinv].value) * "u\"" * u_curr * "/" * x_curr * "\""))
            return Unitful.uconvert(u, rate * x)
        elseif mode == 2
            for (pair1, rate1) in e
                for (pair2, rate2) in e
                    if pair1.base_curr == x_curr && pair2.quote_curr == u_curr && pair1.quote_curr == pair2.base_curr
                        rate = Main.eval(Meta.parse(string(rate1.value * rate2.value) * "u\"" * u_curr * "/" * x_curr * "\""))
                        return Unitful.uconvert(u, rate * x)
                    end
                end
            end
        elseif mode == -2
            for (pair1, rate1) in e
                for (pair2, rate2) in e
                    if pair1.base_curr == u_curr && pair2.quote_curr == x_curr && pair1.quote_curr == pair2.base_curr
                        rate = Main.eval(Meta.parse(string(1 / (rate1.value * rate2.value) ) * "u\"" * u_curr * "/" * x_curr * "\""))
                        return Unitful.uconvert(u, rate * x)
                    end
                end
            end
        end
        throw(ArgumentError(
            "No such exchange rate available in the given exchange" *
            "market for the conversion from $(Unitful.unit(x)) to $u."
            )
        )
    else
        throw(ArgumentError("$u and $x must be currencies"))
    end
end

include("exchmkt_tools.jl")

# Register the above units and dimensions in Unitful
const localpromotion = Unitful.promotion # only needed with new dimensions
function __init__()
    Unitful.register(UnitfulCurrencies) # needed for new Units
    merge!(Unitful.promotion, localpromotion) # only needed with new dimensions
end

end # module
