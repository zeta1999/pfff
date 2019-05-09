/* Yoann Padioleau
 *
 * Copyright (C) 2010, 2013, 2014 Facebook
 * Copyright (C) 2019 Yoann Padioleau
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public License
 * version 2.1 as published by the Free Software Foundation, with the
 * special exception on linking described in file license.txt.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the file
 * license.txt for more details.
 */
%{
(* This file contains a grammar for Javascript (ES6 and more), Flow,
 * and Typescript.
 * See:
 *  - https://en.wikipedia.org/wiki/JavaScript_syntax
 *  - http://www.ecma-international.org/publications/standards/Ecma-262.htm
 *  - https://github.com/Microsoft/TypeScript/blob/master/doc/spec.md#A
 * 
 * src: originally ocamlyaccified from Marcel Laverdet 'fbjs2' via Emacs
 * macros, itself extracted from the official ECMAscript specification at:
 * http://www.ecma-international.org/publications/standards/ecma-262.htm
 * back in the day (probably ES4 or ES3).
 * 
 * I heavily extended the grammar to provide the first parser for Flow.
 * I extended it also to deal with many new Javascript features
 * (see ast_js.ml top comment). 
 *
 * The grammar is close to the ECMA grammar but I simplified things 
 * when I could:
 *  - less intermediate grammar rules for advanced features
 *    (they are inlined in the original grammar rule)
 *  - by using my retagging-tokens technique (see parsing_hacks_js.ml) 
 *    I could also get rid of some of the ugliness in the ECMA grammar 
 *    that has to deal with ambiguous constructs
 *    (they conflate together expressions and arrow parameters, object
 *    values and object matching, etc.). 
 *    Instead, in this grammar things are clearly separated.
 *)
open Common

open Ast_js

let e x = (x)
let bop op a b c = e(B(a, (op, b), c))
let uop op a b = e(U((op,a), b))
let mk_param x = 
  { p_name = x; p_type = None; p_default = None; p_dots = None; }

(* for missing closing > for generics *)
let fake_tok s = {
  Parse_info.
  token = Parse_info.FakeTokStr (s, None);
  transfo = Parse_info.NoTransfo;
}

%}

/*(*************************************************************************)*/
/*(*1 Tokens *)*/
/*(*************************************************************************)*/

%token <Ast_js.tok> TUnknown  /*(* unrecognized token *)*/
%token <Ast_js.tok> EOF

/*(*-----------------------------------------*)*/
/*(*2 The space/comment tokens *)*/
/*(*-----------------------------------------*)*/
/*(* coupling: Token_helpers.is_comment *)*/
%token <Ast_js.tok> TCommentSpace TCommentNewline   TComment

/*(*-----------------------------------------*)*/
/*(*2 The normal tokens *)*/
/*(*-----------------------------------------*)*/

/*(* tokens with a value *)*/
%token<string * Ast_js.tok> T_NUMBER
%token<string * Ast_js.tok> T_IDENTIFIER

%token<string * Ast_js.tok> T_STRING 
%token<string * Ast_js.tok> T_ENCAPSED_STRING
%token<string * Ast_js.tok> T_REGEX

/*(*-----------------------------------------*)*/
/*(*2 Keyword tokens *)*/
/*(*-----------------------------------------*)*/
/*(* coupling: if you add an element here, expand also ident_keyword_bis
   * and also maybe the special hack for regexp in lexer_js.mll
   *)*/
%token <Ast_js.tok>
 T_FUNCTION T_CONST T_VAR T_LET
 T_IF T_ELSE
 T_WHILE T_FOR T_DO T_CONTINUE T_BREAK
 T_SWITCH T_CASE T_DEFAULT 
 T_RETURN 
 T_THROW T_TRY T_CATCH T_FINALLY
 T_YIELD T_ASYNC T_AWAIT
 T_NEW T_IN T_OF T_INSTANCEOF T_THIS T_SUPER T_WITH
 T_NULL T_FALSE T_TRUE
 T_CLASS T_INTERFACE T_EXTENDS T_IMPLEMENTS T_STATIC T_GET T_SET T_CONSTRUCTOR
 T_IMPORT T_EXPORT T_FROM T_AS
 T_IN T_INSTANCEOF T_TYPEOF
 T_DELETE  T_VOID
 T_TYPE  T_ANY_TYPE T_NUMBER_TYPE T_BOOLEAN_TYPE T_STRING_TYPE  T_ENUM
 T_DECLARE T_MODULE
 T_PUBLIC T_PRIVATE T_PROTECTED
 
/*(*-----------------------------------------*)*/
/*(*2 Punctuation tokens *)*/
/*(*-----------------------------------------*)*/

/*(* syntax *)*/
%token <Ast_js.tok>
 T_LCURLY T_RCURLY
 T_LPAREN T_RPAREN
 T_LBRACKET T_RBRACKET
 T_SEMICOLON T_COMMA T_PERIOD T_COLON
 T_PLING 
 T_ARROW 
 T_DOTS
 T_BACKQUOTE 
 T_DOLLARCURLY

/*(* operators *)*/
%token <Ast_js.tok>
 T_OR T_AND
 T_BIT_OR T_BIT_XOR T_BIT_AND
 T_PLUS T_MINUS
 T_DIV T_MULT T_MOD
 T_NOT T_BIT_NOT 
 T_RSHIFT3_ASSIGN T_RSHIFT_ASSIGN T_LSHIFT_ASSIGN
 T_BIT_XOR_ASSIGN T_BIT_OR_ASSIGN T_BIT_AND_ASSIGN T_MOD_ASSIGN T_DIV_ASSIGN
 T_MULT_ASSIGN T_MINUS_ASSIGN T_PLUS_ASSIGN T_ASSIGN
 T_EQUAL T_NOT_EQUAL T_STRICT_EQUAL T_STRICT_NOT_EQUAL
 T_LESS_THAN_EQUAL T_GREATER_THAN_EQUAL T_LESS_THAN T_GREATER_THAN
 T_LSHIFT T_RSHIFT T_RSHIFT3
 T_INCR T_DECR 
 T_EXPONENT

/*(*-----------------------------------------*)*/
/*(*2 XHP tokens *)*/
/*(*-----------------------------------------*)*/
%token <string * Parse_info.info> T_XHP_OPEN_TAG
/*(* The 'option' is for closing tags like </> *)*/
%token <string option * Parse_info.info> T_XHP_CLOSE_TAG

/*(* ending part of the opening tag *)*/
%token <Parse_info.info> T_XHP_GT T_XHP_SLASH_GT

%token <string * Parse_info.info> T_XHP_ATTR T_XHP_TEXT

/*(*-----------------------------------------*)*/
/*(*2 Extra tokens: *)*/
/*(*-----------------------------------------*)*/

/*(* Automatically Inserted Semicolon (ASI), see parse_js.ml *)*/
%token <Ast_js.tok> T_VIRTUAL_SEMICOLON
/*(* '(' the opening parenthesis of the parameters preceding an arrow*)*/
%token <Ast_js.tok> T_LPAREN_ARROW

/*(*************************************************************************)*/
/*(*1 Priorities *)*/
/*(*************************************************************************)*/

/*(* must be at the top so that it has the lowest priority *)*/
%nonassoc LOW_PRIORITY_RULE

/*(* Special if / else associativity*)*/
%nonassoc p_IF
%nonassoc T_ELSE

%nonassoc p_POSTFIX

%right
 T_RSHIFT3_ASSIGN T_RSHIFT_ASSIGN T_LSHIFT_ASSIGN
 T_BIT_XOR_ASSIGN T_BIT_OR_ASSIGN T_BIT_AND_ASSIGN T_MOD_ASSIGN T_DIV_ASSIGN
 T_MULT_ASSIGN T_MINUS_ASSIGN T_PLUS_ASSIGN T_ASSIGN

%left T_OR
%left T_AND
%left T_BIT_OR
%left T_BIT_XOR
%left T_BIT_AND
%left T_EQUAL T_NOT_EQUAL T_STRICT_EQUAL T_STRICT_NOT_EQUAL
%left T_LESS_THAN_EQUAL T_GREATER_THAN_EQUAL T_LESS_THAN T_GREATER_THAN
      T_IN T_INSTANCEOF
%left T_LSHIFT T_RSHIFT T_RSHIFT3
%left T_PLUS T_MINUS
%left T_DIV T_MULT T_MOD

%right T_EXPONENT
%right T_NOT T_BIT_NOT T_INCR T_DECR T_DELETE T_TYPEOF T_VOID T_AWAIT

/*(*************************************************************************)*/
/*(*1 Rules type declaration *)*/
/*(*************************************************************************)*/

%start main module_item_or_eof
%type <Ast_js.module_item list> main
%type <Ast_js.module_item option> module_item_or_eof

