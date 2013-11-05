open Common

let main () =
  let file = Sys.argv.(1) in
  let ((ast, _toks), _) = Parse_js.parse file in
  let v = Meta_ast_js.vof_program ast in
  let s = Ocaml.string_of_v v in
  pr s;
  ()

let _ = main ()
