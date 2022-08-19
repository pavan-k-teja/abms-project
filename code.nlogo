extensions [ csv ]

breed [ consumers consumer ]
breed [ firms firm ]
breed [ vehicles vehicle ]

consumers-own [
  income
  vehicle-end
  vmt
]

firms-own [
  capital
  isEV
  vehicle-id
  q
  qmax
  rnd
  rnd-process
  rnd-product
  total-rnd-process
  total-rnd-product
  revenue
  net-profit
  profit-margin
  market-share-firm

  investment
  debt
  debt-repayment

  isProfitable
  loss-years
]

vehicles-own [
  isEV
  firm-id
  prod-cost
  prod-eff
  engine-cost ;CV
  battery-cost;EV
  price
  purchase-cost ; price-subc
  driving-range
  wtp
  resale-value
  utility


]


globals [
  ;consumer
  max-income
  holding-period; 6
  subc
  subc-period

  ;vehicle
  min-driving-range
  w
  a0
  b0-cv
  b0-ev
  alpha-cv
  alpha-ev
  capacity-ev
  capacity-cv
  current-max-range-cv
  current-max-range-ev
  component-cost-cv
  component-cost-ev
  min-battery-cost
  min-engine-cost
  f-cost-cv
  f-cost-ev
  f-eff-cv
  f-eff-ev
  lifespan-cv
  lifespan-ev
  d-cv
  d-ev
  electricity-cost
  gasoline-cost

  ;firm
  num-of-cv
  num-of-ev
  phi
  lambda
  sigma
  u2
  p0
  p1
  p2

  subf
  subf-period

  ;else
  current-year
  annuity
  market-share-cv
  market-share-ev
  rate-of-fuel-increament
]

to setup
  clear-all
  file-close-all

  initialize-globals
  initialize-consumers
  initialize-firms

  reset-ticks
end


to initialize-globals
  ;consumer
  set holding-period 6

  if consumer-policy = "Business-as-usual"
  [
    set subc 0
    set subc-period 0
  ]
  if consumer-policy = "$7500 for 5 years"
  [
    set subc 7500
    set subc-period 5
  ]
  if consumer-policy = "$7500 for 10 years"
  [
    set subc 7500
    set subc-period 10
  ]
  if consumer-policy = "$15000 for 5 years"
  [
    set subc 15000
    set subc-period 5
  ]

  ;vehicle
  set min-driving-range 75
  set w 22006
  set a0 3.6
  set b0-cv 0.015
  set b0-ev 0.0545
  set alpha-cv 35
  set alpha-ev 50
  set capacity-cv 15
  set capacity-ev 40
  ;set current-max-range
  set component-cost-cv 8465
  set component-cost-ev 9193
  set min-engine-cost 1000
  set min-battery-cost 4000
  set f-cost-cv 9465
  set f-cost-ev 13193
  set f-eff-cv 54.5
  set f-eff-ev 15
  set lifespan-cv 15
  set lifespan-ev 8
  set d-cv 6.7
  set d-ev 12.5
  set gasoline-cost 2.7424
  set electricity-cost 0.1154

  ;firm
  set num-of-cv 150
  set num-of-ev 30
  set phi 0.05
  set lambda 0.01
  set sigma 0.15
  set u2 0.1
  set p0 0.32
  set p1 3.43
  set p2 0.1

  if manufacturer-policy = "Business-as-usual"
  [
    set subf 0
    set subf-period 0
  ]
  if manufacturer-policy = "$0.6 M for 5 years"
  [
    set subf 0.6
    set subf-period 5
  ]
  if manufacturer-policy = "$106 M for 5 years"
  [
    set subf 106
    set subf-period 5
  ]
  if manufacturer-policy = "$171.1 M for 10 years"
  [
    set subf 171.1
    set subf-period 10
  ]


  if fuel-price = "decrease 20%"
  [
    set rate-of-fuel-increament -1 * 1.3712

  ]
  if fuel-price = "increase 20%"
  [
    set rate-of-fuel-increament 1.3712
  ]
  if fuel-price = "increase 40%"
  [
    set rate-of-fuel-increament 2.7424
  ]
  if fuel-price = "no change"
  [
    set rate-of-fuel-increament 0
  ]

  ;else
  set current-year 2010
  set annuity find-annuity holding-period
end


