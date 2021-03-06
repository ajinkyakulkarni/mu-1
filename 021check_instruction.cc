//: Introduce a new transform to perform various checks in instructions before
//: we start running them. It'll be extensible, so that we can add checks for
//: new recipes as we extend 'run' to support them.
//:
//: Doing checking in a separate part complicates things, because the values
//: of variables in memory and the processor (current_recipe_name,
//: current_instruction) aren't available at checking time. If I had a more
//: sophisticated layer system I'd introduce the simpler version first and
//: transform it in a separate layer or set of layers.

:(before "End Checks")
Transform.push_back(check_instruction);  // idempotent

:(code)
void check_instruction(const recipe_ordinal r) {
  trace(9991, "transform") << "--- perform checks for recipe " << get(Recipe, r).name << end();
  map<string, vector<type_ordinal> > metadata;
  for (int i = 0;  i < SIZE(get(Recipe, r).steps);  ++i) {
    instruction& inst = get(Recipe, r).steps.at(i);
    if (inst.is_label) continue;
    switch (inst.operation) {
      // Primitive Recipe Checks
      case COPY: {
        if (SIZE(inst.products) != SIZE(inst.ingredients)) {
          raise << maybe(get(Recipe, r).name) << "ingredients and products should match in '" << inst.original_string << "'\n" << end();
          break;
        }
        for (int i = 0;  i < SIZE(inst.ingredients);  ++i) {
          if (!types_coercible(inst.products.at(i), inst.ingredients.at(i))) {
            raise << maybe(get(Recipe, r).name) << "can't copy '" << inst.ingredients.at(i).original_string << "' to '" << inst.products.at(i).original_string << "'; types don't match\n" << end();
            goto finish_checking_instruction;
          }
        }
        break;
      }
      // End Primitive Recipe Checks
      default: {
        // Defined Recipe Checks
        // End Defined Recipe Checks
      }
    }
    finish_checking_instruction:;
  }
}

:(scenario copy_checks_reagent_count)
% Hide_errors = true;
def main [
  1:num <- copy 34, 35
]
+error: main: ingredients and products should match in '1:num <- copy 34, 35'

:(scenario write_scalar_to_array_disallowed)
% Hide_errors = true;
def main [
  1:array:num <- copy 34
]
+error: main: can't copy '34' to '1:array:num'; types don't match

:(scenario write_scalar_to_array_disallowed_2)
% Hide_errors = true;
def main [
  1:num, 2:array:num <- copy 34, 35
]
+error: main: can't copy '35' to '2:array:num'; types don't match

:(scenario write_scalar_to_address_disallowed)
% Hide_errors = true;
def main [
  1:address:num <- copy 34
]
+error: main: can't copy '34' to '1:address:num'; types don't match

:(scenario write_address_to_number_allowed)
def main [
  1:address:num <- copy 12/unsafe
  2:num <- copy 1:address:num
]
+mem: storing 12 in location 2
$error: 0

:(scenario write_boolean_to_number_allowed)
def main [
  1:bool <- copy 1/true
  2:num <- copy 1:bool
]
+mem: storing 1 in location 2
$error: 0

:(scenario write_number_to_boolean_allowed)
def main [
  1:num <- copy 34
  2:bool <- copy 1:num
]
+mem: storing 34 in location 2
$error: 0

:(code)
// types_match with some leniency
bool types_coercible(const reagent& to, const reagent& from) {
  if (types_match(to, from)) return true;
  if (is_mu_address(from) && is_mu_number(to)) return true;
  if (is_mu_boolean(from) && is_mu_number(to)) return true;
  if (is_mu_number(from) && is_mu_boolean(to)) return true;
  // End types_coercible Special-cases
  return false;
}

bool types_match(const reagent& to, const reagent& from) {
  // to sidestep type-checking, use /unsafe in the source.
  // this will be highlighted in red inside vim. just for setting up some tests.
  if (is_unsafe(from)) return true;
  if (is_literal(from)) {
    if (is_mu_array(to)) return false;
    // End Matching Types For Literal(to)
    // allow writing 0 to any address
    if (is_mu_address(to)) return from.name == "0";
    if (!to.type) return false;
    if (to.type->atom && to.type->value == get(Type_ordinal, "boolean"))
      return from.name == "0" || from.name == "1";
    return size_of(to) == 1;  // literals are always scalars
  }
  return types_strictly_match(to, from);
}

