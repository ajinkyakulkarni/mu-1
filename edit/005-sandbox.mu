## running code from the editor and creating sandboxes
#
# Running code in the sandbox editor prepends its contents to a list of
# (non-editable) sandboxes below the editor, showing the result and a maybe
# few other things.

container programming-environment-data [
  sandbox:address:sandbox-data  # list of sandboxes, from top to bottom
]

container sandbox-data [
  data:address:array:character
  response:address:array:character
  expected-response:address:array:character
  # coordinates to track clicks
  starting-row-on-screen:number
  code-ending-row-on-screen:number  # past end of code
  response-starting-row-on-screen:number
  screen:address:screen  # prints in the sandbox go here
  next-sandbox:address:sandbox-data
]

scenario run-and-show-results [
  $close-trace  # trace too long
  assume-screen 100/width, 15/height
  # recipe editor is empty
  1:address:array:character <- new []
  # sandbox editor contains an instruction without storing outputs
  2:address:array:character <- new [divide-with-remainder 11, 3]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊divide-with-remainder 11, 3                      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  screen-should-contain-in-color 7/white, [
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                   divide-with-remainder 11, 3                      .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
    .                                                                                                    .
  ]
  screen-should-contain-in-color 245/grey, [
    .                                                                                                    .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊                                                 .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # run another command
  assume-console [
    left-click 1, 80
    type [add 2, 2]
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen prints the results
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊add 2, 2                                         .
    .                                                  ┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊divide-with-remainder 11, 3                      .
    .                                                  ┊3                                                .
    .                                                  ┊2                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

after <global-keypress> [
  # F4? load all code and run all sandboxes.
  {
    do-run?:boolean <- equal *k, 65532/F4
    break-unless do-run?
    status:address:array:character <- new [running...  ]
    screen <- update-status screen, status, 245/grey
    error?:boolean, env, screen <- run-sandboxes env, screen
    # F4 might update warnings and results on both sides
    screen <- render-all screen, env
    {
      break-if error?
      status:address:array:character <- new [            ]
      screen <- update-status screen, status, 245/grey
    }
    screen <- update-cursor screen, recipes, current-sandbox, *sandbox-in-focus?
    loop +next-event:label
  }
]

recipe run-sandboxes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  screen:address <- next-ingredient
  stop?:boolean, env, screen <- update-recipes env, screen
  reply-if stop?, 1/errors-found, env/same-as-ingredient:0, screen/same-as-ingredient:1
  # check contents of right editor (sandbox)
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  {
    sandbox-contents:address:array:character <- editor-contents current-sandbox
    break-unless sandbox-contents
    # if contents exist, first save them
    # run them and turn them into a new sandbox-data
    new-sandbox:address:sandbox-data <- new sandbox-data:type
    data:address:address:array:character <- get-address *new-sandbox, data:offset
    *data <- copy sandbox-contents
    # push to head of sandbox list
    dest:address:address:sandbox-data <- get-address *env, sandbox:offset
    next:address:address:sandbox-data <- get-address *new-sandbox, next-sandbox:offset
    *next <- copy *dest
    *dest <- copy new-sandbox
    # clear sandbox editor
    init:address:address:duplex-list <- get-address *current-sandbox, data:offset
    *init <- push-duplex 167/§, 0/tail
    top-of-screen:address:address:duplex-list <- get-address *current-sandbox, top-of-screen:offset
    *top-of-screen <- copy *init
  }
  # save all sandboxes before running, just in case we die when running
  save-sandboxes env
  # run all sandboxes
  curr:address:sandbox-data <- get *env, sandbox:offset
  {
    break-unless curr
    update-sandbox curr
    curr <- get *curr, next-sandbox:offset
    loop
  }
  reply 0/no-errors-found, env/same-as-ingredient:0, screen/same-as-ingredient:1
]

# copy code from recipe editor, persist, load into mu
# replaced in a later layer
recipe update-recipes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  screen:address <- next-ingredient
  recipes:address:editor-data <- get *env, recipes:offset
  in:address:array:character <- editor-contents recipes
  save [recipes.mu], in
  reload in
  reply 0/no-errors-found, env/same-as-ingredient:0, screen/same-as-ingredient:1
]

# replaced in a later layer
recipe update-sandbox [
  local-scope
  sandbox:address:sandbox-data <- next-ingredient
  data:address:array:character <- get *sandbox, data:offset
  response:address:address:array:character <- get-address *sandbox, response:offset
  fake-screen:address:address:screen <- get-address *sandbox, screen:offset
  *response, _, *fake-screen <- run-interactive data
]

recipe update-status [
  local-scope
  screen:address <- next-ingredient
  msg:address:array:character <- next-ingredient
  color:number <- next-ingredient
  screen <- move-cursor screen, 0, 2
  screen <- print-string screen, msg, color, 238/grey/background
  reply screen/same-as-ingredient:0
]

recipe save-sandboxes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  # first clear previous versions, in case we deleted some sandbox
  $system [rm lesson/[0-9]* >/dev/null 2>/dev/null]  # some shells can't handle '>&'
  curr:address:sandbox-data <- get *env, sandbox:offset
  suffix:address:array:character <- new [.out]
  idx:number <- copy 0
  {
    break-unless curr
    data:address:array:character <- get *curr, data:offset
    filename:address:array:character <- integer-to-decimal-string idx
    save filename, data
    {
      expected-response:address:array:character <- get *curr, expected-response:offset
      break-unless expected-response
      filename <- string-append filename, suffix
      save filename, expected-response
    }
    idx <- add idx, 1
    curr <- get *curr, next-sandbox:offset
    loop
  }
]

