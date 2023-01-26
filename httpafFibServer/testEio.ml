open Eio.Std



let () = Eio_main.run 
@@ fun _ ->
  Switch.run @@ fun sw ->
    Fiber.fork ~sw ( fun () ->

      traceln "1st fiber";
      let (p, _) = Eio.Promise.create () in
      let _ = Eio.Promise.await p in 
        traceln "Finished waitinf for fiber 1"

    );
    Fiber.fork ~sw ( fun () ->
      traceln "\n2nd fiber";
      (* Eio.Promise.resolve r 10 *)
      );
