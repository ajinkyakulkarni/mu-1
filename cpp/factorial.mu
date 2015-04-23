recipe factorial [
  default-space:address:array:location <- new location:type, 30:literal
  n:integer <- next-ingredient
  {
    # if n=0 return 1
    zero?:boolean <- equal n:integer, 0:literal
    break-unless zero?:boolean
    reply 1:literal
  }
  # return n * factorial(n - 1)
  x:integer <- subtract n:integer, 1:literal
  subresult:integer <- factorial x:integer
  result:integer <- multiply subresult:integer, n:integer
  reply result:integer
]

recipe main [
  default-space:address:space <- new location:type, 30:literal
  x:integer <- factorial 7:literal
  $print x:integer
  $print [
]
]

scenario factorial-test [
#?   dump all #? 1
  run [
    1:integer <- factorial 5:literal
  ]
  memory should contain [
    1 <- 120
  ]
]