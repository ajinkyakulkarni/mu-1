## putting the environment together out of editors

recipe! main [
  local-scope
  open-console
  initial-sandbox:address:array:character <- new []
  hide-screen 0/screen
  env:address:programming-environment-data <- new-programming-environment 0/screen, initial-sandbox
  env <- restore-sandboxes env
  render-sandbox-side 0/screen, env
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  update-cursor 0/screen, current-sandbox
  show-screen 0/screen
  event-loop 0/screen, 0/console, env
  # never gets here
]

container programming-environment-data [
  current-sandbox:address:editor-data
]

recipe new-programming-environment [
  local-scope
  screen:address <- next-ingredient
  initial-sandbox-contents:address:array:character <- next-ingredient
  width:number <- screen-width screen
  height:number <- screen-height screen
  # top menu
  result:address:programming-environment-data <- new programming-environment-data:type
  draw-horizontal screen, 0, 0/left, width, 32/space, 0/black, 238/grey
  button-start:number <- subtract width, 20
  button-on-screen?:boolean <- greater-or-equal button-start, 0
  assert button-on-screen?, [screen too narrow for menu]
  screen <- move-cursor screen, 0/row, button-start
  run-button:address:array:character <- new [ run (F4) ]
  print-string screen, run-button, 255/white, 161/reddish
  # sandbox editor
  current-sandbox:address:address:editor-data <- get-address *result, current-sandbox:offset
  *current-sandbox <- new-editor initial-sandbox-contents, screen, 0, width/right
  +programming-environment-initialization
  reply result
]

recipe event-loop [
  local-scope
  screen:address <- next-ingredient
  console:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  # if we fall behind we'll stop updating the screen, but then we have to
  # render the entire screen when we catch up.
  # todo: test this
  render-all-on-no-more-events?:boolean <- copy 0/false
  {
    # looping over each (keyboard or touch) event as it occurs
    +next-event
    e:event, console, found?:boolean, quit?:boolean <- read-event console
    loop-unless found?
    break-if quit?  # only in tests
    trace 10, [app], [next-event]
    <handle-event>
    # check for global events that will trigger regardless of which editor has focus
    {
      k:address:number <- maybe-convert e:event, keycode:variant
      break-unless k
      <global-keypress>
    }
    {
      c:address:character <- maybe-convert e:event, text:variant
      break-unless c
      <global-type>
    }
    # 'touch' event
    {
      t:address:touch-event <- maybe-convert e:event, touch:variant
      break-unless t
      # ignore all but 'left-click' events for now
      # todo: test this
      touch-type:number <- get *t, type:offset
      is-left-click?:boolean <- equal touch-type, 65513/mouse-left
      loop-unless is-left-click?, +next-event:label
      # later exceptions for non-editor touches will go here
      <global-touch>
      move-cursor-in-editor screen, current-sandbox, *t
      screen <- update-cursor screen, current-sandbox
      loop +next-event:label
    }
    # 'resize' event - redraw editor
    # todo: test this after supporting resize in assume-console
    {
      r:address:resize-event <- maybe-convert e:event, resize:variant
      break-unless r
      # if more events, we're still resizing; wait until we stop
      more-events?:boolean <- has-more-events? console
      {
        break-unless more-events?
        render-all-on-no-more-events? <- copy 1/true  # no rendering now, full rendering on some future event
      }
      {
        break-if more-events?
        env <- resize screen, env
        screen <- render-all screen, env
        render-all-on-no-more-events? <- copy 0/false  # full render done
      }
      loop +next-event:label
    }
    # if it's not global and not a touch event, send to appropriate editor
    {
      hide-screen screen
      screen, current-sandbox, render?:boolean <- handle-keyboard-event screen, current-sandbox, e:event
      # refresh screen only if no more events
      # if there are more events to process, wait for them to clear up, then make sure you render-all afterward.
      more-events?:boolean <- has-more-events? console
      {
        break-unless more-events?
        render-all-on-no-more-events? <- copy 1/true  # no rendering now, full rendering on some future event
        jump +finish-event:label
      }
      {
        break-if more-events?
        {
          break-unless render-all-on-no-more-events?
          # no more events, and we have to force render
          screen <- render-all screen, env
          render-all-on-no-more-events? <- copy 0/false
          jump +finish-event:label
        }
        # no more events, no force render
        {
          break-unless render?
          screen <- render-sandbox-side screen, env
          jump +finish-event:label
        }
      }
      +finish-event
      screen <- update-cursor screen, current-sandbox
      show-screen screen
    }
    loop
  }
]

recipe resize [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  clear-screen screen  # update screen dimensions
  width:number <- screen-width screen
  # update sandbox editor
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  right:address:number <- get-address *current-sandbox, right:offset
  *right <- subtract width, 1
  # reset cursor
  cursor-row:address:number <- get-address *current-sandbox, cursor-row:offset
  *cursor-row <- copy 1
  cursor-column:address:number <- get-address *current-sandbox, cursor-column:offset
  *cursor-column <- copy 0
  reply env/same-as-ingredient:1
]

recipe render-all [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  trace 10, [app], [render all]
  hide-screen screen
  # top menu
  trace 11, [app], [render top menu]
  width:number <- screen-width screen
  draw-horizontal screen, 0, 0/left, width, 32/space, 0/black, 238/grey
  button-start:number <- subtract width, 20
  button-on-screen?:boolean <- greater-or-equal button-start, 0
  assert button-on-screen?, [screen too narrow for menu]
  screen <- move-cursor screen, 0/row, button-start
  run-button:address:array:character <- new [ run (F4) ]
  print-string screen, run-button, 255/white, 161/reddish
  #
  screen <- render-sandbox-side screen, env
  <render-components-end>
  #
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  screen <- update-cursor screen, current-sandbox
  #
  show-screen screen
  reply screen/same-as-ingredient:0
]