%%

/*(*************************************************************************)*/
/*(*1 Toplevel *)*/
/*(*************************************************************************)*/

main: program EOF { $1 }

program: module_item_list_opt { $1 }


module_item_or_eof:
 | module_item { Some $1 }
 | EOF { None }

module_item:
 | item { It $1 }
 | import_declaration { Import $1 }
 | export_declaration { Export $1 }

/*(* item is also in statement_list, inside every blocks *)*/
item:
 | statement   { St $1 }
 | declaration { $1 }

declaration:
 /*(* part of hoistable_declaration in the ECMA grammar *)*/
 | function_declaration  { FunDecl $1 }
 /*(* es6: *)*/
 | generator_declaration { FunDecl $1 }
 /*(* es7: *)*/
 | async_declaration     { FunDecl $1 }

 /*(* es6: *)*/
 | lexical_declaration   { St $1 }
 | class_declaration     { ClassDecl $1 }
 /*(* typescript: *)*/
 | interface_declaration { InterfaceDecl $1 }
 | type_alias_declaration { ItemTodo }

/*(*************************************************************************)*/
/*(*1 Import/export *)*/
/*(*************************************************************************)*/

/*(*----------------------------*)*/
/*(*2 import *)*/
/*(*----------------------------*)*/

import_declaration: 
 | T_IMPORT import_clause from_clause semicolon 
   { $1, ImportFrom ($2, $3), $4 }
 | T_IMPORT module_specifier semicolon 
   { $1, ImportEffect $2, $3 }

import_clause: 
 | import_default { Some $1, None }
 /*(* less: add T_COMMA in AST? *)*/
 | import_default T_COMMA import_names { Some $1, Some $3 }
 |                        import_names { None, Some $1 }

import_default:
 | binding_identifier { $1 }

import_names:
 | T_MULT T_AS binding_identifier 
   { ImportNamespace ($1, $2, $3) }

 | T_LCURLY T_RCURLY 
   { ImportNames ($1, [], $2) }
 | T_LCURLY import_specifiers          T_RCURLY 
   { ImportNames ($1, $2, $3) }
 | T_LCURLY import_specifiers T_COMMA  T_RCURLY 
   { ImportNames ($1, $2 @ [Right $3], $4) }

/*(* also valid for export *)*/
from_clause: T_FROM module_specifier { ($1, $2) }

import_specifier:
 | binding_identifier                 { $1, None }
 | identifier T_AS binding_identifier { $1, Some ($2, $3) }
 /*(* not in ECMA, not sure what it means *)*/
 | T_DEFAULT T_AS binding_identifier  { ("default",$1), Some ($2, $3) }
 | T_DEFAULT  { ("default",$1), None }

module_specifier: string_literal { $1 }

/*(*----------------------------*)*/
/*(*2 export *)*/
/*(*----------------------------*)*/

export_declaration:
 | T_EXPORT export_names       { $1, $2 }
 | T_EXPORT variable_statement { $1, ExportDecl (St $2) }
 | T_EXPORT declaration        { $1, ExportDecl $2 }
 /*(* in theory just func/gen/class, no lexical_decl *)*/
 | T_EXPORT T_DEFAULT declaration { $1, ExportDefaultDecl ($2, $3) }
 | T_EXPORT T_DEFAULT assignment_expression_no_statement semicolon 
    { $1, ExportDefaultExpr ($2, $3, $4)  }
 /*(* ugly hack because should use assignment_expression above instead*)*/
 | T_EXPORT T_DEFAULT object_literal semicolon
    { $1, ExportDefaultExpr ($2, Object $3, $4)  }


export_names:
 | T_MULT        from_clause semicolon { ReExportNamespace ($1, $2, $3) }
 | export_clause from_clause semicolon { ReExportNames ($1, $2, $3) }
 | export_clause semicolon { ExportNames ($1, $2) }

export_clause:
 | T_LCURLY T_RCURLY 
   { ($1, [], $2) }
 | T_LCURLY import_specifiers          T_RCURLY 
   { ($1, $2, $3) }
 | T_LCURLY import_specifiers T_COMMA  T_RCURLY 
   { ($1, $2 @ [Right $3], $4) }

/*(*************************************************************************)*/
/*(*1 Declare (ambient) *)*/
/*(*************************************************************************)*/
/*(* typescript: *)*/

/*(*************************************************************************)*/
/*(*1 Statement *)*/
/*(*************************************************************************)*/

statement:
 | block                { $1 }
 | variable_statement   { $1 }
 | empty_statement      { $1 }
 | expression_statement { $1 }
 | if_statement         { $1 }
 | iteration_statement  { $1 }
 | continue_statement   { $1 }
 | break_statement      { $1 }
 | return_statement     { $1 }
 | with_statement       { $1 }
 | labelled_statement   { $1 }
 | switch_statement     { $1 }
 | throw_statement      { $1 }
 | try_statement        { $1 }


block:
 | T_LCURLY statement_list T_RCURLY { Block ($1, $2, $3) }
 | T_LCURLY T_RCURLY                { Block ($1, [], $2) }

statement_list:
 | item { [$1] }
 | statement_list item { $1 @ [$2] }


empty_statement:
 | semicolon { Nop $1 }

expression_statement:
 | expression_no_statement semicolon { ExprStmt ($1, $2) }


if_statement:
 | T_IF T_LPAREN expression T_RPAREN statement T_ELSE statement
     { If ($1, ($2, $3, $4), $5, Some ($6, $7)) }
 | T_IF T_LPAREN expression T_RPAREN statement %prec p_IF
     { If ($1, ($2, $3, $4), $5, None) }


iteration_statement:
 | T_DO statement T_WHILE T_LPAREN expression T_RPAREN semicolon
     { Do ($1, $2, $3, ($4, $5, $6), $7) }
 | T_WHILE T_LPAREN expression T_RPAREN statement
     { While ($1, ($2, $3, $4), $5) }

 | T_FOR T_LPAREN
     expression_no_in_opt T_SEMICOLON
     expression_opt T_SEMICOLON
     expression_opt
     T_RPAREN statement
     { For ($1, $2, $3|>Common2.fmap (fun x -> LHS1 x), $4, $5, $6, $7,$8,$9)}
 | T_FOR T_LPAREN
     for_variable_declaration T_SEMICOLON
     expression_opt T_SEMICOLON
     expression_opt
     T_RPAREN statement
     { For ($1, $2, Some (ForVars $3), $4, $5, $6, $7, $8, $9) }

 | T_FOR T_LPAREN left_hand_side_expression T_IN expression T_RPAREN statement
     { ForIn ($1, $2, LHS2 $3, $4, $5, $6, $7) }
 | T_FOR T_LPAREN for_single_variable_decl T_IN expression T_RPAREN  statement
     { ForIn ($1, $2, ForVar $3, $4, $5, $6, $7) }
 | T_FOR T_LPAREN left_hand_side_expression T_OF assignment_expression 
         T_RPAREN statement
     { ForOf ($1, $2, LHS2 $3, $4, $5, $6, $7) }
 | T_FOR T_LPAREN for_single_variable_decl T_OF assignment_expression
        T_RPAREN  statement
     { ForOf ($1, $2, ForVar $3, $4, $5, $6, $7) }


initializer_no_in:
 | T_ASSIGN assignment_expression_no_in { $1, $2 }


continue_statement:
 | T_CONTINUE identifier semicolon { Continue ($1, Some $2, $3) }
 | T_CONTINUE semicolon            { Continue ($1, None, $2) }

break_statement:
 | T_BREAK identifier semicolon { Break ($1, Some $2, $3) }
 | T_BREAK semicolon            { Break ($1, None, $2) }


return_statement:
 | T_RETURN expression semicolon { Return ($1, Some $2, $3) }
 | T_RETURN semicolon            { Return ($1, None, $2) }


with_statement:
 | T_WITH T_LPAREN expression T_RPAREN statement { With ($1, ($2, $3, $4), $5) }


switch_statement:
 | T_SWITCH T_LPAREN expression T_RPAREN case_block { Switch ($1, ($2, $3, $4), $5) }



labelled_statement:
 | identifier T_COLON statement { Labeled ($1, $2, $3) }


throw_statement:
 | T_THROW expression semicolon { Throw ($1, $2, $3) }

try_statement:
 | T_TRY block catch         { Try ($1, $2, Some $3, None)  }
 | T_TRY block       finally { Try ($1, $2, None, Some $3) }
 | T_TRY block catch finally { Try ($1, $2, Some $3, Some $4) }

catch:
 | T_CATCH T_LPAREN identifier T_RPAREN block { $1, ($2, $3, $4), $5 }

