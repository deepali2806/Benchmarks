(* 
ocamlfind ocamlopt -o test_fifo.exe -thread fifo.mli fifo.ml test.ml 
 *)
 open Printf
open Effect
open Effect.Deep
open Cancel_unified_interface

let m1 = MVar.create_empty ()
let m2 = MVar.create_empty ()

let n_iters = 1000000
let n_consumers = 10000
let n_producers = 10000


let start = ref (0.0)
let counter = ref (n_iters)

let main () = 

    let consumer_domain = Domain.spawn( fun () ->
        let comp () = 
        let module F = Fifo.Make () in
            F.run ( fun () -> 
                let rec fiber_create l n = 
                if n = 0 then l
                else
                begin
                let fiber = F.fork ( fun () ->
                let rec consume () =  
                        let value = MVar.take m1 in
                        if value = (1) then
                            begin 
                            (* printf "\nConsumer : Are we reaching here %d?%!" value; *)
                            raise Exit
                            end
                        else
                            consume ()
                        in 
                        consume ()
                        
                    ) in
                    fiber_create (fiber::l) (n-1)
                end 
            in
            start := Unix.gettimeofday ();
            let l = fiber_create [] (n_consumers/2) in

            let rec fiber_create l n = 
                if n = 0 then l
                else
                begin
                let fiber = F.fork ( fun () ->
                let rec consume () =  
                        let value = MVar.take m2 in
                        if value = (1) then
                            begin 
                            (* printf "\nConsumer Are we reaching here %d?%!" value; *)
                            raise Exit
                            end
                        else
                            consume ()
                        in 
                        consume ()
                        
                    ) in
                    fiber_create (fiber::l) (n-1)
                end 
            in
            let l = fiber_create [] (n_consumers/2) in
            ()
        ) in
    try comp () with
    | Exit -> (let stop = Unix.gettimeofday () in 
              printf "Total time needed to consume all the values %fs\n%!" (stop -. !start))

    ) in
  let comp () = 
    let module F = Fifo.Make () in
     F.run (fun () ->
        let rec fiber_create l n = 
            if n = 0 then l
            else
            begin
             let fiber = F.fork ( fun () ->
                
                let rec produce () = 
                    let i = !counter in 
                    if i <= 0 then
                        begin
                            (* printf "\nProducer: Exiting\n%!"; *)
                            raise Exit
                        end
                    else
                        begin
                            (* printf "\nproducing %d" i; *)
                            counter := !counter - 1;
                            MVar.put m2 i;
                            produce ()
                        end
                in 
                    produce ()
                ) in
                fiber_create (fiber::l) (n-1)
            end 
        in
        let l = fiber_create [] (n_producers/2) in
    
        let rec fiber_create l n = 
            if n = 0 then l
            else
            begin
             let fiber = F.fork ( fun () ->
                
                let rec produce () = 
                    let i = !counter in 
                    if i <= 0 then
                        begin
                            (* printf "\nProducer: Exiting\n%!"; *)
                            raise Exit
                        end
                    else
                        begin
                            (* printf "\nproducing %d" i; *)
                            counter := !counter - 1;
                            MVar.put m1 i;
                            produce ()
                        end
                in 
                    produce ()
                ) in
                fiber_create (fiber::l) (n-1)
            end 
        in
        let l = fiber_create [] (n_producers/2) in
        ()
        
         
     ) in 
     try comp () with
    | Exit -> () 
    (* printf "Producer: We will stop here" *)
    (* | ex ->  Printexc.raise_with_backtrace ex (Printexc.get_raw_backtrace ()) *)
    ; 
    let _ = Domain.join consumer_domain in
    printf "\nBoth the domains are finsished\n%!"

let _ = main ()
    