// copy arguments because later layers will want to make changes to them
// without perturbing the caller
bool types_strictly_match(reagent/*copy*/ to, reagent/*copy*/ from) {
  // End Preprocess types_strictly_match(reagent to, reagent from)
  if (is_literal(from) && to.type->value == get(Type_ordinal, "number")) return true;
  // to sidestep type-checking, use /unsafe in the source.
  // this will be highlighted in red inside vim. just for setting up some tests.
  if (is_unsafe(from)) return true;
  // '_' never raises type error
  if (is_dummy(to)) return true;
  if (!to.type) return !from.type;
  return types_strictly_match(to.type, from.type);
}

bool types_strictly_match(const type_tree* to, const type_tree* from) {
  if (from == to) return true;
  if (!to) return false;
  if (!from) return to->atom && to->value == 0;
  if (from->atom != to->atom) return false;
  if (from->atom) {
    if (from->value == -1) return from->name == to->name;
    return from->value == to->value;
  }
  return types_strictly_match(to->left, from->left) && types_strictly_match(to->right, from->right);
}

void test_unknown_type_does_not_match_unknown_type() {
  reagent a("a:foo");
  reagent b("b:bar");
  CHECK(!types_strictly_match(a, b));
}

void test_unknown_type_matches_itself() {
  reagent a("a:foo");
  reagent b("b:foo");
  CHECK(types_strictly_match(a, b));
}

//: helpers

bool is_unsafe(const reagent& r) {
  return has_property(r, "unsafe");
}

bool is_mu_array(reagent/*copy*/ r) {
  // End Preprocess is_mu_array(reagent r)
  return is_mu_array(r.type);
}
bool is_mu_array(const type_tree* type) {
  if (!type) return false;
  if (is_literal(type)) return false;
  if (type->atom) return false;
  if (!type->left->atom) {
    raise << "invalid type " << to_string(type) << '\n' << end();
    return false;
  }
  return type->left->value == get(Type_ordinal, "array");
}

bool is_mu_address(reagent/*copy*/ r) {
  // End Preprocess is_mu_address(reagent r)
  return is_mu_address(r.type);
}
bool is_mu_address(const type_tree* type) {
  if (!type) return false;
  if (is_literal(type)) return false;
  if (type->atom) return false;
  if (!type->left->atom) {
    raise << "invalid type " << to_string(type) << '\n' << end();
    return false;
  }
  return type->left->value == get(Type_ordinal, "address");
}

bool is_mu_boolean(reagent/*copy*/ r) {
  // End Preprocess is_mu_boolean(reagent r)
  if (!r.type) return false;
  if (is_literal(r)) return false;
  if (!r.type->atom) return false;
  return r.type->value == get(Type_ordinal, "boolean");
}

bool is_mu_number(reagent/*copy*/ r) {
  // End Preprocess is_mu_number(reagent r)
  if (!r.type) return false;
  if (!r.type->atom) return false;
  if (is_literal(r)) {
    return r.type->name == "literal-fractional-number"
        || r.type->name == "literal";
  }
  if (r.type->value == get(Type_ordinal, "character")) return true;  // permit arithmetic on unicode code points
  return r.type->value == get(Type_ordinal, "number");
}

bool is_mu_character(reagent/*copy*/ r) {
  // End Preprocess is_mu_character(reagent r)
  return is_mu_character(r.type);
}
bool is_mu_character(const type_tree* type) {
  if (!type) return false;
  if (!type->atom) return false;
  if (is_literal(type)) return false;
  return type->value == get(Type_ordinal, "character");
}

bool is_mu_scalar(reagent/*copy*/ r) {
  return is_mu_scalar(r.type);
}
bool is_mu_scalar(const type_tree* type) {
  if (!type) return false;
  if (is_mu_address(type)) return true;
  if (!type->atom) return false;
  if (is_literal(type))
    return type->name != "literal-string";
  return size_of(type) == 1;
}