finally:
 | T_FINALLY block { $1, $2 }

/*(*----------------------------*)*/
/*(*2 auxillary statements *)*/
/*(*----------------------------*)*/

case_block:
 | T_LCURLY case_clauses_opt T_RCURLY
     { ($1, $2, $3) }
 | T_LCURLY case_clauses_opt default_clause case_clauses_opt T_RCURLY
     { ($1, $2 @ [$3] @ $4, $5) }

case_clause:
 | T_CASE expression T_COLON statement_list { Case ($1, $2, $3, $4) }
 | T_CASE expression T_COLON { Case ($1, $2, $3, []) }

default_clause:
 | T_DEFAULT T_COLON { Default ($1, $2, [])}
 | T_DEFAULT T_COLON statement_list { Default ($1, $2, $3) }

/*(*************************************************************************)*/
/*(*1 Variable declaration *)*/
/*(*************************************************************************)*/

/*(* part of 'statement' *)*/
variable_statement:
 | T_VAR variable_declaration_list semicolon  { VarsDecl ((Var, $1), $2, $3) }

/*(* part of 'declaration' *)*/
lexical_declaration:
 /*(* es6: *)*/
 | T_CONST variable_declaration_list semicolon { VarsDecl((Const, $1), $2,$3) }
 | T_LET variable_declaration_list semicolon { VarsDecl((Let, $1), $2,$3) }


/*(* one var from a list of vars *)*/
variable_declaration:
 | identifier annotation_opt initializeur_opt
     { VarClassic { v_name = $1; v_type = $2; v_init = $3 } }
 | binding_pattern annotation_opt initializeur
     { VarPatternTodo }

initializeur:
 | T_ASSIGN assignment_expression { $1, $2 }



for_variable_declaration:
 | T_VAR variable_declaration_list_no_in   { ((Var, $1), $2) }
 /*(* es6: *)*/
 | T_CONST variable_declaration_list_no_in { ((Const, $1), $2) }
 | T_LET variable_declaration_list_no_in   { ((Let, $1), $2) }

variable_declaration_no_in:
 | identifier initializer_no_in
     { VarClassic { v_name = $1; v_init = Some $2; v_type =None } }
 | identifier
     { VarClassic { v_name = $1; v_init = None; v_type = None } }
 | binding_pattern initializer_no_in
     { VarPatternTodo }

/*(* 'for ... in' and 'for ... of' declare only one variable *)*/
for_single_variable_decl:
 | T_VAR for_binding { ((Var, $1), $2) }
 /*(* es6: *)*/
 | T_CONST for_binding { ((Const, $1), $2) }
 | T_LET for_binding   { ((Let, $1), $2) }

for_binding:
 | identifier annotation_opt 
   { VarClassic { v_name = $1; v_type = $2; v_init = None; } }
 | binding_pattern 
   { VarPatternTodo }

/*(*----------------------------*)*/
/*(*2 pattern *)*/
/*(*----------------------------*)*/

binding_pattern:
 | object_binding_pattern { }
 | array_binding_pattern { }

object_binding_pattern:
 | T_LCURLY T_RCURLY { }
 | T_LCURLY binding_property_list trailing_comma  T_RCURLY { }

binding_property_list:
 | binding_property                                { [Left $1]  }
 | binding_property_list T_COMMA binding_property  { $1 @ [Right $2; Left $3] }


binding_property:
 | binding_identifier initializeur_opt { }
 | property_name T_COLON binding_element { }
 /*(* can appear only at the end of a binding_property_list in ECMA *)*/
 | T_DOTS binding_identifier { }
 | T_DOTS binding_pattern { }

/*(* in theory used also for formal parameter as is *)*/
binding_element:
 | binding_identifier initializeur_opt { }
 | binding_pattern initializeur_opt { }


array_binding_pattern:
 | T_LBRACKET binding_element_list T_RBRACKET { }

binding_element_list:
 | binding_elision_element { }
 | binding_element_list T_COMMA binding_elision_element { }

binding_elision_element:
 |         binding_element { }
 | elision binding_element { }
 /*(* can appear only at the end of a binding_property_list in ECMA *)*/
 | T_DOTS binding_identifier { }
 | T_DOTS binding_pattern { }

/*(*************************************************************************)*/
/*(*1 Function declarations (and expressions) *)*/
/*(*************************************************************************)*/

/*(* ugly: f_name is None only when part of an 'export default' decl 
   * TODO: use other tech to enforce this? extra rule after
   * T_EXPORT T_DEFAULT? but then many ambiguities.
   *)*/
function_declaration:
 | T_FUNCTION identifier_opt generics_opt
     T_LPAREN formal_parameter_list_opt T_RPAREN
     annotation_opt
     T_LCURLY function_body T_RCURLY
     { { f_kind = Regular; f_tok = Some $1; f_name= $2; 
         f_type_params = $3; f_params= ($4, $5, $6); 
         f_return_type = $7; f_body = ($8, $9, $10)
     } }

/*(* the identifier is optional here *)*/
function_expression:
 | T_FUNCTION identifier_opt generics_opt
     T_LPAREN formal_parameter_list_opt T_RPAREN
     annotation_opt
     T_LCURLY function_body T_RCURLY
     { { f_kind = Regular; f_tok = Some $1; f_name= $2; 
                    f_type_params = $3; f_params= ($4, $5, $6);
                    f_return_type = $7; f_body = ($8, $9, $10) } }

function_body:
 | /*(* empty *)*/ { [] }
 | statement_list  { $1 }

/*(*----------------------------*)*/
/*(*2 parameters *)*/
/*(*----------------------------*)*/

formal_parameter_list_opt:
 | /*(*empty*)*/   { [] }
 | formal_parameter_list trailing_comma2  { List.rev ($2 @ $1)  }

/*(* must be written in a left-recursive way (see conflicts.txt) *)*/
formal_parameter_list:
 | formal_parameter_list T_COMMA formal_parameter { (Left $3)::(Right $2)::$1 }
 | formal_parameter                               { [Left $1] }

/*(* The ECMA grammar imposes more restrictions, but I simplified.
   *  We could also factorize with binding_element as done by ECMA.
   *)*/
formal_parameter:
 | identifier            
   { ParamClassic (mk_param $1) }
 /*(* es6: default parameter *)*/
 | identifier initializeur
    { let (tok,e) = $2 in ParamClassic 
      { (mk_param $1) with p_default = Some(DSome(tok,e)); } }
  /*(* until here this is mostly equivalent to the 'binding_element' rule *)*/
  | binding_pattern initializeur_opt { ParamPatternTodo }

 /*(* es6: spread *)*/
 | T_DOTS identifier 
    { ParamClassic { (mk_param $2) with p_dots = Some $1; } }

 /*(* typing-ext: *)*/
 | identifier annotation 
    { ParamClassic { (mk_param $1) with p_type = Some $2; } }
 | identifier T_PLING
     { ParamClassic { (mk_param $1) with p_default = Some(DNone $2); } }
 | identifier T_PLING annotation
     { ParamClassic { (mk_param $1) with 
                     p_type = Some $3; p_default = Some(DNone $2); } }
 | identifier annotation initializeur
     { let (tok,e) = $3 in ParamClassic 
       { (mk_param $1) with 
         p_type = Some $2; p_default = Some(DSome(tok,e)); } }
 | T_DOTS identifier annotation
     { ParamClassic { (mk_param $2) 
                      with p_dots = Some $1; p_type = Some $3; } }


/*(*----------------------------*)*/
/*(*2 generators *)*/
/*(*----------------------------*)*/
/*(* TODO: identifier_opt in original grammar, why? *)*/
generator_declaration:
 | T_FUNCTION T_MULT identifier generics_opt
     T_LPAREN formal_parameter_list_opt T_RPAREN
     annotation_opt
     T_LCURLY function_body T_RCURLY
     { { f_kind = Generator $2; f_tok = Some $1; f_name= Some $3; 
         f_type_params = $4; f_params= ($5, $6, $7); 
         f_return_type = $8; f_body = ($9, $10, $11)
     } }

/*(* the identifier is optional here *)*/
generator_expression:
 | T_FUNCTION T_MULT identifier_opt generics_opt
     T_LPAREN formal_parameter_list_opt T_RPAREN
     annotation_opt
     T_LCURLY function_body T_RCURLY
     { e(Function { f_kind = Generator $2; f_tok = Some $1; f_name= $3; 
                    f_type_params = $4; f_params= ($5, $6, $7);
                    f_return_type = $8; f_body = ($9, $10, $11) }) }

