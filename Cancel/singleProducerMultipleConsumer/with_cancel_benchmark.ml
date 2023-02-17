(* 
ocamlfind ocamlopt -o test_fifo.exe -thread fifo.mli fifo.ml test.ml 
 *)
 open Printf
open Effect
open Effect.Deep
open Cancel_unified_interface

let m = MVar.create_empty ()
let mb = MVar.create_empty ()
let n_iters = 1000000
let n_consumers = 10000
let n_cancel = try int_of_string Sys.argv.(1) with _ -> 1000

let start = ref (0.0)

let main () = 

    let producer_domain = Domain.spawn( fun () ->
        let comp () =
        let module F = Fifo.Make () in
            F.run ( fun () -> 

                let producer = F.fork ( fun () ->
                    let ret = MVar.take mb in
                    if ret = true then
                    begin
                        let counter = ref 0 in
                        let rec produce () = 
                            let i = !counter in 
                            if i = n_iters+1 then ()
                            else
                                begin 
                                    counter := !counter + 1;
                                    MVar.put m i; 
                                    produce ()
                                end
                        in 
                        produce ();
                        raise Exit
                        (* printf "Is is done?" *)
                        (* for i = 1 to (n_iters) do 
                            (* printf "Producer sending %d %!" i; *)
                            MVar.put m i;
                            (* counter := !counter - 1 *)
                        done *)

                    end
                ) in ()
            ) in
             try comp () with
                | Exit -> ()             
    ) in
  let comp () = 
    let module F = Fifo.Make () in
     F.run (fun () ->
        let rec fiber_create l n = 
            if n = 0 then l
            else
            begin
             let fiber = F.fork ( fun () ->
               let rec consume () =  
                    let value = MVar.take m in
                    if value = (n_iters) then
                    (* if !counter = 0 then *)
                        begin 
                        (* printf "\nAre we reaching here %d?%!" value; *)
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
        let l = fiber_create [] (n_consumers) in

        let fiber = F.fork ( fun () ->
            (* Cancel 1000 threads *) 
            let rec cancellation l v = 
                if v = 0 then ()
                else
                begin
                    match l with
                    | [] -> ()
                    | x :: xs -> F.cancel x; cancellation xs (v-1)
                end
            in
            cancellation l n_cancel;  
            MVar.put mb true
        )
         in ()
     ) in 
     try comp () with
    | Exit -> (let stop = Unix.gettimeofday () in 
              printf "\nTotal time needed to consume all the values %fs\n%!" (stop -. !start))
    ; 
    let _ = Domain.join producer_domain in
    printf "\nBoth the domains are done completed\n%!"

let _ = main ()
    
