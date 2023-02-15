(* Original File can be found at
 https://github.com/ocaml-multicore/retro-httpaf-bench/blob/master/httpaf-eio/wrk_effects_benchmark.ml

  *)

  open Httpaf
  open Eio.Std
  (* open Printf  *)
  
  
  module S = Eio.Stream
  
  let n_domains = try int_of_string Sys.argv.(1) with _ -> 2
  let str = (S.create 3000);;
  let i = Atomic.make 0
  
  let rec fib n =
    if n < 2 then 1
    else fib (n-1) + fib (n-2)
  
  let text = "I am Deepali Here :-)"
  (* let text = "CHAPTER I. Down the Rabbit-Hole  Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do: once or twice she had peeped into the book her sister was reading, but it had no pictures or conversations in it, <and what is the use of a book,> thought Alice <without pictures or conversations?> So she was considering in her own mind (as well as she could, for the hot day made her feel very sleepy and stupid), whether the pleasure of making a daisy-chain would be worth the trouble of getting up and picking the daisies, when suddenly a White Rabbit with pink eyes ran close by her. There was nothing so very remarkable in that; nor did Alice think it so very much out of the way to hear the Rabbit say to itself, <Oh dear! Oh dear! I shall be late!> (when she thought it over afterwards, it occurred to her that she ought to have wondered at this, but at the time it all seemed quite natural); but when the Rabbit actually took a watch out of its waistcoat-pocket, and looked at it, and then hurried on, Alice started to her feet, for it flashed across her mind that she had never before seen a rabbit with either a waistcoat-pocket, or a watch to take out of it, and burning with curiosity, she ran across the field after it, and fortunately was just in time to see it pop down a large rabbit-hole under the hedge. In another moment down went Alice after it, never once considering how in the world she was to get out again. The rabbit-hole went straight on like a tunnel for some way, and then dipped suddenly down, so suddenly that Alice had not a moment to think about stopping herself before she found herself falling down a very deep well. Either the well was very deep, or she fell very slowly, for she had plenty of time as she went down to look about her and to wonder what was going to happen next. First, she tried to look down and make out what she was coming to, but it was too dark to see anything; then she looked at the sides of the well, and noticed that they were filled with cupboards......" *)
  
  let text = Bigstringaf.of_string ~off:0 ~len:(String.length text) text
  
  let headers = Headers.of_list ["content-length", string_of_int (Bigstringaf.length text)]
  let request_handler _ reqd =
    let request = Reqd.request reqd in
    match request.target with
    | "/" -> 
              let start = Unix.gettimeofday () in            
              let index = Atomic.get i in
              (* Printf.printf "\nRequest Before Computation %d%!" index; *)

              let (p, r) = Eio.Promise.create () in   
              let value = 40 in         
              S.add str (value, r); 
              let ans = Eio.Promise.await p in
  
              Printf.printf "Eio %d: Fib 45 : %d" index ans;
              
              let response_ok = Response.create ~headers `OK in
              Reqd.respond_with_bigstring reqd response_ok text;
              Atomic.incr i;
              let stop = Unix.gettimeofday () in
              let response_time = (stop -. start) in
              Printf.printf "\n Eio Fiber Response time: %fs\n\n%!" response_time
  
    | "/exit" ->
      exit 0
    | _   ->
      let msg = "Route not found" in
      let headers = Headers.of_list ["content-length", string_of_int (String.length msg)] in
      let response_nf = Response.create ~headers `Not_found in
      Reqd.respond_with_string reqd response_nf msg
  
  let error_handler _ ?request:_ error start_response =
    let response_body = start_response Httpaf.Headers.empty in
    begin match error with
    | `Exn exn ->
      Httpaf.Body.write_string response_body (Printexc.to_string exn);
      Httpaf.Body.write_string response_body "\n";
    | #Httpaf.Status.standard as error ->
      Httpaf.Body.write_string response_body (Httpaf.Status.default_reason_phrase error)
    end;
    Httpaf.Body.close_writer response_body
  
  let log_connection_error ex =
    traceln "Uncaught exception handling client: %a" Fmt.exn ex
  
  let run_domain ssock =
    traceln "Running server in domain %d%!" (Domain.self () :> int);
    Switch.run @@ fun sw ->
    let handle_connection = Httpaf_eio.Server.create_connection_handler request_handler ~error_handler in
    (* Wait for clients, and fork off echo servers. *)
    while true do
    (* Accept_sub will call fibre.fork internally for each connection *)
    (*    Eio.Net.accept_sub ssock ~sw ~on_error:log_connection_error handle_connection *)
    Eio.Net.accept_fork ssock ~sw ~on_error:log_connection_error (fun flow addr -> Switch.run (fun sw -> handle_connection ~sw flow addr ))	
    done
  
  let main ~net ~domain_mgr ~n_domains port backlog =
    Switch.run @@ fun sw ->
      let ssock = Eio.Net.listen net ~sw ~reuse_addr:true ~backlog @@ `Tcp (Eio.Net.Ipaddr.V4.loopback, port) in
      traceln "Echo server listening on 127.0.0.1:%d" port;
      traceln "Starting %d domains..." n_domains;
  
      for _ = 1 to n_domains do
          Fiber.fork ~sw (fun () ->
              Eio.Domain_manager.run domain_mgr
              (fun () ->
                  while true do
                    (* traceln "We are in Domain %d%!" (Domain.self ():> int); *)
                    let (value, resolver) = S.take str in
                    let ans = fib value in
                    Eio.Promise.resolve resolver ans
                  done;
              )
          )
      done;
      run_domain ssock
  
  
  let polling_timeout =
    if Unix.getuid () = 0 then Some 20000
    else (
      print_endline "Warning: not running as root, so running in slower non-polling mode";
      None
    )
  
  let () = 
        Eio_main.run 
        @@ fun env ->
        main 3000 128
          ~net:(Eio.Stdenv.net env)
          ~domain_mgr:(Eio.Stdenv.domain_mgr env)
          ~n_domains
  