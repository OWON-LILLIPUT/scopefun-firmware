# ScopeFun Cypress FX3 Firmware Sources

This is the ScopeFun firmware source code for [Cypress FX3 USB 3.0 Superspeed controller](http://www.cypress.com/products/ez-usb-fx3-superspeed-usb-30-peripheral-controller).

FX3 firmware handles:

  - USB data transfers between FX3 32-bit GPIF-II programmable interface and USB port
  - EEPROM programming and readout via FX3 I2C interface
  - FPGA programming via FX3 SPI interface
  - Custom vendor requests (FX3, FPGA and ADC reset; hardware suspend/resume, ...)

## Getting started

For comiling the FX3 firmware you must install the [FX3 SDK](http://www.cypress.com/documentation/software-and-drivers/ez-usb-fx3-software-development-kit) and import FX3fw project into the EZ USB Suite.

## Licensing

FX3 firmware source files are licensed under GNU General Public License v3 (GPLv3). For details please see the COPYING file(s) and file headers.

Please note however that license terms stated do not extend to any files provided with the Cypress FX3 SDK. For information regarding Cypress license plase refer to license.txt provided with the FX3 SDK in the following path: \<Install Directory>\Cypress\EZ-USB FX3 SDK\1.3\license