PROJECT = VX_pipeline
TOP_LEVEL_ENTITY = VX_pipeline
SRC_FILE = VX_pipeline.v
FPU_INCLUDE = ../../../rtl/fp_cores;../../../rtl/fp_cores/altera/arria10;../../../rtl/fp_cores/fpnew/src;../../../rtl/fp_cores/fpnew/src/fpu_div_sqrt_mvp/hdl;../../../rtl/fp_cores/fpnew/src/common_cells/include;../../../rtl/fp_cores/fpnew/src/common_cells/src
RTL_INCLUDE = $(FPU_INCLUDE);../../../rtl;../../../rtl/libs;../../../rtl/interfaces
PROJECT_FILES = $(PROJECT).qpf $(PROJECT).qsf

# Part, Family
FAMILY = "Arria 10"
DEVICE = 10AX115N3F40E2SG   

# Executable Configuration
SYN_ARGS = --parallel --read_settings_files=on
FIT_ARGS = --parallel --part=$(DEVICE) --read_settings_files=on
ASM_ARGS =
STA_ARGS = --parallel --do_report_timing

# Build targets
all: $(PROJECT).sta.rpt

syn: $(PROJECT).syn.rpt

fit: $(PROJECT).fit.rpt

asm: $(PROJECT).asm.rpt

sta: $(PROJECT).sta.rpt

smart: smart.log

# Target implementations
STAMP = echo done >

$(PROJECT).syn.rpt: smart.log syn.chg $(SOURCE_FILES) 
	quartus_syn $(PROJECT) $(SYN_ARGS)
	$(STAMP) fit.chg

$(PROJECT).fit.rpt: smart.log fit.chg $(PROJECT).syn.rpt
	quartus_fit $(PROJECT) $(FIT_ARGS)
	$(STAMP) asm.chg
	$(STAMP) sta.chg

$(PROJECT).asm.rpt: smart.log asm.chg $(PROJECT).fit.rpt
	quartus_asm $(PROJECT) $(ASM_ARGS)

$(PROJECT).sta.rpt: smart.log sta.chg $(PROJECT).fit.rpt
	quartus_sta $(PROJECT)  $(STA_ARGS) 

smart.log: $(PROJECT_FILES)
	quartus_sh --determine_smart_action $(PROJECT) > smart.log

# Project initialization
$(PROJECT_FILES):
	quartus_sh -t ../project.tcl -project $(PROJECT) -family $(FAMILY) -device $(DEVICE) -top $(TOP_LEVEL_ENTITY) -src "$(SRC_FILE)" -sdc ../project.sdc -inc "$(RTL_INCLUDE)"
	
syn.chg:
	$(STAMP) syn.chg

fit.chg:
	$(STAMP) fit.chg

sta.chg:
	$(STAMP) sta.chg

asm.chg:
	$(STAMP) asm.chg

timing: $(PROJECT_FILES)
	quartus_sh -t ../timing-html.tcl -project $(PROJECT)

program: $(PROJECT).sof
	quartus_pgm --no_banner --mode=jtag -o "$(PROJECT).sof"

clean:
	rm -rf bin *.rpt *.chg *.qsf *.qpf *.qws *.log *.htm *.eqn *.pin *.sof *.pof qdb incremental_db tmp-clearbox
