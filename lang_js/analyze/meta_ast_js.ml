
(* generated by ocamltarzan with: camlp4o -o /tmp/yyy.ml -I pa/ pa_type_conv.cmo pa_vof.cmo  pr_o.cmo /tmp/xxx.ml  *)

open Ast_js

let rec vof_tok v = Meta_parse_info.vof_info_adjustable_precision v

and vof_wrap of_a (v1, v2) =
  let v1 = of_a v1 
  and v2 = vof_tok v2 in 
  OCaml.VTuple [ v1; v2 ]

let vof_bracket of_a (_t1, x, _t2) =
  of_a x
  
let vof_name v = vof_wrap OCaml.vof_string v
let vof_ident x = vof_name x

let vof_resolved_name = function
  | Local -> OCaml.VSum (("Local", []))
  | Param -> OCaml.VSum (("Param", []))
  | NotResolved -> OCaml.VSum (("NotResolved", []))
  | Global v1 -> 
      let v1 = OCaml.vof_string v1 in
      OCaml.VSum (("Global", [ v1 ]))
  
let vof_special =
  function
  | UseStrict -> OCaml.VSum (("UseStrict", []))
  | Null -> OCaml.VSum (("Null", []))
  | Undefined -> OCaml.VSum (("Undefined", []))
  | This -> OCaml.VSum (("This", []))
  | Super -> OCaml.VSum (("Super", []))
  | Require -> OCaml.VSum (("Require", []))
  | Exports -> OCaml.VSum (("Exports", []))
  | Module -> OCaml.VSum (("Module", []))
  | Define -> OCaml.VSum (("Define", []))
  | Arguments -> OCaml.VSum (("Arguments", []))
  | New -> OCaml.VSum (("New", []))
  | NewTarget -> OCaml.VSum (("NewTarget", []))
  | Eval -> OCaml.VSum (("Eval", []))
  | Seq -> OCaml.VSum (("Seq", []))
  | Typeof -> OCaml.VSum (("Typeof", []))
  | Instanceof -> OCaml.VSum (("Instanceof", []))
  | In -> OCaml.VSum (("In", []))
  | Delete -> OCaml.VSum (("Delete", []))
  | Void -> OCaml.VSum (("Void", []))
  | Spread -> OCaml.VSum (("Spread", []))
  | Yield -> OCaml.VSum (("Yield", []))
  | YieldStar -> OCaml.VSum (("YieldStar", []))
  | Await -> OCaml.VSum (("Await", []))
  | Encaps v1 -> let v1 = OCaml.vof_bool v1 in OCaml.VSum (("Await", [v1]))
  | ArithOp x -> Meta_ast_generic_common.vof_arithmetic_operator x
  | IncrDecr v1 -> let v1 = Meta_ast_generic_common.vof_inc_dec v1 in 
      OCaml.VSum (("IncrDecr", [ v1 ]))
  
let vof_label v = vof_wrap OCaml.vof_string v
  
let vof_filename v = vof_wrap OCaml.vof_string v
  
let rec vof_property_name =
  function
  | PN v1 -> let v1 = vof_name v1 in OCaml.VSum (("PN", [ v1 ]))
  | PN_Computed v1 ->
      let v1 = vof_expr v1 in OCaml.VSum (("PN_Computed", [ v1 ]))


