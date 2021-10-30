;; Denyson Jurgen Mendes Grellert
;; 00243676

globals
[
  number-houses number-workplaces
  sizexy ticksday day homeToWork
  minInfectionDays maxInfectionDays
  movementsPerTick countRepetitions
  dailyDeads totalDeads dailyInfected totalInfected
]

breed [people person]

people-own
[
  isWorker isStudent isTeacher isHealthcare isElderly isComorbidity isNurse ;;here nurse will be used as a professional at a nursing home
  mortality isInfected isSymptomatic willDie startInfection finishInfection wasInfected
  homePosition workPosition hospitalPosition stayHome inICU
]

patches-own
[
  capacity capacity-total
]

;;people colors meaning:
;;red    = symptomatic infected
;;violet = asymptomatic infected
;;green  = susceptible
;;blue   = recovered

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup
  clear-all
  reset-ticks
  setup-local
  setup-people
  setup-workplace

  set ticksday round((0.45 / 3) * sqrt(2) * sizexy)
  set homeToWork true
  set day 0
  set movementsPerTick 3
  set totalInfected 0
  set dailyDeads 0
  set dailyInfected 0

  initialInfection
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to go
  tick
  evolveInfection
  spreadInfection
  symptomaticBehavior

  set countRepetitions 0
  while [ countRepetitions < movementsPerTick ]
  [
    walk
    set countRepetitions countRepetitions + 1
  ]

  finishDay
  makePlot

  if count people with [ isInfected ] = 0 [ stop ]

