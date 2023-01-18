(* Here we are checking how Eio fibers are suspended *)
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
        (* printf "\nEio: Running in domain %d%!" (Domain.self () :> int); *)
        Eio.Fiber.fork ~sw
        (fun () -> 
          printf "\nEio : Inside Eio Fiber 1%!";
          let v = MVar.take m in
          printf "\nEio : Value taken %d%!" v
        );
        Eio.Fiber.fork ~sw
        (fun () -> 
          printf "\nEio : Inside Eio Fiber 2%!";
        );
      )
    ) in 
 
     let pool = T.setup_pool ~num_domains:(num_domains - 1) () 
     in
         T.run pool (fun () -> 
                 let pr = T.async pool ( fun _ ->
                         (* printf "\nDomainslib : Async Running in domain %d%!" (Domain.self () :> int); *)
                         let v = fib_par pool (45) in
                         let _ = MVar.put m v in ()
                     ) in
                 printf "\nDomainslib : Waiting for promise to complete %!";
                 let _ = T.await pool pr in ();
                 printf "\nDomainslib : Promise completed %!"
             (* )  *)
     );
         
     let _ = Domain.join eio_domain in 
     printf "\nBoth the domains are done completed%!";
     T.teardown_pool pool
 
 let  _ = main ()