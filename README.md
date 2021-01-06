# UnitfulCurrencies - supplemental pkg for Unitful.jl

![Logo](tools/logo/logo_200x200.png)

![Main Tests Workflow Status](https://github.com/rmsrosa/UnitfulCurrencies.jl/workflows/CI/badge.svg) [![codecov](https://codecov.io/gh/rmsrosa/UnitfulCurrencies.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/rmsrosa/UnitfulCurrencies.jl) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) ![GitHub repo size](https://img.shields.io/github/repo-size/rmsrosa/UnitfulCurrencies.jl)

A supplemental units package for [Unitful.jl](https://github.com/PainterQubits/Unitful.jl), adding units for all currently active currencies in the world, along with tools to perform conversions based on exchange market rates.

**This package is not registered and is current under development.**

## Table of Contents

- [Summary](#summary)
- [Installation](#installation)
- [Examples](#examples)
  - [Cost of raw material for a T-shirt](#cost-of-raw-material-for-a-t-shirt) - mixing currencies with [Unitul.jl](https://github.com/PainterQubits/Unitful.jl)'s quantities.
  - [Production cost](#production-cost) - creating functions with currencies as arguments.
  - [Continuously varying interest rate](#continuously-varying-interest-rate) - using [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl) with currencies.
  - [Exchange markets](#exchange-markets) - generating ExchangeMarkets and using different modes of exchange conversion.
  - [Continuously varying interest rate in a foreign bank](#continuously-varying-interest-rate-in-a-foreign-bank) - exploiting broadcasting for an array of currency quantities.
  - [Decimal and rational exchange rates](#decimal-and-rational-exchange-rates) - using `Decimal` and `Rational` types.
- [Exchange rate as Unitful quantity](#exchange-rate-as-unitful-quantity)
- [To-do](#to-do)
- [Related packages](#related-packages)
- [License](#license)

## Summary

Currency dimensions are created for each currency, along with its reference
unit. Being an extension of [Unitful.jl](https://github.com/PainterQubits/Unitful.jl), currency units play nicely along with Unitful's quantities.

An `ExchangeMarket` type is defined as `Dict{CurrencyPair,ExchangeRate}`, in which `CurrencyPair` is a tuple of Strings with the ISO-4217 alphabetic codes corresponding to the base and quote currencies, and `ExchangeRate` contains a positive `Unitful.Quantity` with the corresponding quote-ask rate for the pair.

Based on an given `ExchangeMarket` instance, a conversion can be made from the "quote" currency to the "base" currency. This conversion is implemented as an extended dispatch for `Unitful.uconvert`.

## Installation

This package is compatible with Julia ≥ 1.2 and Unitful ≥ 1.0.

Since it has not been registered yet, it can be installed directly from the github repo in the Julia REPL, by typing `]` and *adding* the url for the repo:

```julia
pkg> add https://github.com/rmsrosa/UnitfulCurrencies.jl
```

## Examples

Let us see some examples using `UnitfulCurrencies.jl`.

### Cost of raw material for a T-shirt

As an example, consider a T-shirt with a Julia logo that requires as raw material 1.6 square-meters of 150GSM (grams-per-square-meter) cotton fabric at USD\$15 per 44 in x 8 yards bolt; two ounces in dyes at USD\$20 per pound; one ounce of dye fixer at US\$8 per five pounds; and 48 yards in stitching thread at USD\$19 per 1000 yards. Then, we may calculate the cost of the raw material as follows.

```julia
julia> using Unitful, UnitfulCurrencies

julia> fabric = 15u"USD"/8u"yd"/44u"inch"
0.04261363636363636 USD inch⁻¹ yd⁻¹

julia> dyes = 20u"USD/lb"
20 USD lb⁻¹

julia> fixer = 8u"USD"/5u"lb"
1.6 USD lb⁻¹

julia> thread = 19u"USD"/1000u"yd"
0.019 USD yd⁻¹

julia> cost_per_t_shirt = 1.6u"m^2" * fabric + 2u"oz" * dyes + 1u"oz" * fixer + 48u"yd" * thread;

julia> println("\nThe cost of raw material per t-shirt is of $cost_per_t_shirt")

The cost of raw material per t-shirt is of 6.447611931829924 USD
```

Thus, the cost of the raw material is about USD$ 6.45 per T-shirt.

### Production cost

Suppose, now, that we have a small business to manufacture the T-shirts above. Besides the raw material expenses, we need eletricity for the sewing machine and the workplace, workers, rent, insurance, and so on. With that in mind, we assume we have a fixed overhead cost of USD\$ 24000 per year for rent and the essential utilities, insurance and things like that; eletricity expenses for the sewing machine at USD\$ 0.13 per kilowatt-hour; and labor at USD$ 10.50 per worker per hour.

In order to implement that, we add two nondimensional units, namely `tshirt` and `worker`, then we define the price constants above and two functions that give us the total cost and total material used. We do this as follows.

```julia
julia> using Unitful, UnitfulCurrencies

julia> module ProductionUnits
           using Unitful
           using Unitful: @unit
           @unit tshirt "tshirt" TShirt 1 false
           @unit worker "worker" Worker 1 false
       end

julia> Unitful.register(ProductionUnits);

julia> fabric = 15u"USD"/8u"yd"/44u"inch"
0.04261363636363636 USD inch⁻¹ yd⁻¹

julia> dyes = 20u"USD/lb"
20 USD lb⁻¹

julia> fixer = 8u"USD"/5u"lb"
1.6 USD lb⁻¹

julia> thread = 19u"USD"/1000u"yd"
0.019 USD yd⁻¹

julia> """
           raw_material(n::Unitful.Quantity)

       Return the amount of each raw material needed to manufacture `n` T-shirts.

       The argument `n` must be given in `tshirt` units.

       Returns a tuple with the following quantities, respectively:

       * The necessary amount of cotton fabric.

       * The necessary amount of dye.

       * The necessary amount of fixer.

       * The necessary amount of thread.

       """
       raw_material(n::Unitful.Quantity) = (1.6u"m^2" * n / u"tshirt", 2u"oz" * n / u"tshirt", 1u"oz" * n / u"tshirt", 48u"yd" * n / u"tshirt")
raw_material

julia> eletricity_price = 0.13u"USD/kW/hr"
0.13 USD hr⁻¹ kW⁻¹

julia> labor_price = 10.50u"USD/worker/hr"
10.5 USD hr⁻¹ worker⁻¹

julia> fixed_cost = 24000u"USD/yr"
24000 USD yr⁻¹

julia> """
           manufacturing_cost(n::Unitful.Quantity, t::Unitful.Quantity, tlim::Unitful.Quantity=40u"hr/worker/wk")

       Return the cost of manufacturing `n` T-shirts during a time period `t`.

       The argument `n` must be given in `tshirt` units, and `t`, in time units.
       The optional argument `tlim` is the time limit of work per worker, which       defaults to `40u"hr/worker/wk"`.

       Return a tuple with the following quantities, respectively:

       * The cost of the production, in US Dollars.

       * The cost per T-shirt.

       * The number of labor hours required to produce `n` t-shirts.

       * The minimum number of workers considering the limit given by `tlim`.

       * The eletricity required for the whole manufacturing process.
       """
       function production_cost(n::Unitful.Quantity, t::Unitful.Quantity, tlim::Unitful.Quantity=40u"hr/worker/wk")
           labor_hours = 2u"hr/tshirt" * n
           eletricity_spent = 2u"kW * hr/tshirt" * n
           total_cost = n * raw_material_price + labor_hours * labor_price + eletricity_spent * eletricity_price + fixed_cost * t
           cost_per_tshirt = total_cost / n
           min_num_workers = Int(ceil(labor_hours/tlim/t)) * u"worker"
           return total_cost, cost_per_tshirt, labor_hours, min_num_workers, eletricity_spent
       end
production_cost
```

Now, if we want to see the cost and everything else needed to produce 50 T-shirts *per week*, we do

```julia
julia> production_cost(50u"tshirt", 1u"wk")
(1845.3395288296892 USD, 36.906790576593785 USD tshirt⁻¹, 100 hr, 3 worker, 100 hr kW)

julia> raw_material(50u"tshirt")
(80.0 m², 100 oz, 50 oz, 2400 yd)
```

So, it costs about USD$ 36.91 per T-shirt in this case.

If we want to reduce the cost per T-shirt, we increase production, aiming for 2000 T-shirts *per month*, with workers working 44 hours per week:

```julia
julia> production_cost(2000u"tshirt", 30u"d", 44u"hr/worker/wk")
(57386.47643039496 USD, 28.693238215197482 USD tshirt⁻¹, 4000 hr, 22 worker, 4000 hr kW)

julia> raw_material(2000u"tshirt")
(3200.0 m², 4000 oz, 2000 oz, 96000 yd)
```

With that, we are able to reduce the cost per T-shirt to about USD$ 28.69.

**Exercises:**

1. Add *benefit costs* for each worker, so that the number of workers properly affects the cost.

2. Add a linear *revenue* function proportional to the number of T-shirts sold, with proportionality constant being the selling price per T-shirt.

3. Add an affine *profit* function, which is the difference between the revenue function and the cost function.

4. Find the *break-even* point, which is the number of T-shirts where profit vanishes, i.e. neiher profit nor loss is incurred.

### Continuously varying interest rate

Here we use the package [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl).

Suppose we have a £1,000 in a savings account in a British bank, with an expected variable interest rate for the next ten years of the form

![formula](https://render.githubusercontent.com/render/math?math=\qquad\qquad\text{rate}(t)=\left(0.015%2B0.5\frac{(t/\text{yr})^2}{(1%2B(t/\text{yr})^3)}\right)/yr),

and suppose we want to estimate how much we will have after ten years. This can be implemented as follows.

```julia
julia> using Unitful, UnitfulCurrencies, DifferentialEquations

julia> rate(t) = (1.5 + 5(t * u"1/yr")^2 * ( 1 + (t * u"1/yr")^3)^-1)*u"percent/yr"
rate (generic function with 1 method)

julia> f(u,rate,t) = rate(t) * u
f (generic function with 1 method)

julia> tspan = Tuple([0.0,10.0]*u"yr")
(0.0 yr, 10.0 yr)

julia> u₀ = 1000.0u"GBP"
1000.0 GBP

julia> prob = ODEProblem(f,u₀,tspan,rate)
ODEProblem with uType Quantity{Float64,GBPCURRENCY,Unitful.FreeUnits{(GBP,),GBPCURRENCY,nothing}} and tType Quantity{Float64,𝐓,Unitful.FreeUnits{(yr,),𝐓,nothing}}. In-place: false
timespan: (0.0 yr, 10.0 yr)
u0: 1000.0 GBP

julia> savings = solve(prob);

julia> println("After $(savings.t[end]), we expect to have $(savings.u[end])")
After 10.0 yr, we expect to have 1303.6211777402004 GBP
```

Thus, we expect to have about £1,303.62 in our savings account, after ten years.

### Exchange markets

For exchanging money, we provide a few dispatches of a function `generate_exchmkt` to generate an `ExchangeMarket` instance from a single Tuple, an Array or a Dict with `CurrencyPair` and `ExchangeRate` instances. Consider, for example, the following exchange market:

```julia
julia> using Unitful, UnitfulCurrencies

julia> exch_mkt_27nov2020 = generate_exchmkt([
                  ("EUR","USD") => 1.19536, ("USD","EUR") => 0.836570,
                  ("EUR","GBP") => 1.11268, ("GBP","EUR") => 0.898734,
                  ("USD","CAD") => 1.29849, ("CAD","USD") => 0.770125,
                  ("USD","BRL") => 5.33897, ("BRL","USD") => 0.187302
              ])
Dict{UnitfulCurrencies.CurrencyPair,UnitfulCurrencies.ExchangeRate} with 8 entries:
  CurrencyPair("USD", "BRL") => ExchangeRate(5.33897 BRL USD⁻¹)
  CurrencyPair("USD", "EUR") => ExchangeRate(0.83657 EUR USD⁻¹)
  CurrencyPair("EUR", "GBP") => ExchangeRate(1.11268 GBP EUR⁻¹)
  CurrencyPair("GBP", "EUR") => ExchangeRate(0.898734 EUR GBP⁻¹)
  CurrencyPair("USD", "CAD") => ExchangeRate(1.29849 CAD USD⁻¹)
  CurrencyPair("EUR", "USD") => ExchangeRate(1.19536 USD EUR⁻¹)
  CurrencyPair("CAD", "USD") => ExchangeRate(0.770125 USD CAD⁻¹)
  CurrencyPair("BRL", "USD") => ExchangeRate(0.187302 USD BRL⁻¹)
```

Then, the conversions between these currencies can be done as follows:

```julia
julia> uconvert(u"BRL", 100u"USD", exch_mkt_27nov2020)
533.8969999999999 BRL
```

This means that I need about `533.90 BRL` to buy `100 USD`.

If I have dollars and I want to buy about `500 BRL`, we do it the other way around:

```julia
julia> uconvert(u"USD", 500u"BRL", exch_mkt_27nov2020)
93.651 USD
```

Now, if, instead, I have `500 BRL` and I want to see how many dollars I can buy with it, I need the same exchange rate as in the first conversion, but in a inverse relation, which is accomplished with the option argument `mode=-1`, so that

```julia
julia> uconvert(u"USD", 500u"BRL", exch_mkt_27nov2020, mode=-1)
93.65102257551551 USD
```

Another situation is when we don't have a currency pair in the given exchange market, such as `("EUR", "CAD")`, which is not in `exch_mkt_27nov2020`. In this case we can use an intermediate currency, if available. In the example market, `USD` works. The exchange with an intermediate currency is achieved with `mode=2`:

```julia
julia> uconvert(u"CAD", 100u"EUR", exch_mkt_27nov2020, mode=2)
155.21630064 CAD
```

Now, if we have `150 CAD` and want to see how many Euros we can buy with it, we use `mode=-2`:

```julia
julia> uconvert(u"EUR", 150u"CAD", exch_mkt_27nov2020, mode=-2)
96.63933451674102 EUR
```

### Continuously varying interest rate in a foreign bank

Now, considering again the example above of continuously varying interest rate, suppose that I am actually in Brazil and I want to see the evolution of my savings in terms of Brazillian Reais (Disclaimer: I don't have such an account!). Suppose, also, that this happened ten years ago, so we can use some real exchange rates. In this case, I use an exchange rate time series, as follows.

```julia
julia> BRLGBP_timeseries = Dict(
           "2011-01-01" => generate_exchmkt(("BRL","GBP") => 0.38585),
           "2012-01-01" => generate_exchmkt(("BRL","GBP") => 0.34587),
           "2013-01-01" => generate_exchmkt(("BRL","GBP") => 0.29998),
           "2014-01-01" => generate_exchmkt(("BRL","GBP") => 0.25562),
           "2015-01-02" => generate_exchmkt(("BRL","GBP") => 0.24153),
           "2016-01-03" => generate_exchmkt(("BRL","GBP") => 0.17093),
           "2017-01-02" => generate_exchmkt(("BRL","GBP") => 0.24888),
           "2018-01-02" => generate_exchmkt(("BRL","GBP") => 0.22569),
           "2019-01-04" => generate_exchmkt(("BRL","GBP") => 0.21082),
           "2020-01-04" => generate_exchmkt(("BRL","GBP") => 0.18784)
       );

julia> uconvert.(u"BRL", 1000u"GBP", values(BRLGBP_timeseries), mode=-1)'
1×10 LinearAlgebra.Adjoint{Quantity{Float64,BRLCURRENCY,Unitful.FreeUnits{(BRL,),BRLCURRENCY,nothing}},Array{Quantity{Float64,BRLCURRENCY,Unitful.FreeUnits{(BRL,),BRLCURRENCY,nothing}},1}}:
 2591.68 BRL  2891.26 BRL  4018.0 BRL  4743.38 BRL  …  4140.27 BRL  3912.06 BRL  4430.86 BRL  5323.68 BRL
```

Notice the optional argument `mode=-1`, so it uses the inverse rate for the conversion. As explained above, this is different than using the rate for the pair `("GBP", "BRL")` since we don't want to buy `GBP` with `BRL`, and neither do we want the direct rate for `("BRL", "GBP")` since we don't want to buy a specific amount of `BRL` with `GBP`. Instead, we want to find out how much `BRL` we can buy with a given amount of `GBP`, so we use the inverse of the rate `("BRL", "GBP")`.

**Exercise:** In the [Production cost](#production-cost) problem, suppose the raw materials come from a foreign country (or countries) and add an exchange market for properly taking into account the dependency of the production cost, the profit, and the break even point on the foreing currencies.

### Decimal and rational exchange rates

Since the type `ExchangeRate` has been defined with of value of type `Number`, it is possible to work with decimals and rational exchange rates. For example, the following code generates an `ExchangeMarket` instance with Rational rates:

```julia
julia> exch_mkt_from_dict_and_rationals = generate_exchmkt(Dict([
                  ("EUR","USD") => 119536//100000, ("USD","EUR") => 836570//1000000
              ]))
Dict{UnitfulCurrencies.CurrencyPair,UnitfulCurrencies.ExchangeRate} with 2 entries:
  CurrencyPair("USD", "EUR") => ExchangeRate(83657//100000 EUR USD⁻¹)
  CurrencyPair("EUR", "USD") => ExchangeRate(7471//6250 USD EUR⁻¹)
```

For Decimal rates, it is similar:

```julia
julia> exch_mkt_from_dict_and_decimals = generate_exchmkt(Dict([
           ("EUR","USD") => Decimal(1.19536), ("USD","EUR") => Decimal(0.836570)
       ]))
Dict{UnitfulCurrencies.CurrencyPair,UnitfulCurrencies.ExchangeRate} with 2 entries:
  CurrencyPair("USD", "EUR") => ExchangeRate(0.83657 EUR USD⁻¹)
  CurrencyPair("EUR", "USD") => ExchangeRate(1.19536 USD EUR⁻¹)
```

## Exchange rate as Unitful quantity

At some point, I changed the exchange rate from a plain number, such as `ExchangeRate(1.19536)`, to a `Unitful.Quantity`, such as `ExchangeRate(1.19536 USD EUR⁻¹)`. With that, the associated unit does not need to be formed each time during the conversion from one currency to the other. It becomes simply a multiplication in `Unitful`. That is especially useful when broadcasting, significantly speeding up the conversion of arrays of currency quantities.

For instance, the example in [Continuously varying interest rate in a foreign bank](#continuously-varying-interest-rate-in-a-foreign-bank) got more than a 100-fold reduction in speed. These were the respective results in the same machine, using `BenchmarkTools`, first with the `plain rate`:

```julia
julia> @btime uconvert.(u"BRL", 1000u"GBP", values(BRLGBP_timeseries), mode=-1)'
  2.695 ms (1262 allocations: 71.54 KiB)
```

and the second with the `UnitfulQuantity` rate:

```julia
julia> @btime uconvert.(u"BRL", 1000u"GBP", values(BRLGBP_timeseries), mode=-1)'
  21.419 μs (282 allocations: 14.82 KiB)
```

## To do

I have been doing this mostly for learning purposes. Who knows it might even turn out to be a useful package for the community. In any case, if someone wants to contribute, there are still a number of things to be added and I will be happy to have help.

Here are a few things to be done.

1. Add currency symbols such as `$`, `£`, `€`, `R$`, and so on, as units equivalent to the reference units for each currency.

1. See whether it is possible to display currencies as, say `USD$ 10.50`, instead of `10.50 USD`.

1. See whether it is possible to display 10-fold multiples of a currency in a better way than say `kEUR`, `MEUR`, `GMEUR`, and so on. It would be great to have `USD$ 10k`, `USD$ 10M`, and `USD$ 10B` (yeah, it would great if I had that! :-))

1. Add tools to read exchange market from web sources other than [fixer.io](https://fixer.io) and [currencylayer.com](https://currencylayer.com).

1. Add an option to directly obtain the exchange rates from the web sources using a given API.

1. Maybe join all tools to read the exchange market from web sources in a single function, with the market source given as an argument, instead of having one function for each.

1. Add Documentation.

## Related packages

After I started writing this package, I found out about [bhgomes/UnitfulCurrency.jl](https://github.com/bhgomes/UnitfulCurrency.jl), which, however, has been archived for unknown reasons.

Based on `bhgomes/UnitfulCurrency`, I modified my initial approach of currency pairs to be `ExchangeRate("EUR", "USD")`, instead of a six-length string `"EURUSD"`, for instance.

`bhgomes/UnifulCurrency`, however, has a single dimension for all currencies, which has the side-effect of allowing to `uconvert` different quantities without an exchange market rate, on a one-to-one basis. Moreover, all currencies are reference units for the same dimension, which might have further side-effects, although I am not sure.

There is no documentation in `bhgomes/UnitfulCurrency`, and the README is short. It seems, though, that the exchange markets in `bhgomes/UnitfulCurrency` are defined for each pair, which is different than our approach, in which an exchange market contains a dictionary of currency pairs, allowing for more flexibility, in my point of view.

Later I also found out about [JuliaFinance/Currencies.jl](https://github.com/JuliaFinance/Currencies.jl). There are some nice concepts there, distinguishing currencies from assets and cash. Take this excerpt for instance:

 > "When a currency is thought of as a financial instrument (as opposed to a mere label), we choose to refer to it as "Cash" as it would appear, for example, in a balance sheet. Assets.jl provides a Cash instrument together with a specialized Position type that allows for basic algebraic manipulations of Cash and other financial instrument positions".

However, `JuliaFinance/Currencies.jl` is not based on `Unitful`, so none of the examples above can be easily implemented.

## License

This package is licensed under the [MIT license](https://opensource.org/licenses/MIT) (see file [LICENSE](LICENSE) in the root directory of the project).