/*(*----------------------------*)*/
/*(*2 asynchronous functions *)*/
/*(*----------------------------*)*/
/*(* TODO: identifier_opt in original grammar, why? *)*/
async_declaration:
 | T_ASYNC T_FUNCTION identifier generics_opt
     T_LPAREN formal_parameter_list_opt T_RPAREN
     annotation_opt
     T_LCURLY function_body T_RCURLY
     { { f_kind = Async $1; f_tok = Some $2; f_name= Some $3; 
         f_type_params = $4; f_params= ($5, $6, $7); 
         f_return_type = $8; f_body = ($9, $10, $11)
     } }

/*(* the identifier is optional here *)*/
async_function_expression:
 | T_ASYNC T_FUNCTION identifier_opt generics_opt
     T_LPAREN formal_parameter_list_opt T_RPAREN
     annotation_opt
     T_LCURLY function_body T_RCURLY
     { e(Function { f_kind = Async $1; f_tok = Some $2; f_name= $3; 
                    f_type_params = $4; f_params= ($5, $6, $7);
                    f_return_type = $8; f_body = ($9, $10, $11) }) }

/*(*----------------------------*)*/
/*(*2 Method definition (in class or object literal) *)*/
/*(*----------------------------*)*/
method_definition:
 | method_name generics_opt 
    T_LPAREN formal_parameter_list_opt T_RPAREN annotation_opt
    T_LCURLY function_body T_RCURLY
  { { f_kind = Regular; f_tok = None; f_name = Some $1; 
      f_type_params = $2; f_params = ($3, $4, $5);
      f_return_type = $6; f_body =  ($7, $8, $9);
  } }

 | T_MULT identifier generics_opt 
    T_LPAREN formal_parameter_list_opt T_RPAREN annotation_opt
    T_LCURLY function_body T_RCURLY
  { { f_kind = Generator $1; f_tok = None; f_name = Some $2; 
      f_type_params = $3; f_params = ($4, $5, $6);
      f_return_type = $7; f_body =  ($8, $9, $10);
  } }

 | T_GET identifier generics_opt 
    T_LPAREN T_RPAREN annotation_opt
    T_LCURLY function_body T_RCURLY
  { { f_kind = Get $1; f_tok = None; f_name = Some $2; 
      f_type_params = $3; f_params = ($4, [], $5);
      f_return_type = $6; f_body =  ($7, $8, $9);
  } }

 | T_SET identifier generics_opt 
    T_LPAREN formal_parameter T_RPAREN annotation_opt
    T_LCURLY function_body T_RCURLY
  { { f_kind = Set $1; f_tok = None; f_name = Some $2; 
      f_type_params = $3; f_params = ($4, [Left $5], $6);
      f_return_type = $7; f_body =  ($8, $9, $10);
  } }

 /*(* es7: *)*/
 | T_ASYNC identifier generics_opt 
    T_LPAREN formal_parameter_list_opt T_RPAREN annotation_opt
    T_LCURLY function_body T_RCURLY
  { { f_kind = Async $1; f_tok = None; f_name = Some $2; 
      f_type_params = $3; f_params = ($4, $5, $6);
      f_return_type = $7; f_body =  ($8, $9, $10);
  } }

/*(*************************************************************************)*/
/*(*1 Class declaration *)*/
/*(*************************************************************************)*/

/*(* ugly: c_name is None only when part of an 'export default' decl 
   * TODO: use other tech to enforce this? extra rule after
   * T_EXPORT T_DEFAULT? but then many ambiguities.
   *)*/
class_declaration: T_CLASS binding_identifier_opt generics_opt class_tail
   { let (extends, body) = $4 in
     { c_tok = $1; c_name = $2; c_type_params = $3;
       c_extends =extends; c_body = body }
   }

class_tail: class_heritage_opt T_LCURLY class_body_opt T_RCURLY {$1,($2,$3,$4)}

class_heritage: T_EXTENDS type_or_expression { ($1, $2) }

class_body: class_element_list { $1 }

binding_identifier: identifier { $1 }
binding_identifier_opt: 
 | { None } 
 | binding_identifier { Some $1 }


class_expression: T_CLASS binding_identifier_opt generics_opt class_tail
   { let (extends, body) = $4 in
     e(Class { c_tok = $1;  c_name = $2; c_type_params = $3;
               c_extends =extends;c_body = body }) }

/*(*----------------------------*)*/
/*(*2 Class elements *)*/
/*(*----------------------------*)*/

/*(* can't factorize with static_opt, or access_modifier_opt; ambiguities*)*/
class_element:
 |                 method_definition      { Method (None, $1) }
 | T_STATIC        method_definition      { Method (Some $1, $2) }
 | access_modifier method_definition      { Method (None, $2) (* TODO $1 *) }

 | semicolon                       { ClassExtraSemiColon $1 }
 /*(* TODO: not part of ECMA *)*/
 | identifier annotation semicolon { Field ($1, $2, $3) }

access_modifier:
 | T_PUBLIC { }
 | T_PRIVATE { }
 | T_PROTECTED { }

/*(*************************************************************************)*/
/*(*1 Interface declaration *)*/
/*(*************************************************************************)*/
/*(* typescript: *)*/
/* TODO: use type_ at the end here and you get conflicts on '[' 
 * Why? because [] can follow an interface_declaration?
*/
interface_declaration: T_INTERFACE binding_identifier generics_opt 
  interface_extends_opt object_type
   { { i_tok = $1;i_name = $2; (* TODO: interface_extends! *)
       i_type_params = $3; i_type = $5; } }

interface_extends: T_EXTENDS type_reference_list { ($1, $2) }

/*(*************************************************************************)*/
/*(*1 Type declaration *)*/
/*(*************************************************************************)*/
/*(* typescript: *)*/
type_alias_declaration: T_TYPE identifier T_ASSIGN type_ semicolon { }

/*(*************************************************************************)*/
/*(*1 Types *)*/
/*(*************************************************************************)*/
/*(* typescript: *)*/

/*(*----------------------------*)*/
/*(*2 Annotations *)*/
/*(*----------------------------*)*/

annotation: T_COLON type_ { TAnnot($1, $2) }

complex_annotation:
 | annotation { $1 }
 | generics_opt T_LPAREN param_type_list_opt T_RPAREN T_COLON type_
     { TFunAnnot($1,($2,$3,$4),$5,$6) }

/*(*----------------------------*)*/
/*(*2 Types *)*/
/*(*----------------------------*)*/

/*(* can't use 'type'; generate syntax error in parser_js.ml *)*/
type_:
 | primary_or_union_type { $1 }
 | T_PLING type_ { TQuestion ($1, $2) }
 | T_LPAREN_ARROW param_type_list_opt T_RPAREN T_ARROW type_
     { TFun (($1, $2, $3), $4, $5) }

primary_or_union_type:
 | primary_type { $1 }
 | union_type { $1 }

/*(* I introduced those intermediate rules to remove ambiguities *)*/
primary_type:
 | primary_type2 { $1 }
 | primary_type T_LBRACKET T_RBRACKET { TTodo }

primary_type2:
 | predefined_type { $1 }
 | type_reference { TName($1) }
 | object_type { $1 }

predefined_type:
 | T_ANY_TYPE      { TName (V("any", $1), None) }
 | T_NUMBER_TYPE   { TName (V("number", $1), None) }
 | T_BOOLEAN_TYPE  { TName (V("boolean", $1), None) }
 | T_STRING_TYPE   { TName (V("string", $1), None) }
 | T_VOID          { TName (V("void", $1), None) }
 /*(* not in Typescript grammar, but often part of union type *)*/
 | T_NULL          { TName (V("null", $1), None) }

/*(* was called nominal_type in Flow *)*/
type_reference:
 | type_name { ($1,None) }
 | type_name type_arguments { ($1, Some $2) }

/*(* was called type_reference in Flow *)*/
type_name: 
 | T_IDENTIFIER { V($1) }
 | module_name T_PERIOD T_IDENTIFIER { V($3) }

module_name:
 | T_IDENTIFIER { V($1) }
 | module_name T_PERIOD T_IDENTIFIER { V($3) (* TODO: $1 *) } 

union_type: primary_or_union_type T_BIT_OR primary_type { TTodo }


object_type: T_LCURLY type_member_list_opt T_RCURLY  { TObj ($1, $2, $3) } 

/*(* partial type annotations are not supported *)*/
type_member: 
 | property_name_typescript complex_annotation semicolon 
    { ($1, $2, $3) }
 | property_name_typescript T_PLING complex_annotation semicolon 
    { ($1, $3, $4) (* TODO $2*) }
 | T_LBRACKET T_IDENTIFIER T_COLON T_STRING_TYPE T_RBRACKET 
   complex_annotation semicolon
    { (* TODO *) (PN_Id $2, $6, $7)  }
 | T_LBRACKET T_IDENTIFIER T_COLON T_NUMBER_TYPE T_RBRACKET 
   complex_annotation semicolon
    { (* TODO *) (PN_Id $2, $6, $7) }

