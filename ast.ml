type operator = Add | Sub | Mul | Div

type expr =
  | Binop of expr * operator * expr
  | ILit of int
  | FLit of float
  | BLit of bool
  | MLit of expr list list
  | Id of string
  | Func of string * expr list
  | Access of expr * expr * expr

type dtype = Int | Float | Bool | Matrix | Null

(*type elifstmt = Elif of expr * stmt list*)

type assignstmt =
  | VDeAssign of dtype * string * expr
  | Assign of string * expr
  | MAssign of expr * expr * expr * expr

type stmt =
  | Expr of expr
  | Return of expr
  | VDeclare of dtype * string
  | AssignStmt of assignstmt
  | If of expr * stmt list
  | IfElse of expr * stmt list * stmt list
  | For of assignstmt * expr * expr * stmt list
  | While of expr * stmt list

type bind = dtype * string

type fdecl = {
  return : dtype;
  fname : string;
  formals : bind list;
  stmts : stmt list;
}

type program = bind list * fdecl list

(* Pretty-printing functions from microc *)
let string_of_typ = function
  | Int -> "int"
  | Null -> "null"
  | Float -> "float"
  | Bool -> "Bool"
  | Matrix -> "matrix"

let string_of_op = function Add -> "+" | Sub -> "-" | Mul -> "*" | Div -> "/"

let rec string_of_expr = function
  | ILit l -> string_of_int l
  | FLit l -> string_of_float l
  | BLit l -> string_of_bool l
  | MLit l ->
      let string_of_row l = String.concat "" (List.map string_of_expr l) in
      String.concat "" (List.map string_of_row l)
  | Id s -> s
  | Binop (e1, o, e2) ->
      string_of_expr e1 ^ " " ^ string_of_op o ^ " " ^ string_of_expr e2
  | Func (id, inputs) ->
      id ^ "(" ^ String.concat ", " (List.map string_of_expr inputs) ^ ";\n"
  | Access (e1, e2, e3) ->
      string_of_expr e1 ^ " " ^ string_of_expr e2 ^ " " ^ string_of_expr e3

let rec string_of_assignstmt = function
  | VDeAssign (t, id, expr) ->
      "VDeAssign: " ^ string_of_typ t ^ id ^ string_of_expr expr ^ ";\n"
  | Assign (v, e) -> "Assign: " ^ v ^ " = " ^ string_of_expr e ^ ";\n"
  | MAssign (id, r, c, v) ->
      "MAssign: " ^ string_of_expr id ^ "[" ^ string_of_expr r ^ ", "
      ^ string_of_expr c ^ "] = " ^ string_of_expr v ^ ";\n"

let rec string_of_stmt = function
  | Expr expr -> string_of_expr expr ^ ";\n"
  | Return expr -> "return: " ^ string_of_expr expr ^ ";\n"
  | AssignStmt assignstmt -> string_of_assignstmt assignstmt
  (* | Assign(v, e) -> "Assign: " ^ v ^ " = " ^ string_of_expr e ^ ";\n" *)
  | VDeclare (t, id) -> "VDeclare: " ^ string_of_typ t ^ " " ^ id ^ ";\n"
(*| VDeAssign(t, id, expr) -> "VDeAssign: " ^ string_of_typ t ^ id ^ string_of_expr expr ^ ";\n"*)

let string_of_vdecl (t, id) = "vdecl: " ^ string_of_typ t ^ " " ^ id ^ ";\n"

let string_of_fdecl fdecl =
  "fdecl: " ^ fdecl.fname ^ "("
  ^ String.concat ", " (List.map snd fdecl.formals)
  ^ ")\n{\n"
  ^ String.concat "" (List.map string_of_stmt fdecl.stmts)
  ^ "}\n"

let string_of_program (vars, funcs) =
  String.concat "" (List.map string_of_vdecl vars)
  ^ "\n"
  ^ String.concat "\n" (List.map string_of_fdecl funcs)
