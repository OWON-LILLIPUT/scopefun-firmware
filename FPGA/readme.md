# ScopeFun FPGA firmware sources

This is the [Xilinx Artix-7 FPGA](https://www.xilinx.com/products/silicon-devices/fpga/artix-7.html) firmware source code for ScopeFun.

## Getting started

For compiling the FPGA firmware you must install the [Vivado Design Suite (WebPACK edition)](https://www.xilinx.com/products/design-tools/vivado/vivado-webpack.html) from Xilinx. Recommended Vivado version is [2018.3.1](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/vivado-design-tools/2018-3.html) with installed patch ([AR# 71898](https://www.xilinx.com/support/answers/71898.html)) 

After completing Vivado installation run the "gen_project.tcl" script from Vivado (Tools -> Run Tcl Script). This will create a new project and link ScopeFun sources from "srcs" folder.

## Licensing

ScopeFun FGPA firmware sources are licensed under GNU General Public License v3 (GPLv3). For details please see the COPYING file(s) and file headers.