/*(* no [xxx] here *)*/
property_name_typescript:
 | identifier    { PN_Id $1 }
 | string_literal  { PN_String $1 }
 | numeric_literal { PN_Num $1 }
 | ident_keyword   { PN_Id $1 }


param_type_list:
 | param_type T_COMMA param_type_list { (Left $1)::(Right $2)::$3 }
 | param_type                         { [Left $1] }
 | optional_param_type_list           { $1 }

/*(* partial type annotations are not supported *)*/
param_type: identifier complex_annotation
  { (RequiredParam($1), $2) }

optional_param_type: identifier T_PLING complex_annotation
  { (OptionalParam($1,$2), $3) }

optional_param_type_list:
 | optional_param_type T_COMMA optional_param_type_list
     { (Left $1)::(Right $2)::$3 }
 | optional_param_type       { [Left $1] }
 | rest_param_type           { [Left $1] }

rest_param_type: T_DOTS identifier complex_annotation
  { (RestParam($1,$2), $3) }


/*(*----------------------------*)*/
/*(*2 Type parameters (type variables) *)*/
/*(*----------------------------*)*/

generics:
 | T_LESS_THAN type_parameter_list T_GREATER_THAN { $1, $2, $3 }

type_parameter_list:
 | type_parameter                            { [Left $1] }
 | type_parameter_list T_COMMA type_parameter { $1 @ [Right $2; Left $3] }

type_parameter:
 | T_IDENTIFIER { $1 }

/*(*----------------------------*)*/
/*(*2 Type arguments *)*/
/*(*----------------------------*)*/

type_arguments:
 | T_LESS_THAN type_argument_list T_GREATER_THAN { $1, $2, $3 }
 | mismatched_type_arguments { $1 }

type_argument_list:
 | type_argument                            { [Left $1] }
 | type_argument_list T_COMMA type_argument { $1 @ [Right $2; Left $3] }

type_argument: type_ { $1 }

/*(* a sequence of 2 or 3 closing > will be tokenized as >> or >>> *)*/
/*(* thus, we allow type arguments to omit 1 or 2 closing > to make it up *)*/
mismatched_type_arguments:
 | T_LESS_THAN type_argument_list1 T_RSHIFT { $1, $2, $3 }
 | T_LESS_THAN type_argument_list2 T_RSHIFT3 { $1, $2, $3 }

type_argument_list1:
 | nominal_type1                            { [Left (TName $1)] }
 | type_argument_list T_COMMA nominal_type1 { $1 @ [Right $2; Left (TName $3)] }

nominal_type1:
 | type_name type_arguments1 { ($1, Some $2) }

/*(* missing 1 closing > *)*/
type_arguments1:
 | T_LESS_THAN type_argument_list { $1, $2, fake_tok ">" }

type_argument_list2:
 | nominal_type2                            { [Left (TName $1)] }
 | type_argument_list T_COMMA nominal_type2 { $1 @ [Right $2; Left (TName $3)] }

nominal_type2:
 | type_name type_arguments2 { ($1, Some $2) }

/*(* missing 2 closing > *)*/
type_arguments2:
 | T_LESS_THAN type_argument_list1 { $1, $2, fake_tok ">" }

/*(*----------------------------*)*/
/*(*2 Type or expression *)*/
/*(*----------------------------*)*/

/*(* Extends arguments can be any expression according to ES6 *)*/
/*(* however, this causes ambiguities with type arguments a la TypeScript *)*/
/*(* unfortunately, TypeScript enforces severe restrictions here, *)*/
/*(* which e.g. do not admit mixins, which we want to support *)*/
/*(* TODO ambiguity Xxx.yyy, a Period expr or a module path in TypeScript *)*/
type_or_expression:
/* old: flow: 
 | left_hand_side_expression_no_statement { ($1,None) } 
 | type_name type_arguments { ($1, Some $2) }
*/
 /*(* typescript: *)*/
 | type_reference { $1 }

/*(*************************************************************************)*/
/*(*1 Expressions *)*/
/*(*************************************************************************)*/

expression:
 | assignment_expression { $1 }
 | expression T_COMMA assignment_expression { e(Seq ($1, $2, $3)) }

assignment_expression:
 | conditional_expression { $1 }
 | left_hand_side_expression assignment_operator assignment_expression
     { e(Assign ($1, $2, $3)) }
 /*(* es6: *)*/
 | arrow_function { Arrow $1 }
 /*(* es6: *)*/
 | T_YIELD                               { Yield ($1, None, None) }
 | T_YIELD assignment_expression         { Yield ($1, None, Some $2) }
 | T_YIELD T_MULT assignment_expression  { Yield ($1, Some $2, Some $3) }
 /*(* es7: *)*/
 | async_arrow_function { Arrow $1 }

assignment_operator:
 | T_ASSIGN         { A_eq , $1 }
 | T_MULT_ASSIGN    { A_mul, $1 }
 | T_DIV_ASSIGN     { A_div, $1 }
 | T_MOD_ASSIGN     { A_mod, $1 }
 | T_PLUS_ASSIGN    { A_add, $1 }
 | T_MINUS_ASSIGN   { A_sub, $1 }
 | T_LSHIFT_ASSIGN  { A_lsl, $1 }
 | T_RSHIFT_ASSIGN  { A_lsr, $1 }
 | T_RSHIFT3_ASSIGN { A_asr, $1 }
 | T_BIT_AND_ASSIGN { A_and, $1 }
 | T_BIT_XOR_ASSIGN { A_xor, $1 }
 | T_BIT_OR_ASSIGN  { A_or , $1 }

left_hand_side_expression:
 | new_expression  { $1 }
 | call_expression { $1 }

conditional_expression:
 | post_in_expression { $1 }
 | post_in_expression
     T_PLING assignment_expression
     T_COLON assignment_expression
     { e(Conditional ($1, $2, $3, $4, $5)) }

post_in_expression:
 | pre_in_expression { $1 }
 | post_in_expression T_LESS_THAN post_in_expression          { bop B_lt $1 $2 $3 }
 | post_in_expression T_GREATER_THAN post_in_expression       { bop B_gt $1 $2 $3 }
 | post_in_expression T_LESS_THAN_EQUAL post_in_expression    { bop B_le $1 $2 $3 }
 | post_in_expression T_GREATER_THAN_EQUAL post_in_expression { bop B_ge $1 $2 $3 }
 | post_in_expression T_INSTANCEOF post_in_expression         { bop B_instanceof $1 $2 $3 }
 | post_in_expression T_IN post_in_expression                 { bop B_in $1 $2 $3 }
 | post_in_expression T_EQUAL post_in_expression              { bop B_equal $1 $2 $3 }
 | post_in_expression T_NOT_EQUAL post_in_expression          { bop B_notequal $1 $2 $3 }
 | post_in_expression T_STRICT_EQUAL post_in_expression       { bop B_physequal $1 $2 $3 }
 | post_in_expression T_STRICT_NOT_EQUAL post_in_expression   { bop B_physnotequal $1 $2 $3 }
 | post_in_expression T_BIT_AND post_in_expression            { bop B_bitand $1 $2 $3 }
 | post_in_expression T_BIT_XOR post_in_expression            { bop B_bitxor $1 $2 $3 }
 | post_in_expression T_BIT_OR post_in_expression             { bop B_bitor $1 $2 $3 }
 | post_in_expression T_AND post_in_expression                { bop B_and $1 $2 $3 }
 | post_in_expression T_OR post_in_expression                 { bop B_or $1 $2 $3 }

/*(* called unary_expression and update_expression in ECMA *)*/
/*(* coupling: modify also pre_in_expression_no_statement *)*/
pre_in_expression:
 | left_hand_side_expression                     { $1 }

 | pre_in_expression T_INCR %prec p_POSTFIX      { uop U_post_increment $2 $1 }
 | pre_in_expression T_DECR %prec p_POSTFIX      { uop U_post_decrement $2 $1 }
 | T_INCR pre_in_expression                      { uop U_pre_increment $1 $2 }
 | T_DECR pre_in_expression                      { uop U_pre_decrement $1 $2 }

 | T_DELETE pre_in_expression                    { uop U_delete $1 $2 }
 | T_VOID pre_in_expression                      { uop U_void $1 $2 }
 | T_TYPEOF pre_in_expression                    { uop U_typeof $1 $2 }

 | T_PLUS pre_in_expression                      { uop U_plus $1 $2 }
 | T_MINUS pre_in_expression                     { uop U_minus $1 $2}
 | T_BIT_NOT pre_in_expression                   { uop U_bitnot $1 $2 }
 | T_NOT pre_in_expression                       { uop U_not $1 $2 }
 /*(* es7: *)*/
 | T_AWAIT pre_in_expression                     { Await ($1, $2) }

 | pre_in_expression T_MULT pre_in_expression    { bop B_mul $1 $2 $3 }
 | pre_in_expression T_DIV pre_in_expression     { bop B_div $1 $2 $3 }
 | pre_in_expression T_MOD pre_in_expression     { bop B_mod $1 $2 $3 }
 | pre_in_expression T_PLUS pre_in_expression    { bop B_add $1 $2 $3 }
 | pre_in_expression T_MINUS pre_in_expression   { bop B_sub $1 $2 $3 }
 | pre_in_expression T_LSHIFT pre_in_expression  { bop B_lsl $1 $2 $3 }
 | pre_in_expression T_RSHIFT pre_in_expression  { bop B_lsr $1 $2 $3 }
 | pre_in_expression T_RSHIFT3 pre_in_expression { bop B_asr $1 $2 $3 }

 /*(* es7: *)*/
 | pre_in_expression T_EXPONENT pre_in_expression { bop B_expo $1 $2 $3 }