to initialize-consumers
  file-close-all ; close all open files

  file-open "consumer.csv" ; open the file with the turtle data

  ; We'll read all the data in a single loop
  while [ not file-at-end? ] [
    let data csv:from-row file-read-line

    create-consumers 1 [
      ht
      set income    item 0 data
      set vmt       item 1 data

      set vehicle-end random 6 + 2010
    ]
  ]
  set max-income max [ income ] of consumers

  file-close ; make sure to close the file
end

to initialize-firms
  create-firms 150 [
    setxy random-xcor random-ycor
    set shape "factory"
    set size 1.5
    set capital ( ( random-float 9 ) + 1 ) * 1000000000
    set isEV false
    let vehicle-who -1

    hatch-vehicles 1 [
      ht
      set vehicle-who who
      set isEV false
      set firm-id [ who ] of myself
      set engine-cost 2357
      set prod-cost component-cost-cv + engine-cost
      set prod-eff 22
      set driving-range capacity-cv * prod-eff
    ]

    set vehicle-id vehicle-who

  ]


  create-firms 30 [
    setxy random-xcor random-ycor
    set shape "factory"
    set size 1.5
    set capital ( ( random-float 9 ) + 1 ) * 1000000000
    set isEV true
    let vehicle-who -1

    hatch-vehicles 1 [
      ht
      set vehicle-who who
      set isEV true
      set firm-id [ who ] of myself
      set battery-cost 40000
      set prod-cost component-cost-ev + battery-cost
      set prod-eff 0
      set driving-range capacity-ev * prod-eff
    ]

    set vehicle-id vehicle-who


  ]

  ask firms [
    set total-rnd-process 0
    set total-rnd-product 0
    set qmax lambda * capital
    set q 0
    set net-profit 0
    set debt 0
    set loss-years 0
    set isProfitable false
  ]


end

to go
  if current-year > 2050
  [ stop ]

  conduct-rnd ; also update values

  ask firms [
    if not eligible [
      ask vehicle vehicle-id [ die ]
      die
    ]
  ]

  consumers-buy
  update-sales

  ask firms [
    if firm-exits [
      ask vehicle vehicle-id [ die ]
      die
    ]
  ]

  update-market-shares
  set current-year current-year + 1
  update-agent-attributes

  update-plots
  tick
end

to conduct-rnd
  ask firms [
    let prc 1
    ask vehicle vehicle-id [ set prc prod-cost ]
    set rnd phi * ( capital - (prc * 10000) )
    ;ifelse isEV
    ;[ set rnd phi * ( capital - (prc * 10000) ) ]
    ;[ set rnd phi * ( capital ) ]

    show rnd
    ;ifelse isProfitable [
    ;][
    ;  set rnd phi * capital
    ;]
    set capital capital - rnd

    let q-rand random-float 1
    set rnd-process q-rand * rnd
    set rnd-product ( 1 - q-rand ) * rnd

    set total-rnd-process total-rnd-process + rnd-process
    set total-rnd-product total-rnd-product + rnd-product


    let tot-rnd-pc total-rnd-process
    let tot-rnd-pd total-rnd-product
    let curr-eff -1
    ask vehicle vehicle-id [

      let new-cost cost-improvement tot-rnd-pc
      set prod-eff eff-improvement tot-rnd-pd

      ifelse isEV
      [
        set battery-cost new-cost
        set prod-cost component-cost-ev + battery-cost
        set driving-range capacity-ev * prod-eff
      ]
      [
        set engine-cost new-cost
        set prod-cost component-cost-cv + engine-cost
        set driving-range capacity-cv * prod-eff
      ]

      set wtp find-wtp

    ]

  ]
  show length ( [ driving-range ] of ( vehicles with [ isEV = false ] ) )
  show length ( [ driving-range ] of ( vehicles with [ isEV = true ] ) )
  show current-year

  set current-max-range-cv max [ driving-range ] of vehicles with [ isEV = false ]
  set current-max-range-ev max [ driving-range ] of vehicles with [ isEV = true ]

  ask vehicles [
    let mr -1
    let d -1
    ifelse isEV
    [
      set mr current-max-range-ev
      set d d-ev
    ]
    [
      set mr current-max-range-cv
      set d d-cv
    ]
    let u ( driving-range / mr ) * 0.5

    set price prod-cost * ( 1 + u )
    set purchase-cost price - subc
    set resale-value ( 1 - d * holding-period ) * price

  ]

end

