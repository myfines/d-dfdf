create_clock -name ulpi_clk -period 16.667 -waveform {0 8.333} [get_ports {ulpi_clk}]
create_clock -name clk -period 37.037 -waveform {0 18.518} [get_ports {clk}]
create_generated_clock -name usb_core_phase -source [get_ports {ulpi_clk}] -divide_by 1 -phase 315 [get_pins {usb_pll/CLKOUTP}]
# USB3317 DS00002366A table4-3: output1.5..3.5ns, inputsetup5ns/hold0.
# PCB skew/roundtrip budget0.5ns assumed, not measured on this Dock.
set_input_delay -clock ulpi_clk -max 4.0 [get_ports {ulpi_dir ulpi_nxt ulpi_data[*]}]
set_input_delay -clock ulpi_clk -min 1.0 [get_ports {ulpi_dir ulpi_nxt ulpi_data[*]}]
set_output_delay -clock ulpi_clk -max 5.5 [get_ports {ulpi_stp ulpi_data[*]}]
set_output_delay -clock ulpi_clk -min -0.5 [get_ports {ulpi_stp ulpi_data[*]}]
set_false_path -from [get_clocks {clk}] -to [get_clocks {ulpi_clk}]
# 27MHz domain only produces POR, released through the two-stage USB reset synchronizer.
set_false_path -from [get_clocks {clk}] -to [get_clocks {usb_core_phase}]
# CLKOUTP=315deg wraps past the next PHY edge after clock insertion.
# The next PHY sampling edge is therefore the second edge after the ideal
# positive-phase launch. Pair setup2/hold1; never apply this to internal paths.
set_multicycle_path 2 -setup -from [get_clocks {usb_core_phase}] -to [get_ports {ulpi_stp ulpi_data[*]}]
set_multicycle_path 1 -hold -from [get_clocks {usb_core_phase}] -to [get_ports {ulpi_stp ulpi_data[*]}]