/*(* coupling: modify also call_expression_no_statement *)*/
call_expression:
 | member_expression arguments                      { e(Apply ($1, $2)) }
 | call_expression arguments                        { e(Apply ($1, $2)) }
 | call_expression T_LBRACKET expression T_RBRACKET { e(Bracket($1, ($2, $3, $4))) }
 | call_expression T_PERIOD method_name              { e(Period ($1, $2, $3)) }
 /*(* es6: *)*/
 | T_SUPER arguments { e(Apply(Super($1), $2)) }

new_expression:
 | member_expression    { $1 }
 | T_NEW new_expression { uop U_new $1 $2 }

/*(* coupling: modify also member_expression_no_statement *)*/
member_expression:
 | primary_expression                                 { $1 }
 | member_expression T_LBRACKET expression T_RBRACKET { e(Bracket($1, ($2, $3, $4))) }
 | member_expression T_PERIOD field_name              { e(Period ($1, $2, $3)) }
 | T_NEW member_expression arguments
     { e(Apply(uop U_new $1 $2, $3)) }
 /*(* es6: *)*/
 | T_SUPER T_LBRACKET expression T_RBRACKET { e(Bracket(Super($1),($2,$3,$4)))}
 | T_SUPER T_PERIOD field_name { e(Period(Super($1), $2, $3)) }
 | T_NEW T_PERIOD identifier { 
     if fst $3 = "target"
     then e(NewTarget ($1, $2, snd $3))
     else raise (Parsing.Parse_error)
  }


primary_expression:
 | primary_expression_no_braces { $1 }
 | object_literal                  { e(Object $1) }
 | function_expression             { e(Function $1) }
 /*(* es6: *)*/
 | class_expression                { $1 }
 /*(* es6: *)*/
 | generator_expression            { $1 }
 /*(* es7: *)*/
 | async_function_expression            { $1 }

primary_expression_no_braces:
 | T_THIS          { e((This $1)) }
 | identifier      { e((V $1)) }

 | null_literal    { e(L(Null $1)) }
 | boolean_literal { e(L(Bool $1)) }
 | numeric_literal { e(L(Num $1)) }
 | string_literal  { e(L(String $1)) }

 /*(* marcel: this isn't an expansion of literal in ECMA-262... mistake? *)*/
 | regex_literal                { e(L(Regexp $1)) }
 | array_literal                { e($1) }

 /*(* simple! ECMA mixes this rule with arrow parameters (bad) *)*/
 | T_LPAREN expression T_RPAREN { e(Paren ($1, $2, $3)) }

 /*(* xhp: do not put in 'expr', otherwise can't have xhp in function arg *)*/
 | xhp_html { XhpHtml $1 }

 /*(* templated string (aka interpolated strings) *)*/
 | T_BACKQUOTE encaps_list_opt T_BACKQUOTE
     { Encaps (None, $1, $2, $3) }
 | identifier T_BACKQUOTE encaps_list_opt T_BACKQUOTE
     { Encaps (Some $1, $2, $3, $4) }

/*(*----------------------------*)*/
/*(*2 scalar *)*/
/*(*----------------------------*)*/
null_literal:
 | T_NULL { $1 }

boolean_literal:
 | T_TRUE  { true, $1 }
 | T_FALSE { false, $1 }

numeric_literal:
 | T_NUMBER { $1 }

regex_literal:
 | T_REGEX { $1 }

string_literal:
 | T_STRING { $1 }

/*(*----------------------------*)*/
/*(*2 array *)*/
/*(*----------------------------*)*/

array_literal:
 | T_LBRACKET elision_opt T_RBRACKET              
   { Array($1, $2, $3) }
 | T_LBRACKET element_list_rev elision_opt T_RBRACKET 
   { Array($1, List.rev $2 @ $3, $4) }

/*(* TODO: conflict on T_COMMA *)*/
element_list_rev:
 | elision_opt   element                { (Left $2)::$1 }
 | element_list_rev T_COMMA element     { (Left $3) :: [Right $2] @ $1 }
 | element_list_rev T_COMMA elision element     { (Left $4) :: $3 @ [Right $2] @ $1 }

element:
 | assignment_expression { $1 }
 /*(* es6: spread operator: *)*/
 | T_DOTS assignment_expression
     { e(uop U_spread $1 $2) }

/*(*----------------------------*)*/
/*(*2 object *)*/
/*(*----------------------------*)*/

object_literal:
 | T_LCURLY T_RCURLY
     { ($1, [], $2) }
 | T_LCURLY property_name_and_value_list trailing_comma T_RCURLY
     { ($1, $2 @ $3, $4) }


property_name_and_value:
 | property_name T_COLON assignment_expression
     { Left (P_field ($1, $2, $3)) }
 | method_definition
     { Left (P_method ($1)) }
 /*(* es6: *)*/
 | identifier
     { Left (P_shorthand ($1)) }
 /*(* es6: spread operator: *)*/
 | T_DOTS assignment_expression
     { Left (P_spread ($1, $2)) }

property_name_and_value_list:
 | property_name_and_value     
     { [$1] }
 | property_name_and_value_list T_COMMA  property_name_and_value
     { $1 @ [Right $2; $3] }

/*(*----------------------------*)*/
/*(*2 function call *)*/
/*(*----------------------------*)*/

arguments: T_LPAREN argument_list_opt T_RPAREN { ($1, $2 , $3) }

argument_list_opt:
 | /*(*empty*)*/   { [] }
 | argument_list trailing_comma3  { List.rev ($2 @ $1)  }

/*(* must be written in a left-recursive way (see conflicts.txt) *)*/
argument_list:
 | argument                         { [Left $1] }
 | argument_list T_COMMA argument   { (Left $3)::(Right $2)::$1 }

/*(* assignment_expr because expr supports sequence of exprs with ',' *)*/
argument:
 | assignment_expression { $1 }
 /*(* es6: spread operator, allowed not only in last position *)*/
 | T_DOTS assignment_expression
     { (uop U_spread $1 $2) }

/*(*----------------------------*)*/
/*(*2 XHP embeded html *)*/
/*(*----------------------------*)*/
xhp_html:
 | T_XHP_OPEN_TAG xhp_attributes T_XHP_GT xhp_children T_XHP_CLOSE_TAG
     { Xhp ($1, $2, $3, $4, $5)  }
 | T_XHP_OPEN_TAG xhp_attributes T_XHP_SLASH_GT
     { XhpSingleton ($1, $2, $3) }

xhp_child:
 | T_XHP_TEXT           { XhpText $1 }
 | xhp_html             { XhpNested $1 }
 | T_LCURLY expression semicolon T_RCURLY
     { XhpExpr ($1, Some $2, $4) (*TODO$3*) }
 | T_LCURLY T_RCURLY
     { XhpExpr ($1, None , $2) (*TODO$3*) }

xhp_attribute:
 | T_XHP_ATTR T_ASSIGN xhp_attribute_value 
    { XhpAttrClassic ($1, $2, $3) }
 | T_LCURLY T_DOTS assignment_expression T_RCURLY 
    { XhpAttrSpread ($1, ($2, $3), $4) }

xhp_attribute_value:
 | T_STRING { XhpAttrString ($1) }
 | T_LCURLY expression semicolon T_RCURLY { XhpAttrExpr ($1, $2, $4)(*TODO$3*)}

/*(*----------------------------*)*/
/*(*2 interpolated strings *)*/
/*(*----------------------------*)*/
encaps:
 | T_ENCAPSED_STRING                  { EncapsString $1 }
 | T_DOLLARCURLY expression T_RCURLY  { EncapsExpr ($1, $2, $3) }