to-report eligible
  let cond1 false
  let cond2 false

  ask vehicle vehicle-id [
    if driving-range < min-driving-range
    [ set cond1 true ]

    if price >= 0.6 * max-income
    [ set cond2 true ]

  ]

  if cond1 or cond2
  [ report false ]

  report true
end


to-report cost-improvement [ tot-rnd-pc ]

  let tot-rnd-pc-cv tot-rnd-pc / 1
  let tot-rnd-pc-ev tot-rnd-pc / 1000000
  ifelse isEV
  [
    let z ln ( 49193 - f-cost-ev ) - ( a0 * tot-rnd-pc-ev / (f-cost-ev - 9193))
    report ( f-cost-ev + e ^ z ) * 1
  ]
  [
    let z ln ( 2357 - f-cost-cv + 8465 ) - ( a0 * tot-rnd-pc-cv / ( f-cost-cv - 8465))
    report ( f-cost-cv + e ^ z ) * 1
  ]

end

to-report eff-improvement [ tot-rnd-pd ]

  let tot-rnd-pd-cv tot-rnd-pd / 1
  let tot-rnd-pd-ev tot-rnd-pd / 1000000
  ifelse isEV
  [
    let z ln ( f-eff-ev ) - ( b0-ev * tot-rnd-pd-ev / f-eff-ev)
    report ( f-eff-ev - e ^ z ) * 1
  ]
  [
    let z ln ( f-eff-cv - 22 ) - ( b0-cv * tot-rnd-pd-cv / f-eff-cv)
    report ( f-eff-cv - e ^ z ) * 1
  ]

end


to consumers-buy
  ask consumers [
    if current-year >= vehicle-end
    [ stop ]

    let purchase-budget 0.6 * income
    let utility-list []

    ask vehicles[

      let is-filled false
      ask firm firm-id [
        if q > qmax or ( isEV and current-year < 2010 + holding-period )
        [ set is-filled true]
      ]

      if is-filled = false
      [
        if [price] of self < purchase-budget
        [
          let tco find-tco myself self
          set utility wtp + tco

          set utility-list ( insert-item 0 utility-list self )
          set utility-list ( sort-by [ [ vhcl1 vhcl2 ] -> [utility] of vhcl1 < [utility] of vhcl2 ] utility-list )
          if length utility-list > 5
          [ set utility-list ( remove-item 0 utility-list ) ]
        ]

      ]

    ]

    if length utility-list != 0
    [
      let i 0
      while [ i < 1 ]
      [
        let choice one-of utility-list
        let fi -1

        ask choice [
          set fi firm-id
        ]
        ask firm fi [
          set q q + 1
        ]
        set i i + 1
      ]
    ]

    set vehicle-end current-year + holding-period
  ]
end



to-report find-wtp
  let alpha -1
  ifelse isEV
  [ set alpha alpha-ev ]
  [ set alpha alpha-cv ]

  report alpha * ( driving-range - min-driving-range ) + w

end

to-report find-tco [ cons vhcl ]
  let pc -1
  let ef -1
  let unit-price -1
  ask vhcl [
    set pc purchase-cost
    set ef prod-eff
    ifelse isEV
    [ set unit-price electricity-cost ]
    [ set unit-price gasoline-cost ]
  ]
  let m -1
  ask cons [
    set m vmt

  ]

  let energy-cost m * ef * unit-price
  set energy-cost energy-cost * annuity
  let total-resale resale-value / ( ( 1 + p0 ) ^ holding-period )

  report pc + energy-cost - total-resale

end

to-report find-annuity [ years ]
  let ans ( 1 - ( 1 + p0 ) ^ ( -1 * years ) ) / years

  report ans
end

to update-agent-attributes
  ask firms [
    ifelse q < qmax
    [ set investment 0 ]
    [ set investment u2 * capital ]

    set q 0 ;firm

    set debt debt + investment - subf

    ifelse debt < sigma * net-profit
    [
      set debt-repayment debt
      set isProfitable true
      set loss-years 0
    ]
    [
      set debt-repayment sigma * net-profit
      set isProfitable false
      set loss-years loss-years + 1
    ]

    set capital ( 1 - p2 ) * capital + investment + net-profit - rnd - debt-repayment
    set debt debt - debt-repayment
  ]

  ask consumers [
    set income income * 1.02
  ]

  set gasoline-cost gasoline-cost + rate-of-fuel-increament
end


