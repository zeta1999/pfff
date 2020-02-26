open Utils_ruby
module Utils = Utils_ruby

open Il_ruby  

let uniq_counter = ref 0
let uniq () = incr uniq_counter; !uniq_counter


  let compare t1 t2 = compare t1.sid t2.sid

  let mkstmt snode pos = 
    {snode = snode;
     pos = pos;
     lexical_locals = Utils_ruby.StrSet.empty;
     preds=Set_.empty;
     succs=Set_.empty;
     sid = uniq()}

  let update_stmt stmt snode = 
    {snode = snode;
     pos = stmt.pos;
     lexical_locals = stmt.lexical_locals;
     preds=Set_.empty;
     succs=Set_.empty;
     sid = uniq()}

  let update_locals stmt locals = stmt.lexical_locals <- locals

  let rec fold_stmt f acc stmt = match stmt.snode with
    | If(_g,ts,fs) -> fold_stmt f (fold_stmt f (f acc stmt) ts) fs

    | Seq(sl) -> List.fold_left (fold_stmt f) (f acc stmt) sl

    | For(_,_,s)
    | Module(_,_,s)
    | Method(_,_,s)
    | Class(_,_,s)
    | Begin(s)
    | End(s) -> fold_stmt f (f acc stmt) s

    | While(_g,body) ->
        fold_stmt f (f acc stmt)  body

    | Case(c) ->
        let acc = f acc stmt in
        let acc = List.fold_left
	  (fun acc (_w,b) ->
	     fold_stmt f acc b 
	  ) acc c.case_whens
        in
	  Utils_ruby.do_opt ~none:acc ~some:(fold_stmt f acc) c.case_else

    | MethodCall(_,{mc_cb = (None|Some (CB_Arg _)); _}) -> f acc stmt
    | MethodCall(_,{mc_cb = Some (CB_Block(_,cb_body)); _}) -> 
        fold_stmt f (f acc stmt) cb_body
	  
    | ExnBlock(b) ->
        let acc = f acc stmt in
        let acc = fold_stmt f acc b.exn_body in
        let acc = List.fold_left
	  (fun acc rb -> 
	     fold_stmt f acc rb.rescue_body
	  ) acc b.exn_rescue 
        in
        let acc = Utils_ruby.do_opt ~none:acc ~some:(fold_stmt f acc) b.exn_ensure in
	  Utils_ruby.do_opt ~none:acc ~some:(fold_stmt f acc) b.exn_else

    | Alias _ | Assign _ | Expression _ | Return _ | Yield _
    | Defined _ | Undef _ | Break _ | Redo | Retry | Next _ 
        -> f acc stmt

  let rec compute_cfg_succ stmt (succs:stmt Set_.t) = match stmt.snode with
    | Seq [] -> stmt.succs <- succs;
    | Seq ((hd::_) as l) -> 
        stmt.succs <- Set_.add hd stmt.succs;
        compute_cfg_succ_list succs l

    | MethodCall _ (* handle CB *)
    | Assign _
    | Expression _
    | Defined _
    | Alias _ -> stmt.succs <- succs

    | Case cb -> 
        List.iter
	  (fun (_guard,body) ->
	     (*
	       stmt.succs <- StmtSet.add guard stmt.succs;
	       compute_cfg_succ guard (StmtSet.singleton body);
	     *)
	     compute_cfg_succ body succs;
	  ) cb.case_whens;
        begin match cb.case_else with
	  | None -> ()
	  | Some else' -> 
	      stmt.succs <- Set_.add else' stmt.succs;
	      compute_cfg_succ else' succs
        end

    | ExnBlock eb -> 
        stmt.succs <- Set_.add eb.exn_body stmt.succs;
        let succs' =  match eb.exn_ensure, eb.exn_else with
	  | None, None -> succs
	  | Some x, None
	  | None, Some x -> 
	      compute_cfg_succ x succs;
	      Set_.add x succs
	  | Some x1, Some x2 ->
	      compute_cfg_succ x1 succs;
	      compute_cfg_succ x2 succs;
	      Set_.add x1 (Set_.add x2 succs)
        in
        let succs' = 
	  List.fold_left
	    (fun acc resc ->
	       compute_cfg_succ resc.rescue_body succs;
	       Set_.add resc.rescue_body acc
	    ) succs' eb.exn_rescue
        in
	  compute_cfg_succ eb.exn_body succs'
	    
    | If(_g,t,f) -> 
        stmt.succs <- Set_.add t (Set_.add f stmt.succs);
        compute_cfg_succ t succs;
        compute_cfg_succ f succs

    | While(_g,body) ->
        stmt.succs <- Set_.add body stmt.succs;
        body.succs <- Set_.add stmt body.succs;
        compute_cfg_succ body succs

    | For(_params,_guard,body) ->
        stmt.succs <- Set_.union (Set_.add body succs) stmt.succs;
        body.succs <- Set_.union succs body.succs;
        compute_cfg_succ body succs

    | Return _ -> stmt.succs <- Set_.empty
    | Yield _ -> stmt.succs <- Set_.union succs stmt.succs

    | Module(_,_,body)
    | Class(_,_,body) -> 
        stmt.succs <- Set_.add body stmt.succs;
        compute_cfg_succ body succs

    | Method(_,_,body) ->
        stmt.succs <- succs;
        compute_cfg_succ body Set_.empty
	  
    | Undef _ | Break _ | Redo | Retry | Next _ -> 
        failwith "handle control op in successor computation"

    (* These can't actually appear in a method *)
    | Begin(body)
    | End(body) -> 
        stmt.succs <- Set_.add body stmt.succs;
        compute_cfg_succ body succs
	  
  and compute_cfg_succ_list last = function
    | [] -> assert false
    | hd::[] -> compute_cfg_succ hd last
    | h1::((h2::_) as tl) -> 
        compute_cfg_succ h1 (Set_.singleton h2);
        compute_cfg_succ_list last tl

  let preds_from_succs stmt = 
    fold_stmt 
      (fun () stmt ->
         Set_.iter
	   (fun succ ->
	      succ.preds <- Set_.add stmt succ.preds
	   ) stmt.succs
      ) () stmt
      
  let compute_cfg stmt = 
    let () = fold_stmt 
      (fun () s -> 
         s.preds <- Set_.empty; 
         s.succs <- Set_.empty
      ) () stmt 
    in
      compute_cfg_succ stmt Set_.empty;
      preds_from_succs stmt


module Abbr = struct

  let local s = `ID_Var(Var_Local,s)
  let ivar s =`ID_Var(Var_Instance,s)
  let cvar s =`ID_Var(Var_Class,s)
  let global s =`ID_Var(Var_Global,s)
  let const s =`ID_Var(Var_Constant,s)
  let builtin s =`ID_Var(Var_Builtin,s)

  let var x =
    try 
      let kind = match x.[0] with
        | 'a'..'z' | '_' -> Var_Local
        | '@' -> if x.[1] = '@' then Var_Class else Var_Instance
        | '$' -> Var_Global
        | 'A'..'Z' -> Var_Constant
        | _ -> raise (Invalid_argument "ast_id")
      in
        `ID_Var(kind,x)
    with _ -> failwith "Cfg.Abbr.var"

  let iself = `ID_Self
  let inil = `ID_Nil
  let itrue = `ID_True
  let ifalse = `ID_False

  (* convience type for coercing the rested polymorhpic variant used in access_path *)
  type access_path_t = [
     | `ID_Var of var_kind (* always [Var_Constant or Var_Local] *) * string
     | `ID_Scope of access_path_t * string
  ]

  let access_path lst = 
    let rec work = function
      | [] -> assert false
      | [x] -> `ID_Var(Var_Constant, x)
      | x::(_::_ as rest) -> `ID_Scope(work rest,x)
    in (work (List.rev lst) : access_path_t :> [>identifier])

  let num i = `Lit_FixNum i
  let bignum n = `Lit_BigNum n
  let float f = `Lit_Float(string_of_float f, f)
  let str s = `Lit_String s
  let atom s = `Lit_Atom s
  let regexp ?(o="") str = `Lit_Regexp(o,str)
  let array lst = 
    (`Lit_Array lst : [`Lit_Array of star_expr list] :> [>literal])

  let hash lst = 
    (`Lit_Hash lst : [`Lit_Hash of (expr*expr) list] :> [>literal])

  let range ?(inc=true) l u = 
    (`Lit_Range(inc,l,u) : [`Lit_Range of bool * expr * expr] :> [>literal])

  let expr e pos = mkstmt (Expression(e :> expr)) pos

  let seq lst pos = match lst with
    | [] -> expr (EId `ID_Nil) pos
    | ({snode=Seq _; _} as blk)::[] -> blk
    | x::[] -> x
    | l -> 
        let revl = List.fold_left
          (fun acc x -> match x.snode with 
             | Seq l' -> List.rev_append l' acc
             | _ -> x::acc
          ) [] l
        in
        let l' = List.rev revl in
          mkstmt (Seq l') pos

  let alias_g ~link ~orig pos = 
    let link' = (link :> builtin_or_global) in
    let orig' = (orig :> builtin_or_global) in
      mkstmt (Alias(Alias_Global(link',orig'))) pos

  let alias_m ~link ~orig pos = 
    let link' = (link :> msg_id) in
    let orig' = (orig :> msg_id) in
      mkstmt (Alias(Alias_Method(link',orig'))) pos

  let if_s g ~t ~f pos = mkstmt (If((g:>expr),t,f)) pos

  let case ?default guard whens pos = match whens with
    | [] -> begin match default with
        | None -> failwith "Cfg.Abbr.case"
        | Some x -> x
      end
    | _ -> 
        let lst = (whens :> (tuple_expr*stmt) list) in
        let guard = (guard :> expr) in
        let c = {case_guard = guard; case_whens = lst; case_else=default} in
          mkstmt (Case c) pos

  let while_s guard body pos = mkstmt (While((guard :> expr), body)) pos

  let for_s formals guard body pos = 
    let f = (formals :> block_formal_param list) in
    let g = (guard :> expr) in
      mkstmt (For(f,g,body)) pos

  let mcall ?lhs ?targ msg args ?cb pos = 
    let mc = {mc_target=(targ :> expr option); 
              mc_msg = (msg :> msg_id);
              mc_args=(args :> star_expr list);
              mc_cb = cb}
    in mkstmt (MethodCall((lhs:>lhs option),mc)) pos

  let call ?lhs ?targ msg args ?cb pos = 
    mcall ?lhs ?targ (ID_MethodName msg) args ?cb pos

  let massign ?lhs ?targ msg args ?cb pos = 
    mcall ?lhs ?targ (ID_Assign msg) args ?cb pos

  let uop ?lhs msg targ ?cb pos = 
    mcall ?lhs ~targ (ID_UOperator msg) [] ?cb pos

  let binop ?lhs targ msg arg ?cb pos = 
    mcall ?lhs ~targ (ID_Operator msg) [arg] ?cb pos

  let super ?lhs args ?cb pos = mcall ?lhs ID_Super args ?cb pos

  let assign lhs tup pos = 
    mkstmt (Assign((lhs:>lhs),(tup:>tuple_expr))) pos

  let return ?v pos = mkstmt (Return(v :> tuple_expr option)) pos
  let yield ?lhs ?args pos = 
    let args' = default_opt [] (args :> star_expr list option) in
      mkstmt (Yield((lhs :> lhs option),args')) pos

  let meth ?targ def args body pos = 
    ignore targ;
    mkstmt(Method(def,args,body)) pos

  let method_ ?targ msg args body pos = 
    let def = match targ with
      | None -> Instance_Method msg
      | Some i -> Singleton_Method((i :> identifier), msg)
    in
      mkstmt (Method(def,args,body)) pos

  let nameclass ?lhs name ?inh body pos = 
    let kind = NominalClass((name :> identifier),(inh :> identifier option)) in
      mkstmt (Class((lhs :> lhs option),kind,body)) pos
                
  let metaclass ?lhs name body pos = 
    let kind = MetaClass(name :> identifier) in
      mkstmt (Class((lhs :> lhs option),kind,body)) pos

  let module_s ?lhs name body pos = 
    mkstmt (Module((lhs :> lhs option),(name :> identifier),body)) pos

  let mdef ?targ s args body pos =  method_ ?targ (ID_MethodName s) args body pos
  let adef ?targ s args body pos =  method_ ?targ (ID_Assign s) args body pos
  let opdef ?targ o args body pos =  method_ ?targ (ID_Operator o) args body pos
  let uopdef ?targ o args body pos =  method_ ?targ (ID_UOperator o) args body pos


  let rguard ?bind guard = match bind with
    | None -> Rescue_Expr (guard :> tuple_expr)
    | Some s -> Rescue_Bind((guard :>tuple_expr), (s :> identifier))

  let rblock guards stmt = {rescue_guards=guards; rescue_body=stmt}
    
  let rescue ?bind guard stmt = rblock [rguard ?bind guard] stmt

  let exnblock body rescues ?eelse ?ensure pos =
    mkstmt (ExnBlock {exn_body=body;exn_rescue=rescues;
                      exn_else=eelse;exn_ensure=ensure}) pos

  let defined i s pos = mkstmt (Defined((i:>identifier),s)) pos
  let undef lst pos = mkstmt (Undef((lst:>msg_id list))) pos
  let break ?v pos = mkstmt (Break (v:>tuple_expr option)) pos
  let next ?v pos = mkstmt (Next (v:>tuple_expr option)) pos
  let retry pos = mkstmt Retry pos
  let redo pos = mkstmt Redo pos

  let _r1 p = call ~lhs:(LId (local "x")) "foo" [SE (ELit (float 1.0))] p
  let _r2 p = binop (ELit (float 3.0)) Op_Times (SE (EId (local "x"))) p

end

let pos_of s = s.pos

let empty_stmt () = mkstmt (Expression (EId `ID_Nil)) Lexing.dummy_pos

let fresh_local _s = 
  let i = uniq () in
    `ID_Var(Var_Local,Printf.sprintf "__fresh_%d" i)

let _strip_colon s = 
  assert(s.[0] == ':');
  String.sub s 1 (String.length s - 1)

let msg_id_of_string str = match str with
  | "+" -> ID_Operator Op_Plus
  | "-" -> ID_Operator Op_Minus
  | "*" -> ID_Operator Op_Times
  | "%" -> ID_Operator Op_Rem
  | "/" -> ID_Operator Op_Div
  | "<=>" -> ID_Operator Op_CMP
  | "==" -> ID_Operator Op_EQ
  | "===" -> ID_Operator Op_EQQ
  | ">=" -> ID_Operator Op_GEQ
  | "<=" -> ID_Operator Op_LEQ
  | "<" -> ID_Operator Op_LT
  | ">" -> ID_Operator Op_GT
  | "&" -> ID_Operator Op_BAnd
  | "|" -> ID_Operator Op_BOr
  | "=~" -> ID_Operator Op_Match
  | "^" -> ID_Operator Op_XOR
  | "**" -> ID_Operator Op_Pow
  | "[]" -> ID_Operator Op_ARef
  | "[]=" -> ID_Operator Op_ASet
  | "<<" -> ID_Operator Op_LShift
  | ">>" -> ID_Operator Op_RShift
  | "-@" -> ID_UOperator Op_UMinus
  | "+@" -> ID_UOperator Op_UPlus
  | "~@" | "~" -> ID_UOperator Op_UTilde
  | s -> 
      let len = String.length s in
      let all_but_one = String.sub s (len-1) 1 in
        if all_but_one = "="
        then ID_Assign all_but_one
        else ID_MethodName s

let rec stmt_eq (s1:stmt) (s2:stmt) = 
    snode_eq s1.snode s2.snode

and snode_eq s1 s2 = match s1, s2 with
  | Seq l1, Seq l2 -> 
      begin try
	  List.fold_left2 (fun acc s1 s2 -> acc && stmt_eq s1 s2) true l1 l2
	with Invalid_argument _ -> false
      end
  | Alias(ak1), Alias(ak2) -> ak1 = ak2 (* BUG! was ak1 = ak1 *)
  | If(g1,t1,f1),If(g2,t2,f2) -> g1 = g2 && stmt_eq t1 t2 && stmt_eq f1 f2
  | Case c1, Case c2 -> case_eq c1 c2

  | While(g1,b1), While(g2,b2) -> g1 = g2 && stmt_eq b1 b2
  | For(p1,g1,b1), For(p2,g2,b2) -> p1 = p2 && g1 = g2 && stmt_eq b1 b2

  | MethodCall(l1,mc1),MethodCall(l2,mc2) -> l1 = l2 && methodcall_eq mc1 mc2
  | Assign(l1,r1), Assign(l2,r2) -> l1 = l2 && r1 = r2
  | Expression e1, Expression e2 -> e1 = e2
  | Return e1, Return e2 -> e1 = e2
  | Yield(l1,p1), Yield(l2,p2) -> l1 = l2 && p1 = p2
  | Module(lo1,i1,s1),Module(lo2,i2,s2) -> 
      lo1 = lo2 && i1 = i2 && stmt_eq s1 s2
  | Method(n1,p1,s1), Method(n2,p2,s2) -> n1 = n2 && p1 = p2 && stmt_eq s1 s2
  | Class(lo1,k1,b1), Class(lo2,k2, b2) -> 
      lo1 = lo2 && k1 = k2 && stmt_eq b1 b2
  | ExnBlock e1, ExnBlock e2 -> exn_eq e1 e2
  | Begin s1, Begin s2 -> stmt_eq s1 s2
  | End s1, End s2 -> stmt_eq s1 s2
  | Defined(id1,s1), Defined(id2,s2) -> id1 = id2 && stmt_eq s1 s2
  | Undef el1, Undef el2 -> el1 = el2
  | Break(lst1), Break(lst2)
  | Next(lst1), Next(lst2) -> lst1 = lst2
  | Redo, Redo
  | Retry, Retry -> true
  | _,_ -> false

and methodcall_eq mc1 mc2 = 
  (mc1.mc_target = mc2.mc_target)
  &&
    (mc1.mc_msg = mc2.mc_msg)
  &&
    (mc1.mc_args = mc2.mc_args)
  && Utils.eq_opt codeblock_eq mc1.mc_cb mc2.mc_cb 

and codeblock_eq c1 c2 = match c1,c2 with
  | CB_Arg e1, CB_Arg e2 -> e1 = e2
  | CB_Arg _, CB_Block _ | CB_Block _, CB_Arg _ -> false
  | CB_Block(e1,b1), CB_Block(e2,b2) ->
      e1 = e2 && stmt_eq b1 b2

and rescue_block_eq rb1 rb2 = 
  try
    List.fold_left2
      (fun acc b1 b2 -> 
	acc && b1.rescue_guards = b2.rescue_guards &&
	  stmt_eq b1.rescue_body b2.rescue_body
      ) true rb1 rb2
  with Invalid_argument _ -> false

and exn_eq e1 e2 = 
  (stmt_eq e1.exn_body e2.exn_body)
  && rescue_block_eq e1.exn_rescue e2.exn_rescue
  && eq_opt stmt_eq e1.exn_ensure e2.exn_ensure
  && eq_opt stmt_eq e1.exn_else e2.exn_else

and case_eq c1 c2 = 
  (c1.case_guard = c2.case_guard) 
  &&
    begin try List.fold_left2
	(fun acc (e1,s1) (e2,s2) -> 
	  acc && e1 = e2 && stmt_eq s1 s2
	) true c1.case_whens c2.case_whens
      with Invalid_argument _ -> false
    end
  && eq_opt stmt_eq c1.case_else c2.case_else

open Visitor

class type cfg_visitor = object

  method visit_stmt : stmt visit_method

  method visit_id : identifier visit_method
  method visit_literal : literal visit_method
  method visit_expr : expr visit_method
  method visit_lhs : lhs visit_method
  method visit_tuple : tuple_expr visit_method
  method visit_rescue_guard : rescue_guard visit_method
  method visit_def_name : def_name visit_method
  method visit_class_kind : class_kind visit_method
  method visit_method_param : method_formal_param visit_method
  method visit_msg_id : msg_id visit_method
  method visit_block_param : block_formal_param visit_method
end

class default_visitor : cfg_visitor = 
object(_self)
  method visit_literal _l = DoChildren
  method visit_id _id = DoChildren
  method visit_expr _e = DoChildren
  method visit_lhs _lhs = DoChildren
  method visit_tuple _tup = DoChildren
  method visit_msg_id _id = DoChildren
  method visit_rescue_guard _rg = DoChildren
  method visit_def_name _dn = DoChildren
  method visit_class_kind _ck = DoChildren
  method visit_method_param _p = DoChildren
  method visit_block_param _p = DoChildren

  method visit_stmt _stmt = DoChildren
end

class scoped_visitor = 
object(_self)
  inherit default_visitor

  method! visit_stmt stmt = match stmt.snode with
      (* these start a new scope *)
    | Begin _ | End _ | Class _ | Module _ | Method _ -> SkipChildren
    | _ -> DoChildren
end

let visit_leaf meth orig = visit meth orig id

let visit_msg_id vtor msg = visit_leaf vtor#visit_msg_id msg
let visit_id vtor i = visit_leaf vtor#visit_id i
let visit_block_param vtor p = visit_leaf vtor#visit_block_param p

let visit_def_name vtor dn = 
  visit vtor#visit_def_name dn begin function
    | Instance_Method msg ->
	let msg' = visit_msg_id vtor msg in
	  if msg'==msg then dn else Instance_Method msg'
    | Singleton_Method(id,msg) ->
	let id' = visit_id vtor id in
	let msg' = visit_msg_id vtor msg in
	  if id'==id && msg'==msg then dn
	  else Singleton_Method(id',msg')
  end
      
let rec visit_literal vtor l = 
  visit vtor#visit_literal l begin function
    | `Lit_Array star_lst ->
	let lst' = map_preserve List.map (visit_star_expr vtor) star_lst in
	  if star_lst==lst' then l else `Lit_Array lst'
	    
    | `Lit_Hash pair_lst ->
	let lst' = map_preserve List.map
	  (fun ((e1,e2) as pair) ->
	     let e1' = visit_expr vtor e1 in
	     let e2' = visit_expr vtor e2 in
	       if e1==e1' && e2==e2' then pair else (e1',e2')
	  ) pair_lst
	in if pair_lst==lst' then l else `Lit_Hash lst'
	    
    | `Lit_Range(b,e1,e2) ->
	let e1' = visit_expr vtor e1 in
	let e2' = visit_expr vtor e2 in
	  if e1==e1' && e2==e2' then l else `Lit_Range(b,e1',e2')
	    
    | _ -> l
  end

and visit_expr vtor (e:expr) = 
  visit vtor#visit_expr e begin function
    | ELit (#literal as l) -> (ELit (visit_literal vtor l) : expr)
    | EId (#identifier as id) -> (EId (visit_id vtor id) : expr)
  end

and visit_lhs vtor (lhs:lhs) = 
  visit vtor#visit_lhs lhs begin function
    | LId (#identifier as id) -> LId (visit_id vtor id :> identifier)
    | LTup (lhs_l) -> 
	let lhs_l' = map_preserve List.map (visit_lhs vtor) lhs_l in
	  if lhs_l == lhs_l' then lhs
	  else LTup (lhs_l')
    | LStar ( (#identifier as id)) -> 
	let id' = visit_id vtor id in
	  if id==id' then lhs else (LStar ( id') : lhs)
  end

and visit_star_expr vtor star = match star with
  | SE (e) -> SE (visit_expr vtor e)
  | SStar (e) -> 
      let e' = visit_expr vtor e in
        if e==e' then star else SStar (e')

let rec visit_tuple vtor tup = 
  visit vtor#visit_tuple tup begin function
    | TE (e) -> TE (visit_expr vtor e : expr)
    | TTup (lst) ->
  	  let lst' = map_preserve List.map (visit_tuple vtor) lst in
	  if lst == lst' then tup
	  else TTup (lst')
    | TStar ((TE (e))) -> 
	  let e' = visit_expr vtor e in
	  if e==e' then tup else (TStar ((TE e')) : tuple_expr)
    | TStar ((TTup (lst))) -> 
	  let lst' = map_preserve List.map (visit_tuple vtor) lst in
	  if lst == lst' then tup
	  else TStar ((TTup (lst')))
    | _ -> failwith "Impossible" (* TStar (`Star (TStar _) *)
  end


let visit_rescue_guard vtor rg = 
  visit vtor#visit_rescue_guard rg begin function
    | Rescue_Expr tup -> 
	let tup' = visit_tuple vtor tup in
	  if tup' == tup then rg else Rescue_Expr tup'
    | Rescue_Bind(tup,id) ->
	let tup' = visit_tuple vtor tup in
	let id' = visit_id vtor id in
	  if tup'==tup && id'==id then rg else Rescue_Bind(tup',id')
  end

let visit_class_kind vtor ck = 
  visit vtor#visit_class_kind ck begin function
    | MetaClass(id) -> 
	let id' = visit_id vtor id in
	  if id==id' then ck else MetaClass id'
    | NominalClass(id1,id2) ->
	let id1' = visit_id vtor id1 in
	let id2' = map_opt_preserve (visit_id vtor) id2 in
	  if id1'==id1 && id2'==id2 then ck else NominalClass(id1',id2')
end

let visit_method_param vtor p =
  visit vtor#visit_method_param p begin function
      Formal_meth_id _
    | Formal_amp _
    | Formal_star _ -> p
    | Formal_default(s,tup) ->
	let tup' = visit_tuple vtor tup in
	  if tup'==tup then p else Formal_default(s,tup')
  end

let visit_alias_kind (vtor:cfg_visitor) ak = match ak with
  | Alias_Method(m1,m2) ->
      let m1' = visit_msg_id vtor m1 in
      let m2' = visit_msg_id vtor m2 in
	if m1 == m1' && m2 == m2' then ak
	else Alias_Method(m1',m2')

  | Alias_Global(_s1,_s2) -> ak
          
let rec visit_stmt (vtor:cfg_visitor) stmt = 
  visit vtor#visit_stmt stmt (visit_stmt_children vtor)

and visit_stmt_children vtor stmt = match stmt.snode with
    | Seq sl -> 
	let sl' = map_preserve List.map (visit_stmt vtor) sl in
	  if sl == sl' then stmt
	  else update_stmt stmt (Seq sl')

    | Alias(ak) -> 
	let ak' = visit_alias_kind vtor ak in
	  if ak == ak' then stmt
	  else update_stmt stmt (Alias ak')

    | MethodCall(lhso, mc) ->
	let lhso' = map_opt_preserve (visit_lhs vtor) lhso in
	let targ' = map_opt_preserve (visit_expr vtor) mc.mc_target in
	let msg' = visit_msg_id vtor mc.mc_msg in
	let args' = map_preserve List.map (visit_star_expr vtor) mc.mc_args in
	let cb' = map_opt_preserve 
	  (fun cb -> match cb with
             | CB_Arg e -> 
                 let e' = visit_expr vtor e in
                   if e == e' then cb else CB_Arg e'
             | CB_Block(formals,body) -> 
	     let formals' = map_preserve List.map 
	       (visit_block_param vtor) formals 
	     in
	     let body' = visit_stmt vtor body in
	       if formals'==formals && body'==body
	       then cb else CB_Block(formals',body')
	  ) mc.mc_cb
	in
	  if lhso == lhso' && mc.mc_target==targ' && mc.mc_msg == msg' 
	    && mc.mc_args==args' && mc.mc_cb == cb'
	  then stmt 
	  else 
	    let mc' = {mc_target=targ';mc_msg=msg';mc_args=args';mc_cb=cb'}
	    in update_stmt stmt (MethodCall(lhso',mc'))

    | Yield(lhso, args) ->
	let lhso' = map_opt_preserve (visit_lhs vtor) lhso in
	let args' = map_preserve List.map (visit_star_expr vtor) args in
	  if lhso == lhso' && args == args' 
	  then stmt else update_stmt stmt (Yield(lhso',args'))
	    
    | Assign(lhs,rhs) -> 
	let lhs' = visit_lhs vtor lhs in
	let rhs' = visit_tuple vtor rhs in
	  if lhs == lhs' && rhs == rhs'
	  then stmt else update_stmt stmt (Assign(lhs',rhs'))

    | For(blist,guard,body) -> 
	let blist' = map_preserve List.map (visit_block_param vtor) blist in
	let guard' = visit_expr vtor guard in
	let body' = visit_stmt vtor body in
	  if guard == guard' && body == body' && blist == blist'
	  then stmt else update_stmt stmt (For(blist',guard',body'))

    | Begin s ->
	let s' = visit_stmt vtor s in 
	  if s == s' then stmt else update_stmt stmt (Begin s')
	    
    | End s ->
	let s' = visit_stmt vtor s in 
	  if s == s' then stmt else update_stmt stmt (End s')

    | While(g, body) ->
	let g' = visit_expr vtor g in
	let body' = visit_stmt vtor body in
	  if g == g' && body == body'
	  then stmt else update_stmt stmt (While(g',body'))

    | If(g, s1, s2) ->
	let g' = visit_expr vtor g in
	let s1' = visit_stmt vtor s1 in
	let s2' = visit_stmt vtor s2 in
	  if g == g' && s1 == s1' && s2 == s2'
	  then stmt else update_stmt stmt (If(g',s1',s2'))

    | Case c ->
	let guard' = visit_expr vtor c.case_guard in
	let whens' = 
	  map_preserve List.map
	    (fun ((g,s) as w) -> 
	       let g' = visit_tuple vtor g in
	       let s' = visit_stmt vtor s in
		 if g' == g && s == s' then w else (g',s')
	    ) c.case_whens
	in
	let else' = map_opt_preserve (visit_stmt vtor) c.case_else in
	  if guard' == c.case_guard && whens' = c.case_whens
	      && else' == c.case_else 
	  then stmt 
	  else 
	    let c' = {case_guard=guard';case_whens=whens';case_else=else'} in
	      update_stmt stmt (Case c')

    | ExnBlock e ->
	let body' = visit_stmt vtor e.exn_body in
	let else' = map_opt_preserve (visit_stmt vtor) e.exn_else in
	let ensure' = map_opt_preserve (visit_stmt vtor) e.exn_ensure in
	let rescue' = 
	  map_preserve List.map
	    (fun resc -> 
	       let guards' = 
		 map_preserve List.map (visit_rescue_guard vtor) resc.rescue_guards
	       in
	       let rbody' = visit_stmt vtor resc.rescue_body in
		 if guards' == resc.rescue_guards && rbody'=resc.rescue_body
		 then resc
		 else {rescue_guards=guards';rescue_body=rbody'}
	    )  e.exn_rescue
	in
	  if body' == e.exn_body && else'==e.exn_else &&
	    ensure' == e.exn_ensure && rescue'==e.exn_rescue
	  then stmt
	  else 
	    let e' = {exn_body=body';exn_else=else';exn_ensure=ensure';
		      exn_rescue=rescue'}
	    in update_stmt stmt (ExnBlock e')

    | Class(lhso, cls, body) ->
	let lhso' = map_opt_preserve (visit_lhs vtor) lhso in
	let cls' = visit_class_kind vtor cls in
	let body' = visit_stmt vtor body in
	  if cls==cls' && body==body'
	  then stmt
	  else update_stmt stmt (Class(lhso',cls',body'))

    | Module(lhso, id, body) ->
	let lhso' = map_opt_preserve (visit_lhs vtor) lhso in
	let id' = visit_id vtor id in
	let body' = visit_stmt vtor body in
	  if id==id' && body==body' then stmt
	  else update_stmt stmt (Module(lhso',id',body'))

    | Method(def_name, args, body) ->
	let def_name' = visit_def_name vtor def_name in
	let args' = map_preserve List.map (visit_method_param vtor) args in
	let body' = visit_stmt vtor body in
	  if def_name==def_name' && args==args' && body==body'
	  then stmt 
	  else update_stmt stmt (Method(def_name',args',body'))

    | Expression e ->
	let e' = visit_expr vtor e in
	  if e==e' then stmt else update_stmt stmt (Expression e')

    | Defined(id, istmt) ->
	let id' = visit_id vtor id in
	let istmt' = visit_stmt vtor istmt in
	  if id==id' && istmt==istmt' then stmt 
	  else update_stmt stmt (Defined(id',istmt'))

    | Return tup_o ->
	let tup_o' = map_opt_preserve (visit_tuple vtor) tup_o in
	  if tup_o == tup_o' then stmt else update_stmt stmt (Return tup_o')

    | Break tup_o ->
	let tup_o' = map_opt_preserve (visit_tuple vtor) tup_o in
	  if tup_o == tup_o' then stmt else update_stmt stmt (Break tup_o')
	    
    | Next tup_o ->
	let tup_o' = map_opt_preserve (visit_tuple vtor) tup_o in
	  if tup_o == tup_o' then stmt else update_stmt stmt (Next tup_o')
	    
    | Undef msg_l ->
	let msg_l' = map_preserve List.map (visit_msg_id vtor) msg_l in
	  if msg_l == msg_l' then stmt
	  else update_stmt stmt (Undef msg_l')

    | Redo | Retry -> stmt



class alpha_visitor ~var ~sub = 
object(_self)
  inherit scoped_visitor
  method! visit_id id = match id with
    | `ID_Var(Var_Local,s) ->
        if String.compare var s = 0 
        then ChangeTo (`ID_Var(Var_Local,sub))
        else DoChildren
    | _ -> DoChildren
end

let alpha_convert_local ~var ~sub s = 
  visit_stmt (new alpha_visitor ~var ~sub) s

let rec locals_of_lhs acc (lhs:lhs) = match lhs with
  | LId (`ID_Var(Var_Local,s)) -> StrSet.add s acc
  | LId (#identifier) -> acc
  | LTup (lst) -> List.fold_left locals_of_lhs acc lst
  | LStar ((#identifier as s))  -> locals_of_lhs acc (LId s : lhs)


let rec locals_of_any_formal acc (p:any_formal) = match p with
  | M (Formal_default(s,_))
  | M (Formal_star s)
  | B (Formal_star2 s)
  | M (Formal_amp s)
  | M (Formal_meth_id s)
  | B (Formal_block_id(Var_Local, s)) -> StrSet.add s acc
  | B (Formal_block_id _) -> acc
  | B (Formal_tuple lst)  -> 
      let lst = lst |> List.map b_to_any in
      List.fold_left locals_of_any_formal acc (lst : any_formal list)

class compute_locals_vtor seen_env = 
object(_self)
  inherit default_visitor
  val mutable seen = seen_env
    
  method! visit_lhs lhs = 
    seen <- locals_of_lhs seen lhs;
    SkipChildren

  method! visit_method_param p = 
    let p = m_to_any p in
    seen <- locals_of_any_formal seen (p : any_formal);
    SkipChildren
  method! visit_block_param p = 
    let p = b_to_any p in
    seen <- locals_of_any_formal seen (p : any_formal);
    SkipChildren

  method! visit_rescue_guard rg = match rg with
    | Rescue_Bind(_te,`ID_Var(Var_Local,s)) -> 
        seen <- StrSet.add s seen;
        SkipChildren
    | Rescue_Bind _
    | Rescue_Expr _ -> SkipChildren

  method! visit_stmt stmt = 
    update_locals stmt seen;
    match stmt.snode with
        (* these start a new scope *)
      | Begin _ | End _  | Class _ | Module _ | Method _ -> 
          let vtor' = ({<seen=StrSet.empty >} :> cfg_visitor) in
            ignore (visit_stmt_children vtor' stmt);
            SkipChildren
              
      | _ -> DoChildren
end

let compute_cfg_locals ?(env=StrSet.empty) stmt = 
  ignore(visit_stmt (new compute_locals_vtor env) stmt)

