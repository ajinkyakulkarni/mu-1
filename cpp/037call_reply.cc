//: Calls can also generate products, using 'reply'.

:(scenario reply)
recipe main [
  3:integer, 4:integer <- f 2:literal
]
recipe f [
  12:integer <- next-ingredient
  13:integer <- add 1:literal, 12:integer
  reply 12:integer, 13:integer
]
+run: instruction main/0
+run: result 0 is 2
+mem: storing 2 in location 3
+run: result 1 is 3
+mem: storing 3 in location 4

:(before "End Primitive Recipe Declarations")
REPLY,
:(before "End Primitive Recipe Numbers")
Recipe_number["reply"] = REPLY;
:(before "End Primitive Recipe Implementations")
case REPLY: {
  vector<vector<int> > callee_results;
  for (size_t i = 0; i < current_instruction().ingredients.size(); ++i) {
    callee_results.push_back(read_memory(current_instruction().ingredients[i]));
  }
  Current_routine->calls.pop();
  assert(!Current_routine->calls.empty());
  const instruction& caller_instruction = current_instruction();
  assert(caller_instruction.products.size() <= callee_results.size());
  for (size_t i = 0; i < caller_instruction.products.size(); ++i) {
    trace("run") << "result " << i << " is " << to_string(callee_results[i]);
    write_memory(caller_instruction.products[i], callee_results[i]);
  }
  break;  // instruction loop will increment caller's step_index
}

//: Products can include containers and exclusive containers, addresses and arrays.
:(scenario reply_container)
recipe main [
  3:point <- f 2:literal
]
recipe f [
  12:integer <- next-ingredient
  13:integer <- copy 35:literal
  reply 12:point
]
+run: instruction main/0
+run: result 0 is [2, 35]
+mem: storing 2 in location 3
+mem: storing 35 in location 4

:(code)
string to_string(const vector<int>& in) {
  if (in.empty()) return "[]";
  ostringstream out;
  if (in.size() == 1) {
    out << in[0];
    return out.str();
  }
  out << "[";
  for (size_t i = 0; i < in.size(); ++i) {
    if (i > 0) out << ", ";
    out << in[i];
  }
  out << "]";
  return out.str();
}