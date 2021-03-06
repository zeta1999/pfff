open Common
open OUnit

(*****************************************************************************)
(* Unit tests *)
(*****************************************************************************)

let unittest =
  "naming generic" >::: [

    "regression files" >:: (fun () ->

      let dir = Filename.concat Config_pfff.path "/tests/python/naming" in
      let files1 = Common2.glob (spf "%s/*.py" dir) in
      let dir = Filename.concat Config_pfff.path "/tests/go/naming" in
      let files2 = Common2.glob (spf "%s/*.go" dir) in
      let dir = Filename.concat Config_pfff.path "/tests/js/naming" in
      let files3 = Common2.glob (spf "%s/*.js" dir) in
      let dir = Filename.concat Config_pfff.path "/tests/java/naming" in
      let files4 = Common2.glob (spf "%s/*.java" dir) in

      (files1 @ files2 @ files3 @ files4) |> List.iter (fun file ->
        try
        (* at least we can assert we don't thrown an exn or go 
         * into infinite loops *)
         let ast = Parse_generic.parse_program file in
         let lang = List.hd (Lang.langs_of_filename file) in
         Naming_AST.resolve lang ast;
         (* this used to loop forever if you were not handling correctly
          * possible cycles with id_type *)
         let _v = AST_generic.show_any (AST_generic.Pr ast) in
         ()
        with Parse_info.Parsing_error _ ->
          assert_failure (spf "it should correctly parse %s" file)
      )
    );
 
 ]
