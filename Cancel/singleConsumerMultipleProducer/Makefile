OCAMLPATH=~/repos/ocaml-multicore/_install/bin/

all:
#	ocamlfind ocamlopt -o test_fifo.exe -linkpkg -package cancel_unified_interface,eio,eio_main,eio_linux,eio_luv -thread fifo.mli fifo.ml wo_cancel_benchmark.ml
	ocamlfind ocamlopt -o wo_cancel.exe -linkpkg -package cancel_unified_interface -thread fifo.mli fifo.ml wo_cancel_benchmark.ml
	ocamlfind ocamlopt -o with_cancel.exe -linkpkg -package cancel_unified_interface -thread fifo.mli fifo.ml with_cancel_benchmark.ml

clean:
	rm -f *~ *.cm* *.o *.out *.exe