to update-market-shares
  let qsum random-float 0
  set market-share-ev random-float 0
  set market-share-cv random-float 0
  ask firms [
    show q
    set qsum qsum + q
  ]
  ask firms [
    set market-share-firm q
    ifelse isEV
    [ set market-share-ev market-share-ev + market-share-firm ]
    [ set market-share-cv market-share-cv + market-share-firm ]

  ]
  show market-share-cv
  show market-share-ev
  ask firms [
    set market-share-firm ( market-share-firm / qsum )
    show market-share-firm
    set size 1 + ( capital / 5000000000 )
  ]
  set market-share-ev ( market-share-ev / qsum )
  set market-share-cv ( market-share-cv / qsum )

  ;ask firms with [isEV = true] [

  ;]
  ;ask firms with [isEV = false] [
  ;  set size 1 + market-share-cv
  ;]

  show market-share-cv
  show market-share-ev
  show qsum

end

to-report firm-exits

  let cond1 false
  let cond2 false
  let cond3 false

  if capital < min-capital
  [ set cond1 true ]

  if isProfitable = false and loss-years + 1 > max-req-time-in-loss
  [ set cond2 true ]

  if isProfitable = false and debt / ( capital - debt ) > 0.5
  [ set cond3 true ]

  if cond1 or cond2 or cond3
  [ report true ]


  report false
end



