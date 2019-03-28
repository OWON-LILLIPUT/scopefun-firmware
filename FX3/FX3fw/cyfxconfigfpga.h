/*
----------------------------------------------------------------------------------
--    Copyright (C) 2019 Dejan Priversek
--
--    This program is free software: you can redistribute it and/or modify
--    it under the terms of the GNU General Public License as published by
--    the Free Software Foundation, either version 3 of the License, or
--    (at your option) any later version.
--
--    This program is distributed in the hope that it will be useful,
--    but WITHOUT ANY WARRANTY; without even the implied warranty of
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--    GNU General Public License for more details.
--
--    You should have received a copy of the GNU General Public License
--    along with this program.  If not, see <http://www.gnu.org/licenses/>.
----------------------------------------------------------------------------------
*/

#ifndef CYFXCONFIGFPGA_H_
#define CYFXCONFIGFPGA_H_

//Slave fifo Application FW specific defines
#define CY_FX_SLFIFO_DMA_BUF_COUNT      (16)         /* Slave FIFO channel U to P buffer count */

#define FPGA_INIT_B 52
#define FPGA_DONE 50
#define ADC_RESETN 26
#define ADC_CLK_EN 51

/* Buffer used for USB event logs. */
extern uint8_t *gl_UsbLogBuffer;
#define CYFX_USBLOG_SIZE (0x1000)

//Vendor command code used in FPGA slave serial application
#define VND_CMD_SLAVESER_CFGLOAD 0xB2
#define VND_CMD_SLAVESER_CFGSTAT 0xB1

//Vendor command code used for OS Feature Descriptor
#define VND_CMD_GET_MS_DESCRIPTOR 0xDD  //this is the bMS_VendorCode

//Events
#define CY_FX_CONFIGFPGAAPP_START_EVENT          (1 << 0)   /* event to initiate FPGA configuration */
#define CY_FX_CONFIGFPGAAPP_SW_TO_SLFIFO_EVENT   (1 << 1)   /* event to initiate switch back to slave FIFO*/



extern CyU3PDmaChannel glChHandleUtoCPU;   /* DMA Channel handle for U2CPU transfer. */

extern CyBool_t glConfigDone;			/* Flag to indicate the status of FPGA configuration  */
extern CyBool_t glConfigStarted;		/* Flag to indicate that FPGA configuration was attempted */

extern uint32_t filelen;					/* length of Configuration file (.bin) */

extern uint16_t uiPacketSize;

extern volatile CyBool_t glIsApplnActive;

extern CyU3PEvent glFxConfigFpgaAppEvent;    /* Configure FPGA event group. */

extern uint8_t *seqnum_p;




extern void
CyFxAppErrorHandler (
        CyU3PReturnStatus_t apiRetStatus    /* API return status */
        );

extern CyBool_t
CyFxSlFifoApplnUSBSetupCB (
        uint32_t setupdat0,
        uint32_t setupdat1
    );

extern void
CyFxSlFifoApplnUSBEventCB (
    CyU3PUsbEventType_t evtype,
    uint16_t            evdata
    );

extern CyBool_t
CyFxApplnLPMRqtCB (
        CyU3PUsbLinkPowerMode link_mode);

extern void
CyFxConfigFpgaApplnStart (
        void);

extern void
CyFxConfigFpgaApplnInit (void);

extern CyU3PReturnStatus_t CyFxConfigFpga(uint32_t uiLen);

extern void
CyFxConfigFpgaApplnStop (
        void);

extern void gpif_error_cb(CyU3PPibIntrType cbType, uint16_t cbArg);

#endif /* CYFXCONFIGFPGA_H_ */