/*(*----------------------------*)*/
/*(*2 arrow (short lambda) *)*/
/*(*----------------------------*)*/

arrow_function:
 | identifier T_ARROW arrow_body
     { { a_params = ASingleParam (ParamClassic (mk_param $1)); 
         a_return_type = None; a_tok = $2; a_body = $3 } }

 /*(* can not factorize with TOPAR parameter_list TCPAR, see conflicts.txt *)*/
 | T_LPAREN_ARROW formal_parameter_list_opt T_RPAREN annotation_opt 
    T_ARROW arrow_body 
    { { a_params = AParams ($1, $2, $3); a_return_type = $4;
        a_tok = $5; a_body = $6; } }


/*(* was called consise body in spec *)*/
arrow_body:
 | block
     { match $1 with Block (a,b,c) -> ABody (a,b,c) | _ -> raise Impossible }
 /*(* see conflicts.txt for why the %prec *)*/
 | assignment_expression_no_statement %prec LOW_PRIORITY_RULE { AExpr $1 }
 /*(* ugly *)*/
 | function_expression { AExpr (Function $1) }

async_arrow_function: 
 | T_ASYNC arrow_function { $2 }

/*(*----------------------------*)*/
/*(*2 no in *)*/
/*(*----------------------------*)*/
expression_no_in:
 | assignment_expression_no_in { $1 }
 | expression_no_in T_COMMA assignment_expression_no_in { e(Seq ($1, $2, $3)) }

assignment_expression_no_in:
 | conditional_expression_no_in { $1 }
 | left_hand_side_expression assignment_operator assignment_expression_no_in
     { e(Assign ($1, $2, $3)) }

conditional_expression_no_in:
 | post_in_expression_no_in { $1 }
 | post_in_expression_no_in
     T_PLING assignment_expression_no_in
     T_COLON assignment_expression_no_in
     { e(Conditional ($1, $2, $3, $4, $5)) }

post_in_expression_no_in:
 | pre_in_expression { $1 }
 | post_in_expression_no_in T_LESS_THAN post_in_expression          { bop B_lt $1 $2 $3 }
 | post_in_expression_no_in T_GREATER_THAN post_in_expression       { bop B_gt $1 $2 $3 }
 | post_in_expression_no_in T_LESS_THAN_EQUAL post_in_expression    { bop B_le $1 $2 $3 }
 | post_in_expression_no_in T_GREATER_THAN_EQUAL post_in_expression { bop B_ge $1 $2 $3 }
 | post_in_expression_no_in T_INSTANCEOF post_in_expression         { bop B_instanceof $1 $2 $3 }
 /*(* no T_IN case *)*/
 | post_in_expression_no_in T_EQUAL post_in_expression              { bop B_equal $1 $2 $3 }
 | post_in_expression_no_in T_NOT_EQUAL post_in_expression          { bop B_notequal $1 $2 $3 }
 | post_in_expression_no_in T_STRICT_EQUAL post_in_expression       { bop B_physequal $1 $2 $3 }
 | post_in_expression_no_in T_STRICT_NOT_EQUAL post_in_expression   { bop B_physnotequal $1 $2 $3 }
 | post_in_expression_no_in T_BIT_AND post_in_expression            { bop B_bitand $1 $2 $3 }
 | post_in_expression_no_in T_BIT_XOR post_in_expression            { bop B_bitxor $1 $2 $3 }
 | post_in_expression_no_in T_BIT_OR post_in_expression             { bop B_bitor $1 $2 $3 }
 | post_in_expression_no_in T_AND post_in_expression                { bop B_and $1 $2 $3 }
 | post_in_expression_no_in T_OR post_in_expression                 { bop B_or $1 $2 $3 }


/*(*----------------------------*)*/
/*(*2 (no statement, and no object literal like { v: 1 }) *)*/
/*(*----------------------------*)*/
expression_no_statement:
 | assignment_expression_no_statement { $1 }
 | expression_no_statement T_COMMA assignment_expression { e(Seq ($1, $2, $3)) }

assignment_expression_no_statement:
 | conditional_expression_no_statement { $1 }
 | left_hand_side_expression_no_statement assignment_operator assignment_expression
     { e(Assign ($1, $2, $3)) }
 /*(* es6: *)*/
 | arrow_function { Arrow $1 }
 /*(* es6: *)*/
 | T_YIELD                               { Yield ($1, None, None) }
 | T_YIELD assignment_expression   { Yield ($1, None, Some $2) }
 | T_YIELD T_MULT assignment_expression { Yield ($1, Some $2, Some $3) }

left_hand_side_expression_no_statement:
 | new_expression_no_statement { $1 }
 | call_expression_no_statement { $1 }

conditional_expression_no_statement:
 | post_in_expression_no_statement { $1 }
 | post_in_expression_no_statement
     T_PLING assignment_expression
     T_COLON assignment_expression
     { e(Conditional ($1, $2, $3, $4, $5)) }



post_in_expression_no_statement:
 | pre_in_expression_no_statement { $1 }
 | post_in_expression_no_statement T_LESS_THAN post_in_expression          { bop B_lt $1 $2 $3 }
 | post_in_expression_no_statement T_GREATER_THAN post_in_expression       { bop B_gt $1 $2 $3 }
 | post_in_expression_no_statement T_LESS_THAN_EQUAL post_in_expression    { bop B_le $1 $2 $3 }
 | post_in_expression_no_statement T_GREATER_THAN_EQUAL post_in_expression { bop B_ge $1 $2 $3 }
 | post_in_expression_no_statement T_INSTANCEOF post_in_expression         { bop B_instanceof $1 $2 $3 }
 | post_in_expression_no_statement T_IN post_in_expression                 { bop B_in $1 $2 $3 }
 | post_in_expression_no_statement T_EQUAL post_in_expression              { bop B_equal $1 $2 $3 }
 | post_in_expression_no_statement T_NOT_EQUAL post_in_expression          { bop B_notequal $1 $2 $3 }
 | post_in_expression_no_statement T_STRICT_EQUAL post_in_expression       { bop B_physequal $1 $2 $3 }
 | post_in_expression_no_statement T_STRICT_NOT_EQUAL post_in_expression   { bop B_physnotequal $1 $2 $3 }
 | post_in_expression_no_statement T_BIT_AND post_in_expression            { bop B_bitand $1 $2 $3 }
 | post_in_expression_no_statement T_BIT_XOR post_in_expression            { bop B_bitxor $1 $2 $3 }
 | post_in_expression_no_statement T_BIT_OR post_in_expression             { bop B_bitor $1 $2 $3 }
 | post_in_expression_no_statement T_AND post_in_expression                { bop B_and $1 $2 $3 }
 | post_in_expression_no_statement T_OR post_in_expression                 { bop B_or $1 $2 $3 }


pre_in_expression_no_statement:
 | left_hand_side_expression_no_statement                     { $1 }
 | pre_in_expression_no_statement T_INCR                      { uop U_post_increment $2 $1 }
 | pre_in_expression_no_statement T_DECR                      { uop U_post_decrement $2 $1 }
 | T_INCR pre_in_expression                                   { uop U_pre_increment $1 $2 }
 | T_DECR pre_in_expression                                   { uop U_pre_decrement $1 $2 }

 | T_DELETE pre_in_expression                                 { uop U_delete $1 $2 }
 | T_VOID pre_in_expression                                   { uop U_void $1 $2 }
 | T_TYPEOF pre_in_expression                                 { uop U_typeof $1 $2 }


 | T_PLUS pre_in_expression                                   { uop U_plus $1 $2 }
 | T_MINUS pre_in_expression                                  { uop U_minus $1 $2}
 | T_BIT_NOT pre_in_expression                                { uop U_bitnot $1 $2 }
 | T_NOT pre_in_expression                                    { uop U_not $1 $2 }

 /*(* es7: *)*/
 | T_AWAIT pre_in_expression                     { Await ($1, $2) }

 | pre_in_expression_no_statement T_MULT pre_in_expression    { bop B_mul $1 $2 $3 }
 | pre_in_expression_no_statement T_DIV pre_in_expression     { bop B_div $1 $2 $3 }
 | pre_in_expression_no_statement T_MOD pre_in_expression     { bop B_mod $1 $2 $3 }
 | pre_in_expression_no_statement T_PLUS pre_in_expression    { bop B_add $1 $2 $3 }
 | pre_in_expression_no_statement T_MINUS pre_in_expression   { bop B_sub $1 $2 $3 }
 | pre_in_expression_no_statement T_LSHIFT pre_in_expression  { bop B_lsl $1 $2 $3 }
 | pre_in_expression_no_statement T_RSHIFT pre_in_expression  { bop B_lsr $1 $2 $3 }
 | pre_in_expression_no_statement T_RSHIFT3 pre_in_expression { bop B_asr $1 $2 $3 }

 /*(* es7: *)*/
 | pre_in_expression_no_statement T_EXPONENT pre_in_expression { bop B_expo $1 $2 $3 }


