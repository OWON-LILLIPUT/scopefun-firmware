###############################################################################
#    Copyright (C) 2016 Dejan Priversek
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the-
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
###############################################################################

#adc clock is 250 Mhz, waveform is inverted (p/n clock pins are swapped on pcb)
create_clock -period 4.000 -name clk_adc_p -waveform {2.000 4.000} [get_ports clk_adc_p]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets clk_adc_p]
# jitter value specified as nanoseconds
set_input_jitter clk_adc_p 0.012

#ADC interface data fifo
#set_protperty IODELAY_GROUP IODELAY_ADC_IF [get_cells ADC_interface/*]

#disable CDC registers timing check
#set_max_delay -datapath_only -from [get_cells ADC_interface/data_fifo_16x20b/enb_reg*] -to [get_cells ADC_interface/data_fifo_16x20b/enb_d_reg*] 2.000
#set_max_delay -datapath_only -from [get_cells ADC_interface/data_fifo_16x20b/*/RAMC_D1] -to [get_cells {ADC_interface/data_fifo_16x20b/do_reg[*]}] 1.500
#calib_done to ADC interface fifo enable
set_max_delay -datapath_only -from [get_pins calib_done_reg/C] -to [get_pins ADC_interface/data_fifo_16x20b/we_d_reg/D] 2.000
#calib_start to ADC interface calib start
set_max_delay -datapath_only -from [get_pins read_calib_start_reg/C] -to [get_pins ADC_interface/read_calib_start_reg/D] 2.000
set_max_delay -datapath_only -from [get_pins read_calib_source_reg/C] -to [get_pins ADC_interface/read_calib_source_reg/D] 2.000

#global reset to DDR3 sample write buffer reset
#set_false_path -from [get_pins gl_reset_reg/C] -to [get_pins RAM_DDR3_inst/write_buff/reset_reg/D]
#set_false_path -from [get_pins gl_reset_reg/C] -to [get_pins RAM_DDR3_inst/write_buff/rst_d_reg/D]
#set_false_path -from [get_pins gl_reset_reg/C] -to [get_pins RAM_DDR3_inst/ram/ui_reset_d_reg/D]
#set_false_path -from [get_pins gl_reset_reg/C] -to [get_pins RAM_DDR3_inst/read_buff/rst_d_reg/D]

set_false_path -from [get_pins clearflags*/C] -to [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/reset_reg/D]
set_false_path -from [get_pins clearflags*/C] -to [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/rst_d_reg/D]
#set_false_path -from [get_pins clearflags_d/C] -to [get_pins RAM_DDR3_inst/ram/ui_reset_d_reg/D]
#set_false_path -from [get_pins clearflags_d/C] -to [get_pins RAM_DDR3_inst/RAM_READ_FIFO/rst_d_reg/D]

#ignore timing error for distributed RAM (reads are performed after writes)
set_max_delay -datapath_only -from [get_pins config_RAM/RAM_reg_0_63_*/DP/CLK] -to [get_pins {config_RAM/do2_reg[*]/D}] 2.000

