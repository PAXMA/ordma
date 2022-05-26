open Ocamlbuild_plugin
open Unix

let run_cmd cmd () =
  try
    let ch = Unix.open_process_in cmd in
    let line = input_line ch in
    let () = close_in ch in
    line
  with | End_of_file -> "Not available"


let make_version_and_meta _ _ =
  let tag_version    = run_cmd "git describe --tags --exact-match --dirty" in
  let branch_version = run_cmd "git describe --all" in
  let (major,minor,patch) =
    try
      Scanf.sscanf (tag_version ()) "%i.%i.%i" (fun ma mi p -> (ma,mi,p))
    with _ ->
      let bv = branch_version () in
      try Scanf.sscanf bv "heads/%i.%i" (fun ma mi -> (ma,mi,-1))
      with _ -> (-1,-1,-1)
  in
  let git_revision = run_cmd "git describe --all --long --always --dirty" () in
  let lines = [
      Printf.sprintf "let major = %i\n" major;
      Printf.sprintf "let minor = %i\n" minor;
      Printf.sprintf "let patch = %i\n" patch;
      Printf.sprintf "let git_revision = %S\n" git_revision;
      "let summary = (major, minor , patch , git_revision)\n" 
    ]
  in
  let write_version = Echo (lines, "ordma_version.ml") in
  let clean_version =
    match patch with
    | -1 -> git_revision
    | _  -> Printf.sprintf "%i.%i.%i" major minor patch
  in
  let meta_lines = [
      "description = \"librdmacm binding\"\n";
      Printf.sprintf "version = %S\n" clean_version;
      "requires = \"lwt_log\"\n";
      "exists_if = \"libordma.cmxs,libordma.cmxa\"\n";
      "archive(byte) = \"libordma.cma\"\n";
      "archive(native) = \"libordma.cmxa\"\n";
      "linkopts = \"-cclib -lordma_c -cclib -lrdmacm\"\n"
    ]
  in
  let write_meta = Echo (meta_lines, "META") in
  Seq [write_version;write_meta]
       
       
let _ =
  dispatch
  & function
    | After_rules ->
       flag ["compile";"c";]
            (S[
                 A"-ccopt"; A"-Wall";
                 A"-ccopt"; A"-Wextra";
                 A"-ccopt"; A"-Werror";
                 A"-ccopt"; A"-ggdb3";
                 A"-ccopt"; A"-O2";
            ]);
       dep ["compile";"c";]["ordma_debug.h"];
       rule "ordma_version.ml" ~prod:"ordma_version.ml" make_version_and_meta;
       
    | _ -> ()
