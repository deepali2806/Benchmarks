open Eio.Std
(* open Unified_interface *)

let run_sender ~n_iters m =
  for i = 1 to n_iters do
    Unified_interface.MVar.put m i
  done

let run_bench ~domain_mgr ~clock ~use_domains ~n_iters =
    (* let stream = Eio.Stream.create capacity in *)
    let m = Unified_interface.MVar.create_empty () in 
    Gc.full_major ();
    let _minor0, prom0, _major0 = Gc.counters () in
    let t0 = Eio.Time.now clock in
    Fiber.both
      (fun () ->
         if use_domains then (
           Eio.Domain_manager.run domain_mgr @@ fun () ->
           run_sender ~n_iters m
         ) else (
           run_sender ~n_iters m
         )
      )
      (fun () ->
         for i = 1 to n_iters do
           let j = Unified_interface.MVar.take m in
           assert (i = j)
         done
      );
    let t1 = Eio.Time.now clock in
    let time_total = t1 -. t0 in
    let time_per_iter = time_total /. float n_iters in
    let _minor1, prom1, _major1 = Gc.counters () in
    let prom = prom1 -. prom0 in
    Printf.printf "%11b, %8d, %7.2f, %13.4f\n%!" use_domains n_iters (1e9 *. time_per_iter) (prom /. float n_iters)

let main ~domain_mgr ~clock =
  Printf.printf "use_domains, n_iters, ns/iter, promoted/iter\n%!";
  [false, 10_000_000;
   true,   1_000_000]
  |> List.iter (fun (use_domains, n_iters) ->
      (* [0; 1; 10; 100; 1000] |> List.iter (fun capacity -> *)
          run_bench ~domain_mgr ~clock ~use_domains ~n_iters
        (* ) *)
    )

let () =
  Eio_main.run @@ fun env ->
  main
    ~domain_mgr:(Eio.Stdenv.domain_mgr env)
    ~clock:(Eio.Stdenv.clock env)