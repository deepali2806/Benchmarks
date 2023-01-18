(* Here we are checking how Domainslib tasks are suspended *)

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

let m = MVar.create_empty ()

let main () =
  let eio_domain = Domain.spawn( fun () ->
    Eio_main.run @@ fun _env ->
      Eio.Switch.run (fun sw ->
        (* printf "\nEio : Running in domain %d%!" (Domain.self () :> int); *)
        Eio.Fiber.fork ~sw
        (fun () -> 
          printf "\nEio : Eio Fiber 1 %!";
          let _ = Unified_interface.MVar.put m (50) in ()
        );
      )
    ) in 
 
     let pool = T.setup_pool ~num_domains:(num_domains - 1) () 
     in
         T.run pool (fun () -> 
                 let pr = T.async pool ( fun _ ->
                         (* printf "\nDomainslib: Async Running in domain %d%!" (Domain.self () :> int); *)
                         let x = Unified_interface.MVar.take m in
                         printf "\nDomainslib : Value taken : %d%!" x
                     ) in
                 printf "\nDomainslib : Waiting for promise to complete %!";
                 let _ = T.await pool pr in ();
                 printf "\nDomainslib : Promise completed %!"
     );
         
     let _ = Domain.join eio_domain in 
     printf "\nBoth the tasks are completed%!";
     T.teardown_pool pool
 
 let  _ = main ()