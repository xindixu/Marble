module L = Llvm
module A = Ast
open Sast
module StringMap = Map.Make (String)

(* Translate Sast.program -> Llvm.module *)
let translate program =
  let main = program.A.main
  and decls = program.A.decls
  and vars = program.A.decls.vars
  and funcs = program.A.decls.funcs in

  let context = L.global_context () in

  (* Create the LLVM compilation module into which
     we will generate code *)
  let the_module = L.create_modeule context "Marble" in

  let i32_t = L.i32_type context
  and i8_t = L.i8_type context
  and i1_t = L.i1_type context
  (* and float_t = L.double_type context *)
  and void_t = L.void_type context in

  (* Return the LLVM type for a Marble type *)
  let ltype_of_typ = function
    | A.Int -> i32_t
    | A.Bool -> i1_t
    | A.Float -> float_t
    | A.Void -> void_t
  in

  (* Create a map of global variables after creating each *)
  let global_vars : L.llvalue StringMap.t =
    let global_var m (t, n) =
      (* Assign default values *)
      let init =
        match t with
        (* | A.Float -> L.const_float (ltype_of_typ t) 0.0 *)
        | _ -> L.const_int (ltype_of_typ t) 0
      in
      StringMap.add n (L.define_global n init the_module) m
    in
    List.fold_left global_var StringMap.empty globals
  in

  (* Default built-in functions *)
  let printf_t : L.lltype =
    L.var_arg_function_type i32_t [| L.pointer_type i8_t |]
  in

  (* Fill in the body of the given function *)
  let function_decls : (L.llvalue * sfuncs) StringMap.t =
    let function_decl m fdecl =
      let name = fdecl.sfname
      and formal_types = 
	Array.of_list (List.map (fun (t,_) -> ltype_of_typ t) fdecl.sformals)
      in let ftype = L.function_type (ltype_of_typ fdecl.styp) formal_types in
      StringMap.add name (L.define_function name ftype the_module, fdecl) m in
    List.fold_left function_decl StringMap.empty functions in
  
  (* Fill in the body of the given function *)
  let build_function_body fdecl =
    let (the_function, _) = StringMap.find fdecl.sfname function_decls in
    let builder = L.builder_at_end context (L.entry_block the_function) in

    let int_format_str = L.build_global_stringptr "%d\n" "fmt" builder in
    (* and float_format_str = L.build_global_stringptr "%g\n" "fmt" builder *)

    (* Construct the function's "locals": formal arguments and locally
       declared variables.  Allocate each on the stack, initialize their
       value, if appropriate, and remember their values in the "locals" map *)
    let local_vars =
      let add_formal m (t, n) p = 
        L.set_value_name n p;
	let local = L.build_alloca (ltype_of_typ t) n builder in
        ignore (L.build_store p local builder);
	StringMap.add n local m 

      (* Allocate space for any locally declared variables and add the
       * resulting registers to our map *)
      and add_local m (t, n) =
	let local_var = L.build_alloca (ltype_of_typ t) n builder
	in StringMap.add n local_var m 
      in

      let formals = List.fold_left2 add_formal StringMap.empty fdecl.sformals
          (Array.to_list (L.params the_function)) in
      List.fold_left add_local formals fdecl.slocals 
    in

    (* Return the value for a variable or formal argument.
       Check local names first, then global names *)
    let lookup n = try StringMap.find n local_vars
                   with Not_found -> StringMap.find n global_vars
    in


  (* Construct code for an expression; return its value *)
  (* let rec expr builder ((_, e) : sexpr) = *)
  let rec expr builder ((_, e) : sexpr) =
    match e with
    | SIlit i -> L.const_int i32_t i
    | SBLit b -> L.const_int i1_t (if b then 1 else 0)
    | SFLit i -> L.const_float float_t (float_of_string i)
    (* null? | SNoexpr     -> L.const_int i32_t 0 *)
    | SId s -> L.build_load (lookup s) s builder
    (* Matrix | SMatrixLit (contents, rows, cols) -> *)
    | SBinop (e1, op, e2) ->
        let e1' = expr builder e1 and e2' = expr builder e2 in
        (match op with
        | A.Add -> L.build_add
        | A.Sub -> L.build_sub
        | A.Mult -> L.build_mul
        | A.Div -> L.build_sdiv
        | A.And -> L.build_and
        | A.Or -> L.build_or
        | A.Equal -> L.build_icmp L.Icmp.Eq
        | A.Neq -> L.build_icmp L.Icmp.Ne
        | A.Less -> L.build_icmp L.Icmp.Slt
        | A.Leq -> L.build_icmp L.Icmp.Sle
        | A.Greater -> L.build_icmp L.Icmp.Sgt
        | A.Geq -> L.build_icmp L.Icmp.Sge)
          e1' e2' "tmp" builder
    (* Unary and Negate *)
    (* Function call *)
    | SFunc (f, args) ->
        let fdef, fdecl = StringMap.find f function_decls in
        let llargs = List.rev (List.map (expr builder) (List.rev args)) in
        let result =
          match fdecl.styp with A.Void -> "" | _ -> f ^ "_result"
        in
        L.build_call fdef (Array.of_list llargs) result builder
  in
  ignore (List.map (fun (_, _, v) -> expr builder v) fdecl.sformals);

  (* ignore(List.map (fun (_, _, v) -> expr builder v) fdecl.slocals); *)

  (* Below is for stmt part *)
  (* LLVM insists each basic block end with exactly one "terminator"
         instruction that transfers control.  This function runs "instr builder"
         if the current block does not already have a terminator.  Used,
         e.g., to handle the "fall off the end of the function" case. *)
  let add_terminal builder instr =
    match L.block_terminator (L.insertion_block builder) with
    | Some _ -> ()
    | None -> ignore (instr builder)
  in

  (* Build the code for the given statement; return the builder for
     the statement's successor (i.e., the next instruction will be built
     after the one generated by this call) *)
  let rec stmt builder = function
    | SExpr e ->
        ignore (expr builder e);
        builder
    | SReturn e ->
        ignore (L.build_ret (expr builder e) builder);
        builder
    | SVDeclare (t, s) ->
        let local_var = L.build_alloca (ltype_of_typ t) s builder in
        Hashtbl.add var_hash s local_var;
        (* What is the default? *)
        let e' = expr builder se in
        ignore (L.build_store e' (lookup s) builder);
        builder
    | SAssignStmt sastmt -> (
        match sastmt with
        | SVDeAssign (t, s, se) ->
            let local_var = L.build_alloca (ltype_of_typ t) s builder in
            Hashtbl.add var_hash s local_var;
            let e' = expr builder se in
            ignore (L.build_store e' (lookup s) builder);
            builder
        | SAssign (s, se) ->
            let e' = expr builder se in
            ignore (L.build_store e' (lookup s) builder);
            builder)
  in

  (* Build the code for each statement in the function *)
  List.fold_left stmt builder fdecl.sstmts
  
List.iter build_function_body functions;
the_module

(* Add a return if the last block falls off the end
   add_terminal builder (match fdecl.styp with
       A.Void -> L.build_ret_void
     | A.Float -> L.build_ret (L.const_float float_t 0.0)
     | t -> L.build_ret (L.const_int (ltype_of_typ t) 0)) *)
