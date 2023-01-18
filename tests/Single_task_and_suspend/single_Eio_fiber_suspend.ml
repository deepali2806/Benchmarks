(* Here we are checking how in EIO single fiber is suspended *)

open Printf
open Unified_interface

let m = MVar.create_empty ()

let main () =
   Eio_luv.run @@ fun _env ->
     Eio.Switch.run (fun sw ->
       (* printf "\nEio : Running in domain %d%!" (Domain.self () :> int); *)
       Eio.Fiber.fork ~sw
       (fun () -> 
         printf "\nEio : Eio Fiber 1 %!";
         let v = Unified_interface.MVar.take m in 
         printf "\nEio: We will never reach here %d%!" v
       );
     )
   

let  _ = main ()