(*
 * Copyright (c) 2015 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

module IO = Git_mirage.Sync.IO

module Irmin_git = struct
  let config = Irmin_git.config
  let head = Irmin_git.head
  let bare = Irmin_git.bare
  module AO = Irmin_git.AO
  module type CONTEXT = sig val v: IO.ctx option end
  module Context (C: CONTEXT) = struct
    type t = Git_mirage.Sync.IO.ctx
    let v = C.v
  end
  module Memory (C: CONTEXT) = Irmin_git.Memory_ext(Context(C))(IO)
end

module Task (N: sig val name: string end) (C: V1.CLOCK) = struct
  let f msg =
    let date = Int64.of_float (C.time ()) in
    Irmin.Task.create ~date ~owner:N.name msg
end

module KV_RO (S: Irmin.S) = struct

  open Lwt.Infix

  type error = Unknown_key of string
  type 'a io = 'a Lwt.t
  type t = S.t
  type id
  let disconnect _ = Lwt.return_unit
  type page_aligned_buffer = Cstruct.t

  let unknown_key k = Lwt.return (`Error (Unknown_key k))
  let ok x = Lwt.return (`Ok x)

  let read t path off len =
    S.read t (S.Key.of_hum path) >>= function
    | None   -> unknown_key path
    | Some v ->
      let buf = Tc.write_cstruct (module S.Val) v in
      let buf = Cstruct.sub buf off len in
      ok [buf]

  let size t path =
    S.read t (S.Key.of_hum path) >>= function
    | None   -> unknown_key path
    | Some v -> ok (Int64.of_int @@ Tc.size_of (module S.Val) v)

end