to update-sales
  let prc -1
  let cost -1
  ask firms [
    ask vehicle vehicle-id [
      set prc price
      set cost prod-cost
    ]
    set revenue q * prc
    set net-profit q * ( prc - cost )

    ifelse revenue = 0
    [ set profit-margin 0]
    [ set profit-margin net-profit / revenue ]


  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
107
18
789
391
-1
-1
11.05
1
10
1
1
1
0
1
1
1
-30
30
-16
16
1
1
1
ticks
30.0

BUTTON
15
53
78
86
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
16
96
79
129
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
16
142
79
175
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1231
28
1646
305
product innovation
time
rnd-product
2010.0
2050.0
0.0
300.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy current-year ( median [rnd-product] of firms with [ isEV = false ] ) / ( 1000000 )"
"pen-1" 1.0 0 -2674135 true "" "plotxy current-year ( median [rnd-product] of firms with [ isEV = true ] ) / ( 1000000 )"

SLIDER
132
428
368
461
min-capital
min-capital
10
100
50.0
1
1
millions
HORIZONTAL

SLIDER
132
470
365
503
max-req-time-in-loss
max-req-time-in-loss
1
10
8.0
1
1
years
HORIZONTAL

PLOT
1011
316
1397
585
price
time
price
2010.0
2050.0
10000.0
85000.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy current-year mean [price] of vehicles with [isEV = false]"
"pen-1" 1.0 0 -2674135 true "" "plotxy current-year mean [price] of vehicles with [isEV = true]"

CHOOSER
456
410
626
455
consumer-policy
consumer-policy
"Business-as-usual" "$7500 for 5 years" "$7500 for 10 years" "$15000 for 5 years"
0

CHOOSER
455
469
627
514
manufacturer-policy
manufacturer-policy
"Business-as-usual" "$0.6 M for 5 years" "$106 M for 5 years" "$171.1 M for 10 years"
0

PLOT
812
26
1222
305
process innovation
years
rnd-process
2010.0
2050.0
0.0
150.0
false
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy current-year ( median [rnd-process] of firms with [ isEV = false ] ) / ( 1000000 )"
"pen-1" 1.0 0 -2674135 true "" "plotxy current-year ( median [rnd-process] of firms with [ isEV = true ] ) / ( 1000000 )"

CHOOSER
677
417
815
462
fuel-price
fuel-price
"no change" "decrease 20%" "increase 20%" "increase 40%"
0

@#$#@#$#@
#  EFFECTS OF PUBLIC SUBSIDIES OF EMERGING INDUSTRY THAT IS ON _ELECTRIC VEHICLE_


## PURPOSE AND PATTERNS

The purpose of this ABMS is in seeking a clear understanding of the effects of government subsidies on new technology emergence. In this model, we used electric vehicles development in the U.S. to examine the subsidy performance from the consumer and manufacturer perspective and adopt an agent-based simulation model to deal with the incomparability of different subsidies.
To facilitate the commercialization and diffusion of EV technologies, a number of subsidy policies from both the demand and supply sides have been implemented. 
The study differentiates the traditional and new technologies from the perspectives of the product price, performance, and post-adoption expenditure, and constructs an agent-based model which fully considers the heterogeneity of consumers and manufacturer
Our model can be used to explore different aspects of the emergence of electric vehicles with government policies.


## ENTITIES, STATE VARIABLES, AND SCALES

There are three entities: consumers, firms, and vehicles. Each has a few properties.
Variables used and the model and the scales used by them are mentioned below

### Consumer

  * _income_ - the income of the consumer in __dollars__
  * _vehicle-end_
  * _vmt_ - vehicles miles traveled i.e. the number of miles traveled by the consumer with the vehicle units is in __miles__

### Firms

  * _capital_ - The Net worth of the company is in  __billion dollars__ and it starts from 1 billion dollars to 10 billion dollars
  * _isEV_ - Whether the firm produces vehicles in EV or not
  * _vehicle-id_ - The unique number for identifying vehicle
  * _q_ - quantity of vehicles produced 
  * _qmax_ - max quantity of vehicles produced by firms
  * _rnd_ - Research and development cost in __millions dollars__
  * _rnd-process_ - Allocation of R&D for reducing product cost and innovation in __millions dollars__
  * _rnd-product_ - Allocation of R&D for enhancing efficiency and innovation in __millions dollars__
  * _total-rnd-process_ - the sum of all rnd-process over years in __millions dollars__
  * _total-rnd-product_ - the sum of all rnd-product over years in __millions dollars__
  * _revenue_ - total amount received on sales in __millions dollars__
  * _net-profit_ - profit gained in a year in __millions dollars__
  * _profit-margin_ - net-profit divided by revenue
  * _market-share-firm_ - Firms share of vehicles in the market 
  * _investment_ - new money poured every year into the firm  in __millions dollars__
  * _debt_ - Total loan for the company  in __millions dollars__
  * _debt-repayment_ - Every repayment that the company pays for the debt from the profit the company gets  in __millions dollars__
  * _isProfitable_ -  profitable as Yes or No on years
  * _loss-years_ - no of years with continued losses for the firm in __years__


### Vehicles

  * _isEV_  - Whether the vehicle is EV or not
  * _firm-id_ -  Vehicle produced from which firm
  * _prod-cost_ - Production cost of car  in __dollars__
  * _prod-eff_ - Efficiency of car
  * _engine-cost_ - Production cost of the car engine (for CV) in __dollars__
  * _battery-cost_ - Production cost of the car battery (for EV) in __dollars__
  * _price_ - the cost of the vehicle in the market without subsidy in __dollars__
  * _purchase-cost_ - the cost of the vehicle in the market with subsidy in __dollars__
  * _driving-range_ -Max miles that can be driven by the vehicle
  * _wtp_ - Index of willingness to purchase
  * _resale-value_ - The car resale value after certain period of time in __years__

### Global variables

  * _subc_  - Subsidy for the customers 
  * _subc-period_ - The time for which the subsidy is given for the customers
  * _Min-driving-range_ - Min driving capability of vehicle
  * _capacity-ev_ - Battery capacity in KWh
  * _capacity-cv_ - Engine capacity in Litres
  * _current-max-range-cv_ - Max miles that can travelled in a single full charge
  * _current-max-range-ev_ - Max miles that can travelled with a  full tank
  *  _component-cost-cv_ - Components cost of CV 
  * _component-cost-ev_ - Components cost of CV
  * _num-of-cv_  - Number of firms producing cv vehicles
  * _num-of-ev_  - Number of firms producing ev vehicles




## PROCESS OVERVIEW AND SCHEDULING
Each time step includes the following stages in the following order.
The initial configurations populate the “market” with a set of consumer agents and manufacturer agents where the income of consumers and the capitals of manufacturers are Normally distributed.
The consumers randomly purchase their new car with a price lower than the purchase budget, from one of the top 10 firms in the market after each holding period for a total cost of ownership being TCOi,j = pcj + eci,j x A(p0, year) - resalej / (1 + p0)year
The firms conduct R&D to improve their product’s performance by increasing the range and mileage of the vehicle and decreasing the product’s cost with an expenditure of 5% of their original capital each year.
Until the products meet the entry condition of the market (minimum vehicle driving range & product price lower than maximum purchasing budget), firms are excluded from the market, where the consumer’s willingness to pay is positively correlated with the Minrange. (WTPi,j = αm x (rangej - Minrangem) + ωm)
Once the firm enters the market, consumers can make the purchase, and the sales & profit of each firm for every year could be calculated, based on which, the decision for a firm to survive or exit the market is determined.
Firms withdraw forever from the market if the capital decreases below the minimum required level or the profit margin becomes negative and the asset-liability ratio exceeds a certain proportion for a certain period of time. If the firm survives the year, market shares are calculated based on returns.



![If this image is not visible, please check the artifacts for the image main.png and keep it in the same folder](main.png)

The Model starts in the year  2010 with agents we initialized and the firms will work on their R&D  to improve the product cost, performance of vehicles, and every year the firms’ new products go through eligibility conditions like their financial status, product cost, market opportunity and if these metrics are in positive side then the product enters into the market and if it fails it will be excluded from the market. All new products after entering the market, consumers can purchase these products, and business runs as usual. After each year firms calculate profits, market-shares year, if the firm is guaranteed to be bankrupt based on our conditions, the firms will exit from the market. Each year the performance of the firms will be updated and iterated every year until 2050. These firms’ results are obtained at the end of the model and results will be analyzed.

The model determines the significant impact of consumer and manufacturer subsidies by the government on the transition of combustion vehicles to Electrical vehicles over a period of time. The initial configurations populate the “market” with a set of consumer agents and manufacturer agents where the income of consumers and the capitals of manufacturers are Normally distributed.
The simulation then proceeds with agents interacting according to the number of consumers making purchases and how firms make decisions regarding entry and exit, production and sales, R&D activities. After the calculation of the market share of EVs, time automatically increases by one year. If the pre-fixed number of periods is not reached (40 years in the model we’re simulating), the agent attributes are updated and the above procedures are repeated; otherwise, the process is terminated.
Each year, the firms conduct R&D to improve their product’s performance by increasing the range and mileage of the vehicle and decreasing the product’s cost. During the initial stage, until the products meet the entry condition of the market (minimum vehicle driving range & product price lower than maximum purchasing budget), firms are excluded. Once entered, consumers can make the purchase and sales & profit of each firm for every year could be calculated, based on which, the decision for a firm to survive or exit the market is determined.
Either The capital decreasing below the minimum required level or the profit margin becoming negative and the asset-liability ratio exceeding a certain proportion for a certain period of time will result in the exit of the firm.
After every 6 years, consumers randomly purchase their new car with a price lower than the purchase budget, from one of the top 10 firms in the market. The subsidy remains zero for Combustion Vehicles throughout all simulation periods.


## DESIGN CONCEPTS

### Basic Principles
Every year the firms undergo R&D to minimize their product’s cost and maximize their product’s efficiency by utilizing 5% of their original capital as the expenditure (RD = ϕK). when an attribute gets closer to the technology frontier, the rate of technical progress decreases gradually. Each year, the firm’s survival in the market is determined by its capital and profit margin.

### Adaptation
The firms are excluded from the participation in the market until their products meet the entry condition with minimum vehicle driving range (sizej × effj) & product price lower than the maximum purchasing budget. Once the capital is below the minimum required level or the profit margin is negative, firms withdraw from the market forever. Through R&D, the firms can achieve maximum efficiency of (Feff) and a minimum product cost of (Fcost).
### Objective
After each holding period, the consumers randomly purchase their new car with a price lower than the purchase budget, from one of the top 10 firms in the market. The subsidy remains zero for Combustion Vehicles throughout all simulation periods. A number of subsidy policies from both the demand and supply sides have been implemented to facilitate the commercialization and diffusion of EV technologies. In each period, the firms conduct R&D to reduce the __production cost__ 
```
Δcostj = a0 RDjpc(1 - Fcost / costj)
```
and improve the __energy consumption efficiency__ 
```
Δeffj = b0 RDjpd(1 - effj / Feff) 
```

### Interaction
In agents to agents interaction, Firms interact with produced cars for its development of car components as R&D and in annual growth, Consumers interact with cars like buying the car, driving the car, and selling the car to others after certain years. These agents to agents interactions will develop an understanding of the outcomes of the model


### Stochasticity
* We are assigning the capital of each firm randomly from 1 billion dollars to 10 billion dollars.
* For distributing r&d expenditure from the capital of 5 percent to production r&d, process r&d we choose the distribution to be randomly assigned.


### Observation
Output is observed for every year while running the model because each run represents a year, based on the outcomes of each year the firms will go through the analysis of debt, profit, capital to decide their eligibility in running the business in the market next year. These observations are then recorded and analyzed through graphical methods after the end of running the model





## INITIALIZATION
Every value is taken from standard resources and from paper



### CV
* _Tank capacity_ - 15 Gallons
* _Energy efficiency_ -  22 miles per gallons (mpg)
* _Maximum energy efficiency_ - 54.5 mpg
* _Maximum driving range_ - 2357 dollars
* _Engine cost_ - 817.5 dollars
* _Components cost_ - 8465 dollars
* _Minimum engine cost_ - 1000 dollars
* _Lifespan of __cv___ - 15 years
* _Depreciate rate of __cv___ - 6.7%
* _Gasoline price_ - 2.7424 dollars per gallon

### EV
* _Battery size_ - 40 kWh
* _Energy efficiency_ - 3 Miles per KWh
* _Maximum energy efficiency_ - 15 Miles per kWh
* _Maximum driving range_ - 600 Miles
* _Battery cost_ - 40, 000 dollars
* _Components cost_ - 9193 dollars
* _Minimum battery cost_ -  4000 dollars
* _Lifespan of __ev___ - 8 years
* _Depreciate rate of __ev___ - 12.5%
* _Electricity price_ - 0.1154 dollars per kWh


## INPUT DATA

We are using Consumer data for the number and annual household income of potential consumers, as well as their annual holding period and driving distance of vehicles in 2010, we mainly referred to the data collected from the U.S. Bureau of Economic Analysis and Ford Motor Company (Helveston et al., 2015) 





## SUB-MODELS
We don’t have any sub-models for our project













@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

factory
false
0
Rectangle -7500403 true true 76 194 285 270
Rectangle -7500403 true true 36 95 59 231
Rectangle -16777216 true false 90 210 270 240
Line -7500403 true 90 195 90 255
Line -7500403 true 120 195 120 255
Line -7500403 true 150 195 150 240
Line -7500403 true 180 195 180 255
Line -7500403 true 210 210 210 240
Line -7500403 true 240 210 240 240
Line -7500403 true 90 225 270 225
Circle -1 true false 37 73 32
Circle -1 true false 55 38 54
Circle -1 true false 96 21 42
Circle -1 true false 105 40 32
Circle -1 true false 129 19 42
Rectangle -7500403 true true 14 228 78 270

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="consumer-policy">
      <value value="&quot;Business-as-usual&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min-capital">
      <value value="66"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-req-time-in-loss">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="manufaturer-policy">
      <value value="&quot;Business-as-usual&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="value checking" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(( median [rnd-process] of firms with [ isEV = false ] ) / ( 1000000 ) ) + 4</metric>
    <metric>( median [rnd-process] of firms with [ isEV = true ] ) / ( 1000000 ) * 1.2 * e ^ ( -1 * ( current-year - 2010 ) / 10)</metric>
    <metric>(( median [rnd-product] of firms with [ isEV = false ] ) * 2 / ( 1000000 )) + 10</metric>
    <metric>(( median [rnd-product] of firms with [ isEV = true ] ) * 1.5 / ( 1000000 ) * e ^ ( -1 * ( current-year - 2010 ) / 10)) + 10</metric>
    <steppedValueSet variable="min-capital" first="50" step="5" last="100"/>
    <steppedValueSet variable="max-req-time-in-loss" first="6" step="1" last="10"/>
  </experiment>
  <experiment name="consumer-policy" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>(( median [rnd-process] of firms with [ isEV = false ] ) / ( 1000000 ) ) + 4</metric>
    <metric>( median [rnd-process] of firms with [ isEV = true ] ) / ( 1000000 ) * 1.2 * e ^ ( -1 * ( current-year - 2010 ) / 10)</metric>
    <metric>(( median [rnd-product] of firms with [ isEV = false ] ) * 2 / ( 1000000 )) + 10</metric>
    <metric>(( median [rnd-product] of firms with [ isEV = true ] ) * 1.5 / ( 1000000 ) * e ^ ( -1 * ( current-year - 2010 ) / 10)) + 10</metric>
    <enumeratedValueSet variable="consumer-policy">
      <value value="&quot;Business-as-usual&quot;"/>
      <value value="&quot;$7500 for 5 years&quot;"/>
      <value value="&quot;$7500 for 10 years&quot;"/>
      <value value="&quot;$15000 for 5 years&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="manufacturer-policy">
      <value value="&quot;Business-as-usual&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
