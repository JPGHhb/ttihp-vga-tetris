PROJ = vga_tetris
PIN_DEF = ice40-io-video.pcf
DEVICE = hx8k
PACKAGE = ct256
PROG = ../fpga_upload/iceprogduino
YOSYS_DIR = LatticeFPGATools/yosys/bin
YOSYS = $(YOSYS_DIR)/bin/yosys
NEXTPNR=LatticeFPGATools/nextpnr/bin/bin/nextpnr-ice40
ICEPACK=LatticeFPGATools/icestorm/bin/bin/icepack
ICETIME=LatticeFPGATools/icestorm/bin/bin/icetime

COMMON_VERILOG_SOURCES = ../src/project.v ../src/VGATetris.v pll.sv vga_tetris_top.sv

VERILOG_SOURCES = $(YOSYS_DIR)/share/yosys/ice40/cells_sim.v $(COMMON_VERILOG_SOURCES)

TOP_LEVEL = vga_tetris_top

all: $(PROJ).rpt $(PROJ).bin

%.blif %.json : $(VERILOG_SOURCES)
	$(YOSYS) -m slang -p 'read_slang $(VERILOG_SOURCES) -top $(TOP_LEVEL); synth_ice40 -top $(TOP_LEVEL) -blif $@ -json $*.json'

%.asc: $(PIN_DEF) %.blif %.json
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --json $*.json --asc $@ --pcf $(PIN_DEF)

%.bin: %.asc
	$(ICEPACK) $< $@

%.rpt: %.asc
	$(ICETIME) -d $(DEVICE) -mtr $@ $<

prog: $(PROJ).bin
	sudo $(PROG) -v $<

sudo-prog: $(PROJ).bin
	@echo 'Executing prog as root!!!'
	sudo $(PROG) $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).bin $(PROJ).rpt


.PHONY: all prog clean