recipe! render-sandbox-side [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  trace 11, [app], [render sandbox side]
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  row:number, column:number, screen, current-sandbox <- render screen, current-sandbox
  clear-screen-from screen, row, column, left, right
  row <- add row, 1
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  sandbox:address:sandbox-data <- get *env, sandbox:offset
  row, screen <- render-sandboxes screen, sandbox, left, right, row
  clear-rest-of-screen screen, row, left, left, right
  reply screen/same-as-ingredient:0
]

recipe render-sandboxes [
  local-scope
  screen:address <- next-ingredient
  sandbox:address:sandbox-data <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  row:number <- next-ingredient
  reply-unless sandbox, row/same-as-ingredient:4, screen/same-as-ingredient:0
  screen-height:number <- screen-height screen
  at-bottom?:boolean <- greater-or-equal row, screen-height
  reply-if at-bottom?:boolean, row/same-as-ingredient:4, screen/same-as-ingredient:0
  # render sandbox menu
  row <- add row, 1
  screen <- move-cursor screen, row, left
  clear-line-delimited screen, left, right
  print-character screen, 120/x, 245/grey
  # save menu row so we can detect clicks to it later
  starting-row:address:number <- get-address *sandbox, starting-row-on-screen:offset
  *starting-row <- copy row
  # render sandbox contents
  row <- add row, 1
  screen <- move-cursor screen, row, left
  sandbox-data:address:array:character <- get *sandbox, data:offset
  row, screen <- render-code-string screen, sandbox-data, left, right, row
  code-ending-row:address:number <- get-address *sandbox, code-ending-row-on-screen:offset
  *code-ending-row <- copy row
  # render sandbox warnings, screen or response, in that order
  response-starting-row:address:number <- get-address *sandbox, response-starting-row-on-screen:offset
  sandbox-response:address:array:character <- get *sandbox, response:offset
  <render-sandbox-results>
  {
    sandbox-screen:address <- get *sandbox, screen:offset
    empty-screen?:boolean <- fake-screen-is-empty? sandbox-screen
    break-if empty-screen?
    row, screen <- render-screen screen, sandbox-screen, left, right, row
  }
  {
    break-unless empty-screen?
    *response-starting-row <- copy row
    <render-sandbox-response>
    row, screen <- render-string screen, sandbox-response, left, right, 245/grey, row
  }
  +render-sandbox-end
  at-bottom?:boolean <- greater-or-equal row, screen-height
  reply-if at-bottom?, row/same-as-ingredient:4, screen/same-as-ingredient:0
  # draw solid line after sandbox
  draw-horizontal screen, row, left, right, 9473/horizontal-double
  # draw next sandbox
  next-sandbox:address:sandbox-data <- get *sandbox, next-sandbox:offset
  row, screen <- render-sandboxes screen, next-sandbox, left, right, row
  reply row/same-as-ingredient:4, screen/same-as-ingredient:0
]

# assumes programming environment has no sandboxes; restores them from previous session
recipe restore-sandboxes [
  local-scope
  env:address:programming-environment-data <- next-ingredient
  # read all scenarios, pushing them to end of a list of scenarios
  suffix:address:array:character <- new [.out]
  idx:number <- copy 0
  curr:address:address:sandbox-data <- get-address *env, sandbox:offset
  {
    filename:address:array:character <- integer-to-decimal-string idx
    contents:address:array:character <- restore filename
    break-unless contents  # stop at first error; assuming file didn't exist
    # create new sandbox for file
    *curr <- new sandbox-data:type
    data:address:address:array:character <- get-address **curr, data:offset
    *data <- copy contents
    # restore expected output for sandbox if it exists
    {
      filename <- string-append filename, suffix
      contents <- restore filename
      break-unless contents
      expected-response:address:address:array:character <- get-address **curr, expected-response:offset
      *expected-response <- copy contents
    }
    +continue
    idx <- add idx, 1
    curr <- get-address **curr, next-sandbox:offset
    loop
  }
  reply env/same-as-ingredient:0
]

