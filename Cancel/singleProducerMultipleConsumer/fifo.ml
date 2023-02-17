open Printf
open Effect
open Effect.Deep
open Cancel_unified_interface

exception Abort


module type S = sig
  type state = Running | Cancelled | Terminated

(* Referring Affect library *)
  type fiber = E : t -> fiber
  and t = { fiber : fiber;
            tid : int ; 
            mutable state : state ;
            mutable cancel_fn : exn -> unit ;
          }

  val fork : (unit -> unit) -> t
  val yield : unit -> unit
  val run : (unit -> unit) -> unit
  val cancel : t -> unit
end

module Make () : S = struct


let counter = Atomic.make 0
let create_ID () = Atomic.fetch_and_add counter 1


let suspend_count = Atomic.make 0
let m = Mutex.create ()
(*let cv = Condition.create ()
*)

  
 type state = Running | Cancelled | Terminated

(* Referring Affect library *)
  type fiber = E : t -> fiber
  and t = { fiber : fiber;
            tid : int ; 
            mutable state : state ;
            mutable cancel_fn : exn -> unit ;
          }
  type _ Effect.t += Fork  : (t * (unit -> unit)) -> unit Effect.t
  type _ Effect.t += Yield : unit Effect.t

  type 'a record_check = {k:('a, unit) continuation; fiber: t}

  let make_fiber ?(state = Running) () =  
    let rec f = {fiber = E f; tid = create_ID (); state; cancel_fn = ignore} in f

  let run main =
    let run_q = Queue.create () in
    let enqueue (t: 'a record_check) v =
      Mutex.lock m;
      Queue.push  (t, v) run_q;
      Mutex.unlock m;
    in
    let rec dequeue () =
    (* Check the value of v in case of exception *)
        Mutex.lock m;
        if (not (Queue.is_empty run_q)) then
          let (t, v) = Queue.pop run_q 
          in
          (if t.fiber.state = Running then
            begin
              Mutex.unlock m;
              continue t.k v
            end
          else
            begin
              try discontinue t.k Abort with
              | Abort -> Mutex.unlock m;
                         (* printf "\nSome fiber %d got aborted\n%!" t.fiber.tid; *)
                         dequeue ()
            end
            )
        else
        begin
          Mutex.unlock m;
          (* Mutex.lock m; *)
          (* Inefficinetly doing spinning *)
          while (((Atomic.get suspend_count) > 0) && (Queue.is_empty run_q))  do
          ()
            (* Condition.wait cv m  *)
          done;
          (* Mutex.unlock m; *)
          (* Check runqueue again *)
          Mutex.lock m;
          if (not (Queue.is_empty run_q)) then
              begin
              Mutex.unlock m;
              dequeue ()
              end
        end
    in
    let rec spawn ~new_fiber:fiber f =
      match_with f ()
      { retc = (fun () -> dequeue ());
        exnc = ((fun ex ->
                   Printexc.raise_with_backtrace ex (Printexc.get_raw_backtrace ())));
        effc = fun (type a) (e : a Effect.t) ->
          match e with
          | Sched.Suspend f -> Some (fun (k: (a,_) continuation) ->
              Atomic.incr suspend_count;
              let t = { k; fiber } in
              (* If cancelled then increase the counter again so the scheduler wont wait *)
              let resumer v = 
                if fiber.state = Running then
                  begin
                              enqueue (Obj.magic t) v;
                              Atomic.decr suspend_count;
                              (* (if(Atomic.get suspend_count = 0) then *)
                                (* Condition.signal cv; *)
                                (* ); *)
                              (* Printf.printf "\nResumer is being executed and enqueued %d\n%!" fiber.tid; *)                    
                  Sched.Resume_success
                  end
                else
                  begin
                  Sched.Resume_failure
                  end
              in 
              let cancellation_function (ex:exn) = (
                  (* printf "\n Fiber %d got aborted\n%!" fiber.tid; *)
                  Atomic.decr suspend_count;
                  (* (if(Atomic.get suspend_count = 0) then
                      Condition.signal cv); *)
                  )
              in
              if f (Obj.magic resumer) then
                begin
                  (* printf "\n Fiber %d suspended \n%!" fiber.tid; *)
                  fiber.cancel_fn <- (cancellation_function);
                  dequeue ()
                end
              else 
                discontinue k Exit
            )
          | Yield -> Some (fun (k: (a,_) continuation) ->
              let t = { k; fiber } in 
              enqueue (Obj.magic t) (); 
              dequeue ())
          | Fork (new_fiber, f) -> Some (fun (k: (a,_) continuation) ->
              let t = { k; fiber } in
              enqueue (Obj.magic t) (); 
              spawn ~new_fiber f
              )
          | _ -> None }
    in
    let new_fiber = (make_fiber ()) in
    spawn ~new_fiber main

  let fork f = 
    let new_fiber = make_fiber () in 
    perform (Fork (new_fiber, f));
    new_fiber
  
  let yield () = perform Yield


  let cancel fiber = 
    match fiber.state with
    | Running -> fiber.state <- Cancelled; fiber.cancel_fn (Abort)
    | Cancelled | Terminated -> Printf.printf "Already cancelled/done no!"
end
