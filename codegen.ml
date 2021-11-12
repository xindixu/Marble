module L = Llvm
module A = Ast

open Sast

module StringMap = Map.Make(String)






(* let translate (functions) = 
    let rec ltype_of_typ = function
		  A.Int -> i32_t 
		| A.Float -> float_t 
		| A.Void  -> void_t
		| A.Matrix(t) -> L.pointer_type (ltype_of_typ t)

	in
*)







(* Fill in the body of the given function *)	
(* let build_function_body fdecl = *)



(*  let lookup n = Hashtbl.find var_hash n
    in
*)



(* Construct code for an expression; return its value *)
(* let rec expr builder ((_, e) : sexpr) = *)
 let rec expr builder ((_, e) : sexpr) = match e with
    SIlit i  -> L.const_int i32_t i
      | SBLit b  -> L.const_int i1_t (if b then 1 else 0)
      | SFLit i -> L.const_float float_t (float_of_string i)
      (* null? | SNoexpr     -> L.const_int i32_t 0 *)
      | SId s       -> L.build_load (lookup s) s builder
      (* Matrix | SMatrixLit (contents, rows, cols) -> *)
      | SBinop (e1, op, e2) ->
            let e1' = expr builder e1
            and e2' = expr builder e2 in
            (match op with
            A.Add     -> L.build_add
            | A.Sub     -> L.build_sub
            | A.Mult    -> L.build_mul
            | A.Div     -> L.build_sdiv
            | A.And     -> L.build_and
            | A.Or      -> L.build_or
            | A.Equal   -> L.build_icmp L.Icmp.Eq
            | A.Neq     -> L.build_icmp L.Icmp.Ne
            | A.Less    -> L.build_icmp L.Icmp.Slt
            | A.Leq     -> L.build_icmp L.Icmp.Sle
            | A.Greater -> L.build_icmp L.Icmp.Sgt
            | A.Geq     -> L.build_icmp L.Icmp.Sge
            ) e1' e2' "tmp" builder
            (* Unary and Negate *)
            | SFunc (f, args) ->
                let (fdef, fdecl) = StringMap.find f function_decls in
                    let llargs = (List.rev (List.map (expr builder) (List.rev args))) in
                    let result = (match fdecl.styp with
                                A.Void -> ""
                            | _ -> f ^ "_result") in
                    L.build_call fdef (Array.of_list llargs) result builder
                in
                ignore(List.map (fun (_, _, v) -> expr builder v) fdecl.sformals);
                ignore(List.map (fun (_, _, v) -> expr builder v) fdecl.slocals);



(* Below is for stmt part *)
(* LLVM insists each basic block end with exactly one "terminator" 
       instruction that transfers control.  This function runs "instr builder"
       if the current block does not already have a terminator.  Used,
       e.g., to handle the "fall off the end of the function" case. *)
	    
	    let add_terminal builder instr =
	      match L.block_terminator (L.insertion_block builder) with
			Some _ -> ()
	      | None -> ignore (instr builder) in
		
	    (* Build the code for the given statement; return the builder for
	       the statement's successor (i.e., the next instruction will be built
	       after the one generated by this call) *)
        let rec stmt builder = function
            SExpr e -> ignore(expr builder e); builder
            | SReturn e -> ignore(L.build_ret (expr builder e) builder ); builder
            | SVDeclare(t,s) -> 
                let local_var = L.build_alloca (ltype_of_typ t) s builder in 
                Hashtbl.add var_hash s local_var;
                (* What is the default? *)
                let e' = expr builder se in
                ignore(L.build_store e' (lookup s) builder); builder
            | SAssignStmt sastmt -> match sastmt with
                                        SVDeAssign(t,s, se) ->
                                            let local_var = L.build_alloca (ltype_of_typ t) s builder in 
                                            Hashtbl.add var_hash s local_var;
                                            let e' = expr builder se in
                                            ignore(L.build_store e' (lookup s) builder); builder
                                        | SAssign(s, se) -> let e' = expr builder se in ignore(L.build_store e' (lookup s) builder); builder

        in 

        (* Build the code for each statement in the function *)
	    List.fold_left stmt builder fdecl.sstmts 

	    (* Add a return if the last block falls off the end 
	    add_terminal builder (match fdecl.styp with
	        A.Void -> L.build_ret_void
	      | A.Float -> L.build_ret (L.const_float float_t 0.0)
	      | t -> L.build_ret (L.const_int (ltype_of_typ t) 0)) *)