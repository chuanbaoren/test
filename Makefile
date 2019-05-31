DEVICE=semu_b2000_board
DUT=semu_b2000_board
TBNAME=tb_board
#TBNAME=semu_b2000_board
XILINXLIB_PATH=./vcs/xilinx_lib
##########################################################################################################
all: help

help:
	@echo
	@echo "   make compile_libs         : compile xilinx unisim & secureip & ip using -kdb option"
	@echo "   make compile_dut          : compile dut"
	@echo "   make vcs_run              : elaborate design & build simv file"
	@echo "   make run_verdi            : start verdi gui to load fsdb and to debug"
	@echo
##########################################################################################################
.PHONY: compile_xilinx_lib_vcs  compile_ip  compile_secureip delete_work compile_common \
	    compile_zynq compile_fpga compile_dut compile_board compile_tb compile_libs compile_design
compile_xilinx_lib_vcs:
	-@mkdir -p $(XILINXLIB_PATH) 
	@if [ -d $(XILINXLIB_PATH)/unisims_ver ]; then \
	echo "Xilinx library already compiled"; else \
	echo "config_compile_simlib -cfgopt {vcs_mx.verilog.unisim: -kdb}" > $(XILINXLIB_PATH)/$(DEVICE)_simlib.tcl ; \
	echo "compile_simlib -directory $(XILINXLIB_PATH) -family all -language all \
	      -library unisim -no_ip_compile -simulator vcs_mx " >> $(XILINXLIB_PATH)/$(DEVICE)_simlib.tcl ; \
	vivado -mode batch -source $(XILINXLIB_PATH)/$(DEVICE)_simlib.tcl ; \
	#cp $(XILINXLIB_PATH)/synopsys_sim.setup . ;\
	fi;

compile_ip: compile.ip
	@if [ -f ./compile.ip ]; then \
		./compile.ip ; \
	else \
		echo "Error: compile.ip isn't exist in current dir!!"; \
	fi;

compile_secureip: compile.secureip
	@if [ -f ./compile.secureip ]; then \
		-@rm -rf vcs/xilinx_lib/secureip/* ; \
		./compile.secureip ; \
	else \
		echo "Error: compile.secureip isn't exist in current dir!!"; \
	fi;

compile_common: compile.common
	@if [ -f ./compile.common ]; then \
		./compile.common ; \
	else \
		echo "Error: compile.common isn't exist in current dir!!"; \
	fi;

compile_zynq: compile.zynq
	@if [ -f ./compile.zynq ]; then \
		./compile.zynq ; \
	else \
		echo "Error: compile.zynq isn't exist in current dir!!"; \
	fi;

compile_fpga: compile.fpga
	@if [ -f ./compile.fpga ]; then \
		./compile.fpga ; \
	else \
		echo "Error: compile.fpga isn't exist in current dir!!"; \
	fi;

compile_board: compile.board
	@if [ -f ./compile.board ]; then \
		./compile.board ; \
	else \
		echo "Error: compile.board isn't exist in current dir!!"; \
	fi;

compile_dut: compile.dut
	@if [ -f ./compile.dut ]; then \
		./compile.dut ; \
	else \
		echo "Error: compile.dut isn't exist in current dir!!"; \
	fi;

compile_tb: compile.tb
	@if [ -f ./compile.tb ]; then \
		./compile.tb ; \
	else \
		echo "Error: compile.tb isn't exist in current dir!!"; \
	fi;

delete_work: 
	-@rm -rf vcs/work

delete_libs: 
	-@rm -rf vcs/work vcs/common vcs/zynq vcs/fpga

compile_libs: compile_xilinx_lib_vcs  compile_secureip compile_ip
compile_design: delete_work compile_dut compile_board compile_tb
recompile_design: delete_libs compile_common compile_zynq compile_fpga compile_dut compile_board compile_tb

compile_clean:
	-@rm -rf vcs/ .cxl* 
##########################################################################################################
.PHONY: vcs_elab vcs_run vcs_1st_elab vcs_1st_run vcs_clean vcs-distclean
vcs_elab: compile_design
	vcs +lint=TFIPC-L -full64 -debug_pp -l vcs_elaborate.log \
	-P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a \
	work.$(TBNAME) work.glbl -o $(DUT)_simv

vcs_run: vcs_elab
	./$(DUT)_simv +DUMP_FSDB -ucli -do simulate.do -l vcs_simulate.log
	#$(DUT)_simv -l vcs_simulate.log
	#$(DUT)_simv +TESTNAME=sample_smoke_test0 -l vcs_simulate.log

vcs_rerun:
	./$(DUT)_simv +DUMP_FSDB -ucli -do simulate.do -l vcs_simulate.log

vcs_1st_elab: recompile_design
	vcs +lint=TFIPC-L -full64 -debug_pp -l vcs_elaborate.log \
	-P $(VERDI_HOME)/share/PLI/VCS/LINUX64/novas.tab $(VERDI_HOME)/share/PLI/VCS/LINUX64/pli.a \
	work.$(TBNAME) work.glbl -o $(DUT)_simv

vcs_1st_run: vcs_1st_elab
	./$(DUT)_simv +DUMP_FSDB -ucli -do simulate.do -l vcs_simulate.log
	#$(DUT)_simv -l vcs_simulate.log
	#$(DUT)_simv +TESTNAME=sample_smoke_test0 -l vcs_simulate.log

vcs_clean:
	-@rm -rf vcs/ $(DUT)_simv.daidir/ csrc/
	-@rm -f $(DUT)_simv .vlogansetup.args .vlogansetup.env
	-@rm -f vcs_elaborate.log vcs_simulate.log

distclean: vcs_clean
	-@rm -rf compile_simlib.log* novas.conf novas_dump.log synopsys_sim.setup.bak ucli.key verdiLog vivado*.jou vivado*.log *.fsdb*
	-@rm -rf vc_hdrs.h vhdlanLog mb_log.tube frame_data_e2_rbt_out.txt
##########################################################################################################
PAT_NAME = mb_pcie_rp_selftest semu_reg_test semu_adder_test

.PHONY: $(PAT_NAME)

.ONESHELL:
build_bsp:
	cd ../../software/mb_pcie_rp_bsp
	cd microblaze_0/include
	./delete_extra_h
	cd ../.. 
	make clean && make all
	cd ../../sim/mb_pcie_rp

$(PAT_NAME): build_bsp
	rm -f mb_pcie_rp_blk_mem_gen_0_0.mem
	rm -f mb_pcie_rp_lmb_bram_0.mem
	cd ../../software/scenario/$@/Debug
	make clean && make all
	cd ../../../../sim/mb_pcie_rp
	ln -s ../../software/scenario/$@/Debug/mb_pcie_rp_blk_mem_gen_0_0.mem .
	ln -s ../../software/scenario/$@/Debug/mb_pcie_rp_lmb_bram_0.mem .

##########################################################################################################
.PHONY: run_verdi
run_verdi:
	-@verdi -nologo -simflow -top $(TBNAME) &
