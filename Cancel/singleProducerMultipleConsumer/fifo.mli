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

module Make () : S