# row, screen <- render-screen screen:address, sandbox-screen:address, left:number, right:number, row:number
# print the fake sandbox screen to 'screen' with appropriate delimiters
# leave cursor at start of next line
recipe render-screen [
  local-scope
  screen:address <- next-ingredient
  s:address:screen <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  row:number <- next-ingredient
  reply-unless s, row/same-as-ingredient:4, screen/same-as-ingredient:0
  # print 'screen:'
  header:address:array:character <- new [screen:]
  row <- render-string screen, header, left, right, 245/grey, row
  screen <- move-cursor screen, row, left
  # start printing s
  column:number <- copy left
  s-width:number <- screen-width s
  s-height:number <- screen-height s
  buf:address:array:screen-cell <- get *s, data:offset
  stop-printing:number <- add left, s-width, 3
  max-column:number <- min stop-printing, right
  i:number <- copy 0
  len:number <- length *buf
  screen-height:number <- screen-height screen
  {
    done?:boolean <- greater-or-equal i, len
    break-if done?
    done? <- greater-or-equal row, screen-height
    break-if done?
    column <- copy left
    screen <- move-cursor screen, row, column
    # initial leader for each row: two spaces and a '.'
    print-character screen, 32/space, 245/grey
    print-character screen, 32/space, 245/grey
    print-character screen, 46/full-stop, 245/grey
    column <- add left, 3
    {
      # print row
      row-done?:boolean <- greater-or-equal column, max-column
      break-if row-done?
      curr:screen-cell <- index *buf, i
      c:character <- get curr, contents:offset
      color:number <- get curr, color:offset
      {
        # damp whites down to grey
        white?:boolean <- equal color, 7/white
        break-unless white?
        color <- copy 245/grey
      }
      print-character screen, c, color
      column <- add column, 1
      i <- add i, 1
      loop
    }
    # print final '.'
    print-character screen, 46/full-stop, 245/grey
    column <- add column, 1
    {
      # clear rest of current line
      line-done?:boolean <- greater-than column, right
      break-if line-done?
      print-character screen, 32/space
      column <- add column, 1
      loop
    }
    row <- add row, 1
    loop
  }
  reply row/same-as-ingredient:4, screen/same-as-ingredient:0
]

scenario run-updates-results [
  $close-trace  # trace too long
  assume-screen 100/width, 12/height
  # define a recipe (no indent for the 'add' line below so column numbers are more obvious)
  1:address:array:character <- new [ 
recipe foo [
z:number <- add 2, 2
]]
  # sandbox editor contains an instruction without storing outputs
  2:address:array:character <- new [foo]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editors
  assume-console [
    press F4
  ]
  event-loop screen:address, console:address, 3:address:programming-environment-data
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .z:number <- add 2, 2                              ┊                                                x.
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊4                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
  # make a change (incrementing one of the args to 'add'), then rerun
  assume-console [
    left-click 3, 28  # one past the value of the second arg
    press backspace
    type [3]
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that screen updates the result on the right
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .recipe foo [                                      ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .z:number <- add 2, 3                              ┊                                                x.
    .]                                                 ┊foo                                              .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊5                                                .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

scenario run-instruction-manages-screen-per-sandbox [
  $close-trace  # trace too long
  assume-screen 100/width, 20/height
  # left editor is empty
  1:address:array:character <- new []
  # right editor contains an instruction
  2:address:array:character <- new [print-integer screen:address, 4]
  3:address:programming-environment-data <- new-programming-environment screen:address, 1:address:array:character, 2:address:array:character
  # run the code in the editor
  assume-console [
    press F4
  ]
  run [
    event-loop screen:address, console:address, 3:address:programming-environment-data
  ]
  # check that it prints a little toy screen
  screen-should-contain [
    .                                                                                 run (F4)           .
    .                                                  ┊                                                 .
    .┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                x.
    .                                                  ┊print-integer screen:address, 4                  .
    .                                                  ┊screen:                                          .
    .                                                  ┊  .4                             .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊  .                              .               .
    .                                                  ┊━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━.
    .                                                  ┊                                                 .
  ]
]

recipe editor-contents [
  local-scope
  editor:address:editor-data <- next-ingredient
  buf:address:buffer <- new-buffer 80
  curr:address:duplex-list <- get *editor, data:offset
  # skip § sentinel
  assert curr, [editor without data is illegal; must have at least a sentinel]
  curr <- next-duplex curr
  reply-unless curr, 0
  {
    break-unless curr
    c:character <- get *curr, value:offset
    buffer-append buf, c
    curr <- next-duplex curr
    loop
  }
  result:address:array:character <- buffer-to-array buf
  reply result
]

scenario editor-provides-edited-contents [
  assume-screen 10/width, 5/height
  1:address:array:character <- new [abc]
  2:address:editor-data <- new-editor 1:address:array:character, screen:address, 0/left, 10/right
  assume-console [
    left-click 1, 2
    type [def]
  ]
  run [
    editor-event-loop screen:address, console:address, 2:address:editor-data
    3:address:array:character <- editor-contents 2:address:editor-data
    4:array:character <- copy *3:address:array:character
  ]
  memory-should-contain [
    4:string <- [abdefc]
  ]
]