preprocess:
	@echo **********Creating 1D mesh
	../../bin/interval --dx=1000.0 -- 0.0 10000.0 line

run:
	@echo **********Running simulation
	../../bin/fluidity mphase_inlet_velocity_bc_compressible.flml

input: clean preprocess

clean:
	rm -f *.stat *.steady_state*
	rm -f *.d.* *.vtu
	rm -f *.msh
	rm -f *.ele *.edge *.node *.poly *.bound
	rm -f matrixdump* *.log* *.err*