call_expression_no_statement:
 | member_expression_no_statement arguments                      { e(Apply ($1, $2)) }
 | call_expression_no_statement arguments                        { e(Apply ($1, $2)) }
 | call_expression_no_statement T_LBRACKET expression T_RBRACKET { e(Bracket($1, ($2, $3, $4))) }
 | call_expression_no_statement T_PERIOD method_name              { e(Period ($1, $2, $3)) }
 /*(* es6: *)*/
 | T_SUPER arguments { e(Apply(Super($1), $2)) }

new_expression_no_statement:
 | member_expression_no_statement { $1 }
 | T_NEW new_expression { uop U_new $1 $2 }

member_expression_no_statement:
 | primary_expression_no_statement                                 { $1 }
 | member_expression_no_statement T_LBRACKET expression T_RBRACKET { e(Bracket($1, ($2, $3, $4))) }
 | member_expression_no_statement T_PERIOD field_name              { e(Period ($1, $2, $3)) }
 | T_NEW member_expression arguments                               { e(Apply(uop U_new $1 $2, $3)) }
 /*(* es6: *)*/
 | T_SUPER T_LBRACKET expression T_RBRACKET { e(Bracket(Super($1),($2,$3,$4)))}
 | T_SUPER T_PERIOD field_name { e(Period(Super($1), $2, $3)) }

/*(* no object_literal here *)*/
primary_expression_no_statement:
 | primary_expression_no_braces { $1 }

/*(*************************************************************************)*/
/*(*1 Entities, names *)*/
/*(*************************************************************************)*/
/*(* used for entities, parameters, labels, etc. *)*/
identifier:
 | T_IDENTIFIER { $1 }
 | ident_semi_keyword { PI.str_of_info $1, $1 }

/*(* add here keywords which are not considered reserved by ECMA *)*/
ident_semi_keyword:
 | T_FROM { $1 } | T_AS   { $1 } | T_OF { $1 }
 | T_GET { $1 } | T_SET { $1 }
 | T_ASYNC { $1 }
 | T_IMPLEMENTS { $1 }
 | T_CONSTRUCTOR { $1 }
 | T_TYPE { $1 }
 | T_ANY_TYPE { $1 } | T_NUMBER_TYPE { $1 } | T_BOOLEAN_TYPE { $1 }
 | T_STRING_TYPE { $1 }
 | T_ENUM { $1 }
 | T_DECLARE { $1 }
 | T_MODULE { $1 }
 | T_PUBLIC { $1 } | T_PRIVATE { $1 } | T_PROTECTED { $1 }

/*(* TODO: would like to add T_IMPORT here, but cause conflicts *)*/

/*(*alt: use the _last_non_whitespace_like_token trick and look if
   * previous token was a period to return a T_IDENTFIER
   *)*/
ident_keyword: ident_keyword_bis { PI.str_of_info $1, $1 }

ident_keyword_bis:
 | T_FUNCTION { $1 } | T_CONST { $1 } | T_VAR { $1 } | T_LET { $1 }
 | T_IF { $1 } | T_ELSE { $1 }
 | T_WHILE { $1 } | T_FOR { $1 } | T_DO { $1 }
 | T_CONTINUE { $1 } | T_BREAK { $1 }
 | T_SWITCH { $1 } | T_CASE { $1 } | T_DEFAULT { $1 }
 | T_RETURN { $1 }
 | T_THROW { $1 } | T_TRY { $1 } | T_CATCH { $1 } | T_FINALLY { $1 }
 | T_YIELD { $1 } | T_AWAIT { $1 }
 | T_NEW { $1 } | T_IN { $1 } | T_INSTANCEOF { $1 } | T_DELETE { $1 }
 | T_THIS { $1 } | T_SUPER { $1 }
 | T_WITH { $1 }
 | T_NULL { $1 }
 | T_FALSE { $1 } | T_TRUE { $1 }
 | T_CLASS { $1 } | T_INTERFACE { $1 } | T_EXTENDS { $1 } | T_STATIC { $1 }
 | T_IMPORT { $1 } | T_EXPORT { $1 } 
/* already in identifier
 | T_FROM { $1 } | T_AS { $1 } | T_OF { $1}
 | T_GET { $1 } | T_SET { $1 }
 | T_ASYNC { $1 }
*/

field_name:
 | identifier { $1 }
 | ident_keyword { $1 }

method_name:
 | identifier { $1 }
 | ident_keyword { $1 }

property_name:
 | identifier    { PN_Id $1 }
 | string_literal  { PN_String $1 }
 | numeric_literal { PN_Num $1 }
 | ident_keyword   { PN_Id $1 }
 /*(* es6: *)*/
 | T_LBRACKET assignment_expression T_RBRACKET { PN_Computed ($1, $2, $3) }

/*(*************************************************************************)*/
/*(*1 xxx_opt, xxx_list *)*/
/*(*************************************************************************)*/

semicolon:
 | T_SEMICOLON         { Some $1 }
 | T_VIRTUAL_SEMICOLON { None }

elision:
 | T_COMMA { [Right $1] }
 | elision T_COMMA { $1 @ [Right $2] }

/*(* es6: in object literals *)*/
trailing_comma:
 | /*(*empty*)*/ { [] }
 | T_COMMA { [Right $1] }
/*(* es8: in parameters and arguments *)*/
trailing_comma2:
 | /*(*empty*)*/ { [] }
 | T_COMMA { [Right $1] }
trailing_comma3:
 | /*(*empty*)*/ { [] }
 | T_COMMA { [Right $1] }



class_element_list:
 | class_element { [$1] }
 | class_element_list class_element { $1 @ [$2] }

encaps_list:
 | encaps { [$1] }
 | encaps_list encaps { $1 @ [$2] }

module_item_list:
 | module_item { [$1] }
 | module_item_list module_item { $1 @ [$2] }

type_member_list:
 | type_member { [$1] }
 | type_member_list type_member { $1 @ [$2] }


case_clauses:
 | case_clause { [$1] }
 | case_clauses case_clause { $1 @ [$2] }

xhp_attributes:
 | /*(*empty*)*/ { [] }
 | xhp_attributes xhp_attribute { $1 @ [$2] }

xhp_children:
 | /*(*empty*)*/ { [] }
 | xhp_children xhp_child { $1 @ [$2] }


variable_declaration_list:
 | variable_declaration
     { [Left $1]  }
 | variable_declaration_list T_COMMA variable_declaration
     { $1 @ [Right $2; Left $3] }

variable_declaration_list_no_in:
 | variable_declaration_no_in
     { [Left $1] }
 | variable_declaration_list_no_in T_COMMA variable_declaration_no_in
     { $1 @ [Right $2; Left $3] }

import_specifiers:
 | import_specifier
     { [Left $1]  }
 | import_specifiers T_COMMA import_specifier
     { $1 @ [Right $2; Left $3] }

type_reference_list:
 | type_reference { [Left $1]  }
 | type_reference_list T_COMMA type_reference { $1 @ [Right $2; Left $3] }


expression_opt:
 | /*(* empty *)*/ { None }
 | expression      { Some $1 }

expression_no_in_opt:
 | /*(* empty *)*/  { None }
 | expression_no_in { Some $1 }

class_heritage_opt:
 | /*(*empty*)*/   { None }
 | class_heritage { Some $1 }

class_body_opt:
 | /*(*empty*)*/   { [] }
 | class_body { $1 }

module_item_list_opt:
 | /*(*empty*)*/    { [] }
 | module_item_list { $1 }

case_clauses_opt:
 | /*(* empty *)*/ { [] }
 | case_clauses    { $1 }

encaps_list_opt:
 | /*(* empty *)*/ { [] }
 | encaps_list    { $1 }

annotation_opt:
 | /*(* empty *)*/ { None }
 | annotation    { Some $1 }

generics_opt:
 | /*(* empty *)*/ { None }
 | generics        { Some $1 }

identifier_opt:
 | /*(* empty *)*/ { None }
 | identifier { Some $1 }

initializeur_opt:
 | /*(* empty *)*/ { None }
 | initializeur { Some $1 }

interface_extends_opt:
 | /*(* empty *)*/ { None }
 | interface_extends { Some $1 }




type_member_list_opt:
 | /*(* empty *)*/ { [] }
 | type_member_list { $1 }

param_type_list_opt:
 | /*(* empty *)*/ { [] }
 | param_type_list { $1 }

elision_opt:
 | /*(* empty *)*/ { [] }
 | elision { $1 }