end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to finishDay
  if floor(ticks / ticksday) > day
  [
    set day floor(ticks / ticksday)
    set dailyDeads 0
    set dailyInfected 0
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-people
  create-people npop
  [
    set isWorker true
    set isStudent false
    set isTeacher false
    set isHealthcare false
    set isElderly false
    set isComorbidity false
    set isNurse false

    assignHome "H"

    set stayHome false
    set isInfected false
    set isSymptomatic false
    set wasInfected false
    set willDie false
    set inICU false
    set mortality work-mortality

    set workPosition [0 0]
    set hospitalPosition [-1 -1]

    set color green
    set shape "person"
  ]

  ask people
  [
    if random-float 100 <= percentage-young
    [
      set isWorker false
      set isStudent true
      set mortality young-mortality
    ]
  ]

  ask people with [ isWorker ]
  [
    if random-float 100 <= percentage-healthcare
    [
      set isWorker false
      set isHealthcare true
    ]
  ]

  ask people with [ isWorker ]
  [
    if random-float 100 <= percentage-teacher
    [
      set isWorker false
      set isTeacher true
    ]
  ]

  ask people with [ isWorker ]
  [
    if random-float 100 <= percentage-elderly
    [
      set isWorker false
      set isElderly true
      set mortality elderly-mortality
    ]
  ]

  ask people with [ isWorker ]
  [
    if random-float 100 <= percentage-comorbidity
    [
      set isComorbidity true
      set mortality comorbidity-mortality
    ]
  ]

  ask people with [ isWorker ]
  [
    if random-float 100 <= percentage-comorbidity
    [
      set isComorbidity true
      set mortality comorbidity-mortality
    ]
  ]

end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-local
  set sizexy sqrt(npop / population-density) * 100
  resize-world 0 sizexy 0 sizexy
  set number-houses round(npop / 2.9)

  ;;first set all patches as free patches
  ask patches
  [
   set pcolor white
   set plabel "F"  ;;patche free
  ]


  let n number-schools
  while [n > 0]
  [
    ask one-of patches with [ plabel = "F" ]
    [
      set plabel "S"
      set pcolor blue
      ask neighbors with [ plabel = "F" ] [ set pcolor brown + 3 set plabel "P" ]
    ]
    set n (n - 1)
  ]

  let z number-houses
  while [z > 0]
  [
    ask one-of patches with [ plabel = "F" ]
    [
      set plabel "H"
      set pcolor gray
      set capacity 3
    ]
    set z (z - 1)
  ]

  let i number-hospitals
  while [i > 0]
  [
    ask one-of patches with [ plabel = "F" ]
    [
      set plabel "HP"
      set pcolor yellow - 1
      set capacity 15
      ask neighbors with [ plabel = "F" ] [ set pcolor brown + 3 set plabel "P" ]
    ]
    set i (i - 1)
  ]

  let j number-nursingHomes
  while [j > 0]
  [
    ask one-of patches with [ plabel = "F" ]
    [
      set plabel "N"
      set pcolor cyan
    ]
    set j (j - 1)
  ]

end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to assignHome [ house ]
  ;;to set an agent to this house, the house should have less agents already assigned than the mean capacity
  let myHome one-of patches with [ plabel = house and capacity > 0 ]
  ask myHome [ set capacity (capacity - 1) ]

  set homePosition (list[pxcor] of myHome [pycor] of myHome)
  setxy first homePosition last homePosition
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to assignWork [ work ]
  ;;to set an agent to this workplace, the workplace should have less agents already assigned than the mean capacity
  let myWork one-of patches with [ plabel = work and capacity > 0 ]
  ask myWork [ set capacity (capacity - 1) ]

  set workPosition (list[pxcor] of myWork [pycor] of myWork)
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to setup-workplace
  ;;all workers will have workplaces
  set number-workplaces (count people with [ isWorker ] / 15)

  let z number-workplaces
  while [z > 0]
  [
    ask one-of patches with [ plabel = "F" ]
    [
      set plabel "W"
      set pcolor magenta
      set capacity 15
    ]
    set z (z - 1)
  ]

  ask patches with [ plabel = "HP" ] [ set capacity-total 1 ]

  ask patches with [ plabel = "S" ] [ set capacity ceiling((count people with [ isStudent or isTeacher ]) / number-schools) ]
  ask patches with [ plabel = "N" ] [ set capacity ceiling((count people with [ isElderly or isNurse ]) / number-nursingHomes) ]

  ask people with [ isWorker ] [ assignWork "W"]
  ask people with [ isHealthcare ] [ assignWork "H"]
  ask people with [ isStudent ] [ assignWork "S" ]
  ask people with [ isTeacher ] [ assignWork "S" ]

  ask people with [ isElderly ] [ assignHome "N" ]
  ask people with [ isNurse ] [ assignWork "N" ]

  ask people with [ isHealthcare ] [ assignWork "HP" ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to walk

  walk-to-hospital

  ifelse homeToWork
  [
    walk-to-work
    if floor(ticks / ticksday) > day
    [
      set homeToWork false
    ]
  ]
  [
    walk-to-home
    if floor(ticks / ticksday) > day
    [
      set homeToWork true
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to walk-to-work
  ask people with [ not stayHome and not inICU ]
  [
    let p patch xcor ycor  ;;actual patch
    let w patch first workPosition last workPosition  ;;patch of work
    ;;if is not on work already
    if p != w
    [
      ;;take the closest patch that is a path (free or path)
      let b1 min-one-of neighbors with [ plabel = "F" or plabel = "P" ] [distance w]
      ;;take the closest patch
      let b2 min-one-of neighbors [distance w]
      ;;if the closest patch is the work, then go to there
      ifelse b2 = w
      [ move-to b2 ]
      [ move-to b1 ]
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to walk-to-home
  ask people with [ not inICU ]
  [
    let p patch xcor ycor  ;;actual patch
    let h patch first homePosition last homePosition ;;patch of home
    ;;if is not on home already
    if p != h
    [
      ;;take the closest patch that is a path (free or path)
      let b1 min-one-of neighbors with [ plabel = "F" or plabel = "P" ] [distance h]
      ;;take the closest patch
      let b2 min-one-of neighbors [distance h]
      ;;if the closest patch is the home, then go to there
      ifelse b2 = h
      [ move-to b2 ]
      [ move-to b1 ]
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to walk-to-hospital
  ;;only agents who started to have symptoms go to the hospital
  if count people with [ inICU and (startInfection < ticks) ] > 0
  [
    ask people with [ inICU and (startInfection < ticks) ]
    [
      let p patch xcor ycor  ;;actual patch
      let w patch first hospitalPosition last hospitalPosition  ;;patch of hospital
      ;;if is not on hospital already
      if p != w
      [
        ;;take the closest patch that is a path (free or path)
        let b1 min-one-of neighbors with [ plabel = "F" or plabel = "P" ] [distance w]
        ;;take the closest patch
        let b2 min-one-of neighbors [distance w]
        ;;if the closest patch is the hospital, then go to there
        ifelse b2 = w
        [ move-to b2 ]
        [ move-to b1 ]
      ]
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to initialInfection
  set minInfectionDays ticksDay * minInfection
  set maxInfectionDays ticksDay * maxInfection
  ;;not start with elderly or people in hospitals
  ask n-of round(initialInfected * npop / 100) people with [ isStudent = true or isTeacher = true or isWorker = true ]
  [
    infect 1
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; this function will evolve the infection to recovery or death
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to evolveInfection
  ;;at infection time will be determined if the agent will die or not, not here
  if count  people with [ isInfected and willDie ] > 0
  [
    ask people with [ isInfected and willDie ]
    [
      if ticks = finishInfection
      [
        set dailyDeads dailyDeads + 1
        set totalDeads totalDeads + 1
        die
      ]
    ]
  ]

  ask people with [ isInfected ]
  [
    if ticks = finishInfection
    [
      set wasInfected true
      set isInfected false
      set isSymptomatic false
      set stayHome false
      set color blue
      if inICU
      [
        set inICU false
        ask patch first hospitalPosition last hospitalPosition [ set capacity-total capacity-total + 1 ]
      ]
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to spreadInfection
  ;; people in the incubation period don't spread the infection
  if count people with [isInfected and (startInfection < ticks)] > 0
  [
    ask people with [ isInfected and (startInfection < ticks) ]
    [
      ;; recovered people doesn't get reinfected
      if count other people-here with [ (not isInfected) and (not wasInfected) ] > 0
      [
        ask other people-here with [ (not isInfected) and (not wasInfected) ]
        [
          if random-float 100 < probability-of-getting-infection
          [
            infect ticks
          ]
        ]
      ]
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to infect [ start ]
  set color red
  set isInfected true
  set isSymptomatic true
  set startInfection start + incubation
  set finishInfection (start + minInfectionDays + random(maxInfectionDays - minInfectionDays))

  ;;determines whether the agent will die or not based on his mortality (of his class)
  if random-float 100 < mortality [ set willDie true ]

  ;;elderly and agents with comorbidity have a higher chance of evolving symptoms
  ifelse (isComorbidity or isElderly)
  [
    if random-float 100 < asymptomaticFragileInfectionRatio
    [
      set color violet
      set isSymptomatic false
      set willDie false
    ]
  ]
  [
    if random-float 100 < asymptomaticInfectionRatio
    [
      set color violet
      set isSymptomatic false
      set willDie false
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to symptomaticBehavior
  let hps patch-set patches with [ plabel = "HP" ]
  if count people with [isInfected and isSymptomatic and (startInfection < ticks)] > 0
  [
    ask people with [ isInfected and isSymptomatic and (startInfection < ticks) ]
    [
      ifelse count hps with [ capacity-total > 0 ] > 0
      [
        let hp one-of hps with [ capacity-total > 0 ]
        ask hp [ set capacity-total capacity-total - 1 ]

        set inICU true
        set hospitalPosition (list[pxcor] of hp [pycor] of hp)

      ]
      [
        set stayHome true
      ]
    ]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to makePlot
  set-current-plot "Daily Deads"
  set-current-plot-pen "dead"
  plot dailyDeads

  set-current-plot "Cumulative Deads"
  set-current-plot-pen "dead"
  plot totalDeads
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
555
10
1451
907
-1
-1
12.0
1
10
1
1
1
0
1
1
1
0
73
0
73
1
1
1
ticks
30.0

BUTTON
15
10
79
43
Setup
setup
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
90
10
153
43
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

INPUTBOX
15
60
150
120
npop
1500.0
1
0
Number

SLIDER
185
130
350
163
work-mortality
work-mortality
0
10
1.2
0.05
1
%
HORIZONTAL

SLIDER
185
200
350
233
young-mortality
young-mortality
0
10
0.8
0.05
1
%
HORIZONTAL

SLIDER
15
200
180
233
percentage-young
percentage-young
0
100
16.8
0.1
1
%
HORIZONTAL

SLIDER
15
165
180
198
percentage-teacher
percentage-teacher
0
10
0.69
0.01
1
%
HORIZONTAL

SLIDER
15
130
180
163
percentage-healthcare
percentage-healthcare
0
10
0.73
0.01
1
%
HORIZONTAL

SLIDER
15
235
180
268
percentage-elderly
percentage-elderly
0
100
15.0
0.1
1
%
HORIZONTAL

SLIDER
185
235
350
268
elderly-mortality
elderly-mortality
0
20
10.0
0.01
1
%
HORIZONTAL

SLIDER
15
270
180
303
percentage-comorbidity
percentage-comorbidity
0
25
5.0
0.01
1
%
HORIZONTAL

SLIDER
185
270
350
303
comorbidity-mortality
comorbidity-mortality
0
20
4.0
0.01
1
%
HORIZONTAL

INPUTBOX
185
60
320
120
population-density
2800.0
1
0
Number

SLIDER
15
315
180
348
number-schools
number-schools
0
25
10.0
1
1
NIL
HORIZONTAL

SLIDER
185
315
350
348
number-hospitals
number-hospitals
0
30
2.0
1
1
NIL
HORIZONTAL

SLIDER
15
350
180
383
number-nursingHomes
number-nursingHomes
0
20
3.0
1
1
NIL
HORIZONTAL

SLIDER
185
165
350
198
percentage-nurse
percentage-nurse
0
10
0.02
0.01
1
%
HORIZONTAL

SLIDER
15
395
180
428
minInfection
minInfection
0
25
10.0
1
1
days
HORIZONTAL

SLIDER
15
430
180
463
maxInfection
maxInfection
0
40
25.0
1
1
days
HORIZONTAL

SLIDER
15
465
180
498
incubation
incubation
0
15
7.0
1
1
days
HORIZONTAL

SLIDER
185
395
350
428
initialInfected
initialInfected
0
2
0.21
0.01
1
%
HORIZONTAL

SLIDER
185
430
350
463
asymptomaticInfectionRatio
asymptomaticInfectionRatio
0
100
95.0
0.5
1
%
HORIZONTAL

SLIDER
185
465
350
498
asymptomaticFragileInfectionRatio
asymptomaticFragileInfectionRatio
0
100
20.0
0.5
1
%
HORIZONTAL

SLIDER
185
350
350
383
probability-of-getting-infection
probability-of-getting-infection
0
25
5.0
0.5
1
%
HORIZONTAL

MONITOR
365
130
500
175
Symptomatic infected
count people with [ color = red ]
2
1
11

MONITOR
365
180
500
225
Asymptomatic intfected
count people with [ color = violet ]
2
1
11

MONITOR
365
230
500
275
Recovered
count people with [ color = blue ]
2
1
11

MONITOR
365
280
500
325
Susceptible
count people with [ color = green ]
2
1
11

PLOT
15
510
505
660
Infection State
Time
People
0.0
300.0
0.0
1500.0
true
true
"" ""
PENS
"Symptomatic" 1.0 0 -2674135 true "" "plot count people with [ color = red ]"
"Asymptomatic" 1.0 0 -8630108 true "" "plot count people with [ color = violet ]"
"Recovered" 1.0 0 -13345367 true "" "plot count people with [ color = blue ]"
"Susceptible" 1.0 0 -10899396 true "" "plot count people with [ color = green ]"

PLOT
15
665
215
800
Daily Deads
Time
People
0.0
30.0
0.0
10.0
true
false
"" ""
PENS
"dead" 1.0 1 -16777216 true "" ""

PLOT
220
665
420
800
Cumulative Deads
People
Time
0.0
30.0
0.0
10.0
true
false
"" ""
PENS
"dead" 1.0 0 -16777216 true "" ""

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
1
@#$#@#$#@
