(* ocamlfind ocamlopt -package lwt,lwt.unix,lwt_ppx,eio_domainslib_interface,domainslib  -linkpkg -o checkMVar checkMVar.ml 
 *)
 open Printf
 open Unified_interface

 let num_domains = try int_of_string Sys.argv.(1) with _ -> 1
 module T = Domainslib.Task
 
 
 let rec fib n =
   if n < 2 then 1
   else fib (n-1) + fib (n-2)
 
 let rec fib_par pool n =
   if n <= 40 then fib n
   else
     let a = T.async pool (fun _ -> fib_par pool (n-1)) in
     let b = T.async pool (fun _ -> fib_par pool (n-2)) in
     T.await pool a + T.await pool b
 
 open Lwt.Infix

 module Final_monad = Monad.Make_monad (struct 
 type 'a t = 'a Lwt.t
 let return = Lwt.return
 let suspend_fn = Lwt.suspend_fn
 end
)

let m = MVar.create_empty ()
 
let main () =
  let lwt_domain = Domain.spawn( fun () ->
 
   Lwt_main.run ( 
     let p = Lwt.bind (let v = (Final_monad.take_monad m) in v) 
                      (fun v ->  printf "\nLwt: Hello %d%!" v; Lwt.return ())
    in p >>= fun () ->
    Lwt.return (printf "\nLwt : Second promise%!")                                 
 );
   
     ) in 
 
     let pool = T.setup_pool ~num_domains:(num_domains - 1) () 
     in
         T.run pool (fun () -> 
                 let pr = T.async pool ( fun _ ->
                     (* printf "\nDomainslib: Async Running in domain %d%!" (Domain.self () :> int); *)
                         let v = fib_par pool (40) in
                         let _ = Unified_interface.MVar.put m v in
                         printf "\nDomainslib: Fib 45 ans %d%!" v;
                     ) in
                 let _ = T.await pool pr in ();
     );
         
      let _ = Domain.join lwt_domain in  
     printf "\nBoth the domains are done completed%!";
     T.teardown_pool pool
 
 let  _ = main ()
