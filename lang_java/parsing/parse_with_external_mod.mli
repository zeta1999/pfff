(* entry point, call internally another program that parses the file
 * and return a JSON of its AST that we then convert into our own AST
 * of ast_java.ml
 *)
val parse: Common.filename -> Tree_sitter_ast_java.program

(* internals *)
val json_of_filename_with_external_prog: Common.filename -> Json_type.t

val program_of_tree_sitter_json: 
  Common.filename -> Json_type.t -> Tree_sitter_ast_java.program

val program_of_babelfish_json: 
  Common.filename -> Json_type.t -> Tree_sitter_ast_java.program