and
  vof_xml {
            xml_tag = v_xml_tag;
            xml_attrs = v_xml_attrs;
            xml_body = v_xml_body
          } =
  let bnds = [] in
  let arg = OCaml.vof_list vof_xml_body v_xml_body in
  let bnd = ("xml_body", arg) in
  let bnds = bnd :: bnds in
  let arg =
    OCaml.vof_list
      (fun (v1, v2) ->
         let v1 = vof_ident v1
         and v2 = vof_xml_attr v2
         in OCaml.VTuple [ v1; v2 ])
      v_xml_attrs in
  let bnd = ("xml_attrs", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_ident v_xml_tag in
  let bnd = ("xml_tag", arg) in let bnds = bnd :: bnds in 
  OCaml.VDict bnds

and vof_xml_attr v = vof_expr v

and vof_xml_body =
  function
  | XmlText v1 ->
      let v1 = vof_wrap OCaml.vof_string v1
      in OCaml.VSum (("XmlText", [ v1 ]))
  | XmlExpr v1 -> let v1 = vof_expr v1 in OCaml.VSum (("XmlExpr", [ v1 ]))
  | XmlXml v1 -> let v1 = vof_xml v1 in OCaml.VSum (("XmlXml", [ v1 ]))

and vof_expr =
  function
  | Xml v1 -> let v1 = vof_xml v1 in OCaml.VSum (("Xml", [ v1 ]))
  | Arr v1 ->
     let v1 = vof_bracket (OCaml.vof_list vof_expr) v1 in OCaml.VSum (("Arr", [v1]))
  | Bool v1 ->
      let v1 = vof_wrap OCaml.vof_bool v1 in OCaml.VSum (("Bool", [ v1 ]))
  | Num v1 ->
      let v1 = vof_wrap OCaml.vof_string v1 in OCaml.VSum (("Num", [ v1 ]))
  | String v1 ->
      let v1 = vof_wrap OCaml.vof_string v1
      in OCaml.VSum (("String", [ v1 ]))
  | Regexp v1 ->
      let v1 = vof_wrap OCaml.vof_string v1
      in OCaml.VSum (("Regexp", [ v1 ]))
  | Id (v1, v2) -> 
      let v1 = vof_name v1 in 
      let v2 = OCaml.vof_ref vof_resolved_name v2 in
      OCaml.VSum (("Id", [ v1; v2 ]))
  | IdSpecial v1 ->
      let v1 = vof_wrap vof_special v1 in OCaml.VSum (("IdSpecial", [ v1 ]))
  | Assign ((v1, v2, v3)) ->
      let v1 = vof_expr v1
      and v2 = vof_tok v2
      and v3 = vof_expr v3 
      in OCaml.VSum (("Assign", [ v1; v2; v3 ]))
  | ArrAccess ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = vof_expr v2
      in OCaml.VSum (("ArrAccess", [ v1; v2 ]))
  | Obj v1 -> let v1 = vof_obj_ v1 in OCaml.VSum (("Obj", [ v1 ]))
  | Ellipsis v1 -> let v1 = vof_tok v1 in OCaml.VSum (("Ellipsis", [ v1 ]))
  | DeepEllipsis v1 -> let v1 = vof_bracket vof_expr v1 in 
      OCaml.VSum (("DeepEllipsis", [ v1 ]))
  | Class (v1, v2) -> 
     let v1 = vof_class_ v1 in 
     let v2 = OCaml.vof_option vof_name v2 in
     OCaml.VSum (("Class", [ v1; v2 ]))
  | ObjAccess ((v1, t, v2)) ->
      let v1 = vof_expr v1
      and v2 = vof_property_name v2
      and t = vof_tok t
      in OCaml.VSum (("ObjAccess", [ v1; t; v2 ]))
  | Fun ((v1, v2)) ->
      let v1 = vof_fun_ v1
      and v2 = OCaml.vof_option vof_name v2
      in OCaml.VSum (("Fun", [ v1; v2 ]))
  | Apply ((v1, v2)) ->
      let v1 = vof_expr v1
      and v2 = OCaml.vof_list vof_expr v2
      in OCaml.VSum (("Apply", [ v1; v2 ]))
  | Conditional ((v1, v2, v3)) ->
      let v1 = vof_expr v1
      and v2 = vof_expr v2
      and v3 = vof_expr v3
      in OCaml.VSum (("Conditional", [ v1; v2; v3 ]))
and vof_stmt =
  function
  | VarDecl v1 -> let v1 = vof_var v1 in OCaml.VSum (("VarDecl", [ v1 ]))
  | Block v1 ->
      let v1 = OCaml.vof_list vof_stmt v1 in OCaml.VSum (("Block", [ v1 ]))
  | ExprStmt v1 -> let v1 = vof_expr v1 in OCaml.VSum (("ExprStmt", [ v1 ]))
  | If ((t, v1, v2, v3)) ->
      let t = vof_tok t in
      let v1 = vof_expr v1
      and v2 = vof_stmt v2
      and v3 = vof_stmt v3
      in OCaml.VSum (("If", [ t; v1; v2; v3 ]))
  | Do ((t, v1, v2)) ->
      let t = vof_tok t in
      let v1 = vof_stmt v1
      and v2 = vof_expr v2
      in OCaml.VSum (("Do", [ t; v1; v2 ]))
  | While ((t, v1, v2)) ->
      let t = vof_tok t in
      let v1 = vof_expr v1
      and v2 = vof_stmt v2
      in OCaml.VSum (("While", [ t; v1; v2 ]))
  | For ((t, v1, v2)) ->
      let t = vof_tok t in
      let v1 = vof_for_header v1
      and v2 = vof_stmt v2
      in OCaml.VSum (("For", [ t; v1; v2 ]))
  | Switch ((v0, v1, v2)) ->
      let v0 = vof_tok v0 in
      let v1 = vof_expr v1
      and v2 = OCaml.vof_list vof_case v2
      in OCaml.VSum (("Switch", [ v0; v1; v2 ]))
  | Continue (t, v1) ->
      let t = vof_tok t in
      let v1 = OCaml.vof_option vof_label v1
      in OCaml.VSum (("Continue", [ t; v1 ]))
  | Break (t, v1) ->
      let t = vof_tok t in
      let v1 = OCaml.vof_option vof_label v1
      in OCaml.VSum (("Break", [ t; v1 ]))
  | Return (t, v1) -> 
      let t = vof_tok t in
      let v1 = OCaml.vof_option vof_expr v1 in 
      OCaml.VSum (("Return", [ t; v1 ]))
  | Label ((v1, v2)) ->
      let v1 = vof_label v1
      and v2 = vof_stmt v2
      in OCaml.VSum (("Label", [ v1; v2 ]))
  | Throw (t, v1) -> 
      let t = vof_tok t in
      let v1 = vof_expr v1 in OCaml.VSum (("Throw", [ t; v1 ]))
  | Try ((t, v1, v2, v3)) ->
      let t = vof_tok t in
      let v1 = vof_stmt v1
      and v2 =
        OCaml.vof_option
          (fun (t, v1, v2) ->
             let t = vof_tok t in
             let v1 = vof_wrap OCaml.vof_string v1
             and v2 = vof_stmt v2
             in OCaml.VTuple [ t; v1; v2 ])
          v2
      and v3 = OCaml.vof_option vof_tok_and_stmt v3
      in OCaml.VSum (("Try", [ t; v1; v2; v3 ]))
and vof_tok_and_stmt (t, v) = 
  let t = vof_tok t in
  let v = vof_stmt v in
  OCaml.VTuple [t; v]
and vof_for_header =
  function
  | ForClassic ((v1, v2, v3)) ->
      let v1 = OCaml.vof_either (OCaml.vof_list vof_var) vof_expr v1
      and v2 = OCaml.vof_option vof_expr v2
      and v3 = OCaml.vof_option vof_expr v3
      in OCaml.VSum (("ForClassic", [ v1; v2; v3 ]))
  | ForIn ((v1, t, v2)) ->
      let t = vof_tok t in
      let v1 = OCaml.vof_either vof_var vof_expr v1
      and v2 = vof_expr v2
      in OCaml.VSum (("ForIn", [ v1; t; v2 ]))
and vof_case =
  function
  | Case ((t, v1, v2)) ->
      let t = vof_tok t in
      let v1 = vof_expr v1
      and v2 = vof_stmt v2
      in OCaml.VSum (("Case", [ t; v1; v2 ]))
  | Default (t, v1) -> 
      let t = vof_tok t in
      let v1 = vof_stmt v1 in OCaml.VSum (("Default", [ t; v1 ]))
and vof_var { v_name = v_v_name; 
              v_kind = v_v_kind; 
              v_init = v_v_init;
              v_resolved = v_v_resolved;
             } =
  let bnds = [] in
  let arg = OCaml.vof_ref vof_resolved_name v_v_resolved in
  let bnd = ("v_resolved", arg) in
  let bnds = bnd :: bnds in
  let arg = OCaml.vof_option vof_expr v_v_init in
  let bnd = ("v_init", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_wrap vof_var_kind v_v_kind in
  let bnd = ("v_kind", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_name v_v_name in
  let bnd = ("v_name", arg) in let bnds = bnd :: bnds in OCaml.VDict bnds
and vof_var_kind =
  function
  | Var -> OCaml.VSum (("Var", []))
  | Let -> OCaml.VSum (("Let", []))
  | Const -> OCaml.VSum (("Const", []))
and
  vof_fun_ { f_props = v_f_props; f_params = v_f_params; f_body = v_f_body }
           =
  let bnds = [] in
  let arg = vof_stmt v_f_body in
  let bnd = ("f_body", arg) in
  let bnds = bnd :: bnds in
  let arg = OCaml.vof_list vof_parameter_binding v_f_params in
  let bnd = ("f_params", arg) in
  let bnds = bnd :: bnds in
  let arg = OCaml.vof_list (vof_wrap vof_fun_prop) v_f_props in
  let bnd = ("f_props", arg) in let bnds = bnd :: bnds in OCaml.VDict bnds


and vof_parameter_binding =
  function
  | ParamClassic v1 ->
      let v1 = vof_parameter v1 in OCaml.VSum (("ParamClassic", [ v1 ]))
  | ParamEllipsis v1 ->
      let v1 = vof_tok v1 in OCaml.VSum (("ParamEllipsis", [ v1 ]))

and  vof_parameter {
                  p_name = v_p_name;
                  p_default = v_p_default;
                  p_dots = v_p_dots
                } =
  let bnds = [] in
  let arg = OCaml.vof_option vof_tok v_p_dots in
  let bnd = ("p_dots", arg) in
  let bnds = bnd :: bnds in
  let arg = OCaml.vof_option vof_expr v_p_default in
  let bnd = ("p_default", arg) in
  let bnds = bnd :: bnds in
  let arg = vof_name v_p_name in
  let bnd = ("p_name", arg) in let bnds = bnd :: bnds in OCaml.VDict bnds
and vof_fun_prop =
  function
  | Get -> OCaml.VSum (("Get", []))
  | Set -> OCaml.VSum (("Set", []))
  | Generator -> OCaml.VSum (("Generator", []))
  | Async -> OCaml.VSum (("Async", []))
and vof_obj_ v = vof_bracket (OCaml.vof_list vof_property) v
and vof_class_ { c_extends = v_c_extends; c_body = v_c_body } =
  let bnds = [] in
  let arg = vof_bracket (OCaml.vof_list vof_property) v_c_body in
  let bnd = ("c_body", arg) in
  let bnds = bnd :: bnds in
  let arg = OCaml.vof_option vof_expr v_c_extends in
  let bnd = ("c_extends", arg) in let bnds = bnd :: bnds in OCaml.VDict bnds
and vof_property =
  function
  | Field ((v1, v2, v3)) ->
      let v1 = vof_property_name v1
      and v2 = OCaml.vof_list (vof_wrap vof_property_prop) v2
      and v3 = OCaml.vof_option vof_expr v3
      in OCaml.VSum (("Field", [ v1; v2; v3 ]))
  | FieldSpread (t, v1) ->
      let t = vof_tok t in
      let v1 = vof_expr v1 in OCaml.VSum (("FieldSpread", [ t; v1 ]))
  | FieldEllipsis v1 ->
      let v1 = vof_tok v1 in OCaml.VSum (("FieldEllipsis", [ v1 ]))
and vof_property_prop =
  function
  | Static -> OCaml.VSum (("Static", []))
  | Public -> OCaml.VSum (("Public", []))
  | Private -> OCaml.VSum (("Private", []))
  | Protected -> OCaml.VSum (("Protected", []))

let vof_module_directive =
  function
  | Import ((t, v1, v2, v3)) ->
      let t =  vof_tok t in
      let v1 = vof_name v1
      and v2 = OCaml.vof_option vof_name v2
      and v3 = vof_filename v3
      in OCaml.VSum (("Import", [ t; v1; v2; v3 ]))
  | ModuleAlias ((t, v1, v2)) ->
      let t =  vof_tok t in
      let v1 = vof_name v1
      and v2 = vof_filename v2
      in OCaml.VSum (("ModuleAlias", [ t; v1; v2 ]))
  | ImportCss ((v1)) ->
      let v1 = vof_filename v1
      in OCaml.VSum (("ImportCss", [ v1 ]))
  | ImportEffect ((v0, v1)) ->
      let v0 = vof_tok v0 in
      let v1 = vof_filename v1
      in OCaml.VSum (("ImportEffect", [ v0; v1 ]))
  | Export ((v1)) ->
      let v1 = vof_name v1
      in OCaml.VSum (("Export", [ v1 ]))
  
let vof_toplevel =
  function
  | S (v1, v2) -> 
     let v1 = vof_tok v1 in let v2 = vof_stmt v2 in
     OCaml.VSum (("S", [ v1; v2 ]))
  | V v1 ->
     let v1 = vof_var v1 in
     OCaml.VSum (("V", [v1]))
  | M v1 ->
     let v1 = vof_module_directive v1 in
     OCaml.VSum (("V", [v1]))

  
let vof_program v = OCaml.vof_list vof_toplevel v
  
let vof_any =
  function
  | Expr v1 -> let v1 = vof_expr v1 in OCaml.VSum (("Expr", [ v1 ]))
  | Item v1 -> let v1 = vof_toplevel v1 in OCaml.VSum (("Item", [ v1 ]))
  | Items v1 -> let v1 = OCaml.vof_list vof_toplevel v1 in 
      OCaml.VSum (("Items", [ v1 ]))
  | Stmt v1 -> let v1 = vof_stmt v1 in OCaml.VSum (("Stmt", [ v1 ]))
  | Program v1 -> let v1 = vof_program v1 in OCaml.VSum (("Program", [ v1 ]))
