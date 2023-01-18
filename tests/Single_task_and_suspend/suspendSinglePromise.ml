(* ocamlfind ocamlopt -package lwt,lwt.unix,lwt_ppx,eio_domainslib_interface,domainslib  -linkpkg -o checkMVar checkMVar.ml 
 *)
 open Printf
 open Unified_interface
 (* open Effect *)
 (* open Effect.Deep *)
 
 (* open Lwt.Infix *)

 module Final_monad = Monad.Make_monad (struct 
 type 'a t = 'a Lwt.t
 let return = Lwt.return
 let suspend_fn = Lwt.suspend_fn
 end
)

let m = MVar.create_empty ()
 
(* let mn = Lwt_mvar.create_empty () *)

let main () =
   Lwt_main.run ( 
     let p = Lwt.bind
      (let v = (Final_monad.take_monad m) in v) 
      (* (let v = Lwt_mvar.take mn in v) *)
                      (fun v ->  printf "\nLwt: Hello %d%!" v; Lwt.return ())
              in p
   )
 
 let  _ = main ()