# replaced in a later layer
recipe render-sandbox-side [
  local-scope
  screen:address <- next-ingredient
  env:address:programming-environment-data <- next-ingredient
  current-sandbox:address:editor-data <- get *env, current-sandbox:offset
  left:number <- get *current-sandbox, left:offset
  right:number <- get *current-sandbox, right:offset
  row:number, column:number, screen, current-sandbox <- render screen, current-sandbox
  clear-line-delimited screen, column, right
  row <- add row, 1
  # draw solid line after code
  draw-horizontal screen, row, left, right, 9473/horizontal
  row <- add row, 1
  clear-screen-from screen, row, left, left, right
  reply screen/same-as-ingredient:0
]

recipe update-cursor [
  local-scope
  screen:address <- next-ingredient
  current-sandbox:address:editor-data <- next-ingredient
  cursor-row:number <- get *current-sandbox, cursor-row:offset
  cursor-column:number <- get *current-sandbox, cursor-column:offset
  screen <- move-cursor screen, cursor-row, cursor-column
  reply screen/same-as-ingredient:0
]

# row, screen <- render-string screen:address, s:address:array:character, left:number, right:number, color:number, row:number
# print a string 's' to 'editor' in 'color' starting at 'row'
# clear rest of last line, move cursor to next line
recipe render-string [
  local-scope
  screen:address <- next-ingredient
  s:address:array:character <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  color:number <- next-ingredient
  row:number <- next-ingredient
  reply-unless s, row/same-as-ingredient:5, screen/same-as-ingredient:0
  column:number <- copy left
  screen <- move-cursor screen, row, column
  screen-height:number <- screen-height screen
  i:number <- copy 0
  len:number <- length *s
  {
    +next-character
    done?:boolean <- greater-or-equal i, len
    break-if done?
    done? <- greater-or-equal row, screen-height
    break-if done?
    c:character <- index *s, i
    {
      # at right? wrap.
      at-right?:boolean <- equal column, right
      break-unless at-right?
      # print wrap icon
      print-character screen, 8617/loop-back-to-left, 245/grey
      column <- copy left
      row <- add row, 1
      screen <- move-cursor screen, row, column
      loop +next-character:label  # retry i
    }
    i <- add i, 1
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      # clear rest of line in this window
      {
        done?:boolean <- greater-than column, right
        break-if done?
        print-character screen, 32/space
        column <- add column, 1
        loop
      }
      row <- add row, 1
      column <- copy left
      screen <- move-cursor screen, row, column
      loop +next-character:label
    }
    print-character screen, c, color
    column <- add column, 1
    loop
  }
  was-at-left?:boolean <- equal column, left
  clear-line-delimited screen, column, right
  {
    break-if was-at-left?
    row <- add row, 1
  }
  move-cursor row, left
  reply row/same-as-ingredient:5, screen/same-as-ingredient:0
]

# row, screen <- render-code-string screen:address, s:address:array:character, left:number, right:number, row:number
# like 'render-string' but with colorization for comments like in the editor
recipe render-code-string [
  local-scope
  screen:address <- next-ingredient
  s:address:array:character <- next-ingredient
  left:number <- next-ingredient
  right:number <- next-ingredient
  row:number <- next-ingredient
  reply-unless s, row/same-as-ingredient:4, screen/same-as-ingredient:0
  color:number <- copy 7/white
  column:number <- copy left
  screen <- move-cursor screen, row, column
  screen-height:number <- screen-height screen
  i:number <- copy 0
  len:number <- length *s
  {
    +next-character
    done?:boolean <- greater-or-equal i, len
    break-if done?
    done? <- greater-or-equal row, screen-height
    break-if done?
    c:character <- index *s, i
    <character-c-received>  # only line different from render-string
    {
      # at right? wrap.
      at-right?:boolean <- equal column, right
      break-unless at-right?
      # print wrap icon
      print-character screen, 8617/loop-back-to-left, 245/grey
      column <- copy left
      row <- add row, 1
      screen <- move-cursor screen, row, column
      loop +next-character:label  # retry i
    }
    i <- add i, 1
    {
      # newline? move to left rather than 0
      newline?:boolean <- equal c, 10/newline
      break-unless newline?
      # clear rest of line in this window
      {
        done?:boolean <- greater-than column, right
        break-if done?
        print-character screen, 32/space
        column <- add column, 1
        loop
      }
      row <- add row, 1
      column <- copy left
      screen <- move-cursor screen, row, column
      loop +next-character:label
    }
    print-character screen, c, color
    column <- add column, 1
    loop
  }
  was-at-left?:boolean <- equal column, left
  clear-line-delimited screen, column, right
  {
    break-if was-at-left?
    row <- add row, 1
  }
  move-cursor row, left
  reply row/same-as-ingredient:4, screen/same-as-ingredient:0
]

# ctrl-l - redraw screen (just in case it printed junk somehow)

after <global-type> [
  {
    redraw-screen?:boolean <- equal *c, 12/ctrl-l
    break-unless redraw-screen?
    screen <- render-all screen, env:address:programming-environment-data
    sync-screen screen
    loop +next-event:label
  }
]