#clk_adc / clk_fx3 to AWG clk
#AWG signal output to core (for trigger)
set_max_delay -datapath_only -from [get_pins {signal_generator_inst/genSignal_1_reg[*]/C}] -to [get_pins {genSignal_1_d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {signal_generator_inst/genSignal_2_reg[*]/C}] -to [get_pins {genSignal_2_d_reg[*]/D}] 2.000
#AWG enable signal
set_false_path -from [get_pins sig_out_enable_d_reg/C] -to [get_pins signal_generator_inst/generator1On_d_reg/D]
set_false_path -from [get_pins sig_out_enable_d_reg/C] -to [get_pins signal_generator_inst/generator2On_d_reg/D]
set_false_path -from [get_pins generator1On_reg/C] -to [get_pins signal_generator_inst/generator1On_d_reg/D]
set_false_path -from [get_pins generator2On_reg/C] -to [get_pins signal_generator_inst/generator2On_d_reg/D]

#AWG inputs
set_max_delay -datapath_only -from [get_pins {generator1Delta_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorDelta_1_i_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {generator2Delta_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorDelta_2_i_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {generator1Duty_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorDuty_1d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {generator2Duty_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorDuty_2d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {generator1Offset_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorOffset_1d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {generator2Offset_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorOffset_2d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {generator1Type_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorType_1d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {generator2Type_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorType_2d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {generator1Voltage_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorVoltage_1d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {generator2Voltage_reg[*]/C}] -to [get_pins {signal_generator_inst/generatorVoltage_2d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins {phase_val_reg[*]/C}] -to [get_pins {signal_generator_inst/phase_val_i_reg[*]/D}] 2.000

#clk_adc to clk_fx3 CDC
set_max_delay -datapath_only -from [get_cells {timebase_d_reg[*]}] -to [get_cells {timebase_dd_reg[*]}] 2.000
set_max_delay -datapath_only -from [get_pins triggered_reg/C] -to [get_pins triggered_d_reg/D] 2.000
set_max_delay -datapath_only -from [get_pins {framesize_d_reg[*]/C}] -to [get_pins {framesize_dd_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins getnewframe_reg/C] -to [get_pins getnewframe_d_reg/D] 2.000
set_max_delay -datapath_only -from [get_pins {RAM_DDR3_inst/PreTrigSavingCnt_reg[*]/C}] -to [get_pins {RAM_DDR3_inst/PreTrigSavingCnt_d_reg[*]/D}] 2.000
set_max_delay -datapath_only -from [get_pins clearflags*/C] -to [get_pins RAM_DDR3_inst/rst_d_reg/D] 2.000

#clk_fx3 to clk_adc CDC
set_max_delay -datapath_only -from [get_cells {an_trig_delay_reg[*]}] -to [get_cells {an_trig_delay_d_reg[*]}] 2.000
set_max_delay -datapath_only -from [get_pins clearflags_reg/C] -to [get_pins clearflags_d_reg/D] 2.000
set_max_delay -datapath_only -from [get_pins sig_out_enable_reg/C] -to [get_pins sig_out_enable_d_reg/D] 2.000
set_max_delay -datapath_only -from [get_pins requestFrame_reg/C] -to [get_pins requestFrame_d_reg/D] 2.000
set_max_delay -datapath_only -from [get_pins RAM_DDR3_inst/PreTrigSavingCntRecvd_reg/C] -to [get_pins RAM_DDR3_inst/PreTrigSavingCntRecvd_d_reg/D] 2.000
set_max_delay -datapath_only -from [get_pins RAM_DDR3_inst/ram_rdy_i_reg/C] -to [get_pins RAM_DDR3_inst/ram_rdy_reg/D] 2.000
set_max_delay -datapath_only -from [get_pins {pre_trigger_d_reg[*]/C}] -to [get_pins {RAM_DDR3_inst/RAM/wr_pretriglen_reg[*]/D}] 2.000


#DDR3 controller
# write FIFO reset
# clk_adc -> clk_fx3
set_max_delay -datapath_only -from [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/FIFO_DUALCLOCK_MACRO_inst1/bl.fifo_36_inst_bl_1.fifo_36_bl_1/WRCLK] -to [get_pins RAM_DDR3_inst/fwr_AlmostFull_d_reg/D] 2.000
set_false_path -from [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/rst_i_reg/C] -to [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/FIFO_DUALCLOCK_MACRO_inst1/bl.fifo_36_inst_bl_1.fifo_36_bl_1/RST]
set_false_path -from [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/rst_i_reg/C] -to [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/FIFO_DUALCLOCK_MACRO_inst2/bl.fifo_36_inst_bl_1.fifo_36_bl_1/RST]
set_false_path -from [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/reset_reg/C] -to [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/FIFO_DUALCLOCK_MACRO_inst1/bl.fifo_36_inst_bl_1.fifo_36_bl_1/RDEN]
set_false_path -from [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/reset_reg/C] -to [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/FIFO_DUALCLOCK_MACRO_inst2/bl.fifo_36_inst_bl_1.fifo_36_bl_1/RDEN]

# signals start moving samples from WRITE FIFO into DDR3 RAM
set_max_delay -from [get_pins RAM_DDR3_inst/RAM_WRITE_FIFO/FIFO_DUALCLOCK_MACRO_inst1/bl.fifo_36_inst_bl_1.fifo_36_bl_1/WRCLK] -to [get_pins RAM_DDR3_inst/fwr_AlmostFull_d_reg/D] 2.000

# ADC clock interface is a Source-synchronous DDR interface (min/max times taken from KAD5510P data-sheet)
# clk-to-data delay wrt rising edge : min -260 ps, max 120 ps
# clk-to-data delay wrt falling edge: min -160 ps, max 230 ps
# note: clock is taken from CH1 ADC and clock pins are swapped on pcb
# there is a 180 degree phase shift between ADC1 and ADC2 sampling clock
set_input_delay -clock [get_clocks clk_adc_p] -clock_fall -min -add_delay -0.260 [get_ports {dataA_p[*]}]
set_input_delay -clock [get_clocks clk_adc_p] -clock_fall -max -add_delay 0.120 [get_ports {dataA_p[*]}]
set_input_delay -clock [get_clocks clk_adc_p] -min -add_delay -0.160 [get_ports {dataA_p[*]}]
set_input_delay -clock [get_clocks clk_adc_p] -max -add_delay 0.230 [get_ports {dataA_p[*]}]
# above contraints for dataA inputs are for static timing analasys only
# dynamic calibration is used to find the center of a data eye
# so we can disable timing analysis for dataA inputs with the following line
set_false_path -from [get_ports {dataA_p[*]}] -to [get_pins {ADC_interface/data_ddr_to_se[*].data1_ddr_to_se/D}]
# report_timing -from [get_ports {dataA_p[*]}] -to [get_pins {ADC_interface/data_ddr_to_se[*].data1_ddr_to_se/D}] -delay_type min_max -max_paths 10 -sort_by group -input_pins -routable_nets -name timing_1
# use static timing analysis for dataB ports (we use fixed IDELAY value for dataB inputs)
set_input_delay -clock [get_clocks clk_adc_p] -clock_fall -min -add_delay 1.840 [get_ports {dataB_p[*]}]
set_input_delay -clock [get_clocks clk_adc_p] -clock_fall -max -add_delay 2.230 [get_ports {dataB_p[*]}]
set_input_delay -clock [get_clocks clk_adc_p] -min -add_delay 1.740 [get_ports {dataB_p[*]}]
set_input_delay -clock [get_clocks clk_adc_p] -max -add_delay 2.120 [get_ports {dataB_p[*]}]
set_false_path -from [get_ports {dataB_p[*]}] -to [get_pins {ADC_interface/data_ddr_to_se[*].data2_ddr_to_se/D}]

#set_input_delay -clock [get_clocks clk_fx3] -add_delay 1.100 [get_ports {fdata[*]}]
#set_input_delay -clock [get_clocks clk_adc_dclk] -add_delay 1.100 [get_ports {dataB[*]}]

#report out skew of dac_data vs dac_clk
create_generated_clock -name dac_clk_1 -source [get_pins dac_interface/ODDR_CLK/C] -divide_by 1 [get_ports dac_clk_1]
set_output_delay -clock [get_clocks dac_clk_1] -clock_fall -min -add_delay -0.500 [get_ports {dac_data[*]}]
set_output_delay -clock [get_clocks dac_clk_1] -clock_fall -max -add_delay 0.500 [get_ports {dac_data[*]}]
set_output_delay -clock [get_clocks dac_clk_1] -min -add_delay -0.500 [get_ports {dac_data[*]}]
set_output_delay -clock [get_clocks dac_clk_1] -max -add_delay 0.500 [get_ports {dac_data[*]}]

#ignore timing for async signals
set_max_delay -datapath_only -from [get_pins {DebugADCState_reg[*]/C}] -to [get_pins {DebugADCState_d_reg[*]/D}] 4.000




