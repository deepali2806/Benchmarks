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
let n_producers = 10000
let n_cancel = try int_of_string Sys.argv.(1) with _ -> 1000

let start = ref (0.0)
let counter = ref (n_iters)


let main () = 

    let consumer_domain = Domain.spawn( fun () ->
    
    let comp () = 
        let module F = Fifo.Make () in
            F.run ( fun () -> 
                let _ = F.fork ( fun () ->
                    let ret = MVar.take mb in
                    if ret = true then
                    begin
                        start := Unix.gettimeofday ();
                        let v = ref (-1) in
                        while !v <> 1 do 
                             v := MVar.take m;
                            (* () *)
                            (* printf "\nTaking value %d%!" !v *)
                        done;
                        raise Exit
                    end
                ) in 
                ()
            ) in
          try comp () with
                | Exit ->
                 let stop = Unix.gettimeofday () in 
                printf "\nTotal time needed to consume all the values %fs\n%!" (stop -. !start)

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
                            (* printf "\n Exiting\n%!"; *)
                            raise Exit
                        end
                    else
                        begin
                            (* printf "\nproducing %d" i; *)
                            counter := !counter - 1;
                            MVar.put m i;
                            produce ()
                        end
                in 
                    produce ()
                ) in
                fiber_create (fiber::l) (n-1)
            end 
        in
        let l = fiber_create [] (n_producers) in

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
    | Exit -> ()
    (* printf "\nWe will stop here%!" *)
    (* | ex ->  Printexc.raise_with_backtrace ex (Printexc.get_raw_backtrace ()) *)
    ; 
    let _ = Domain.join consumer_domain in
    printf "\nBoth the domains are done completed\n%!"

let _ = main ()
    
