open Ast

type sexpr = dtype * sx
and sx =
  | SBinop of sexpr * operator * sexpr
  | SId of string
  | SILit of int
  | SFLit of float
  | SMLit of (sexpr list) list

type svdecl = dtype * string

type sstmt =
  | SAssign of string * sexpr
  | SExpr of sexpr
  | SReturn of sexpr
  | SVDeclare of svdecl
  | SVDeAssign of dtype * string * sexpr
  | SBlock of sstmt list

type sbind = dtype * string

type smain = { sstmts : sstmt list }

type sfdecl = {
  sfname : string;
  sformals : sbind list;
  sstmts : sstmt list;
}

type sdecls = { 
  svars : sbind list; 
  sfuncs : sfdecl list;
}

type sprogram = {
  sdecls: sdecls;
  smain: smain
}

(* Pretty-printing functions from microc *)

let rec string_of_sexpr (t, e) = 
  "(" ^ string_of_typ t ^ " : " ^ (match e with
    SILit(l) -> string_of_int l
  | SFLit(l) -> string_of_float l
  | SId(s) -> s
  | SBinop(e1, o, e2) ->
      string_of_sexpr e1 ^ " " ^ string_of_op o ^ " " ^ string_of_sexpr e2
  | SMLit(l) -> let string_of_row l =
    String.concat ", " (List.map string_of_sexpr l)
    in
    String.concat "\n" (List.map string_of_row l)
    ) ^ ")"

let rec string_of_sstmt = function
  SExpr(sexpr) -> string_of_sexpr sexpr ^ ";\n"
| SReturn(sexpr) -> "return: " ^ string_of_sexpr sexpr ^ ";\n"
| SAssign(v, e) -> "Assign: " ^ v ^ " = " ^ string_of_sexpr e ^ ";\n"
| SVDeclare(t, id) -> "VDeclare: " ^ string_of_typ t ^ " " ^ id ^ ";\n"
| SVDeAssign(t, id, sexpr) -> "VDeAssign: " ^ string_of_typ t ^ id ^ string_of_sexpr sexpr ^ ";\n"
| SBlock(stmts) ->
  "{\n" ^ String.concat "" (List.map string_of_sstmt stmts) ^ "}\n"

let string_of_svdecl (t, id) = "vdecl: " ^ string_of_typ t ^ " " ^ id ^ ";\n"

let string_of_sfdecl fdecl =
  "fdecl: " ^ fdecl.sfname ^ "(" ^ String.concat ", " (List.map snd fdecl.sformals) ^
  ")\n{\n" ^
  String.concat "" (List.map string_of_sstmt fdecl.sstmts) ^
  "}\n"

let string_of_sdecls (decls) =
  String.concat "" (List.map string_of_svdecl decls.svars) ^ "\n" ^
  String.concat "\n" (List.map string_of_sfdecl decls.sfuncs)

let string_of_sprogram (program) = 
  (string_of_sdecls program.sdecls) ^ "\n" ^
  "inside main: \n" ^ String.concat "\n" (List.map string_of_sstmt program.smain.sstmts)