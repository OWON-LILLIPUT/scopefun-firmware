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

#include "cyu3system.h"
#include "cyu3os.h"
#include "cyu3dma.h"
#include "cyu3error.h"
#include "cyu3usb.h"
#include "cyu3gpio.h"
#include "cyu3spi.h"
#include "cyu3uart.h"
#include "cyfxslfifosync.h"
#include "cyu3gpif.h"
#include "cyu3pib.h"
#include "pib_regs.h"
#include "cyfxconfigfpga.h"
#include "cyu3lpp.h"
#include "cyu3utils.h"

/* Initialize FX3 GPIF interface                      */
/* Configure FPGA via SPI interface                   */

CyU3PDmaChannel glChHandleUtoCPU;   /* DMA Channel handle for U2CPU transfer. */

CyBool_t glConfigDone = CyTrue;	   /* Flag to indicate that FPGA configuration is done */
                                   /* here we set the variable to CyTrue and later de-assert it if error is detected */
CyBool_t glConfigStarted = CyFalse;/* Flag indicates that FPGA configuration has been attempted */

uint32_t filelen = 0;				/* length of Configuration file (.bin) */

CyU3PEvent glFxConfigFpgaAppEvent;  /* Configure FPGA event group. */

uint16_t uiPacketSize = 0;

uint8_t *gl_UsbLogBuffer = NULL;

static const char hexchar[16] = "0123456789ABCDEF";
static uvint32_t *EFUSE_DIE_ID = ((uvint32_t *)0xE0055010);
uint32_t die_id[2];

/* This function writes configuration data to the xilinx FPGA */
CyU3PReturnStatus_t CyFxConfigFpga(uint32_t uiLen)
{
      uint32_t uiIdx;

      CyU3PReturnStatus_t apiRetStatus;
      CyU3PDmaBuffer_t inBuf_p;
      CyBool_t xFpga_Done, xFpga_Init_B;

      glConfigStarted = CyTrue;

      CyU3PDebugPrint (6, "file length: %d\n", uiLen);
      /* Pull PROG_B line to reset FPGA */
      apiRetStatus = CyU3PSpiSetSsnLine (CyFalse);
      CyU3PGpioSimpleGetValue (FPGA_INIT_B, &xFpga_Init_B);

      CyU3PGpioSimpleGetValue (FPGA_INIT_B, &xFpga_Init_B);

          	  if (xFpga_Init_B)
          	  {
          		glConfigDone = CyFalse;
          		return apiRetStatus;
          	  }
      CyU3PThreadSleep(10);
      /* Release PROG_B line */
      apiRetStatus |= CyU3PSpiSetSsnLine (CyTrue);
      CyU3PThreadSleep(100);   // Allow FPGA to startup
      /* Check if FPGA is now ready by testing the FPGA_Init_B signal */
      apiRetStatus |= CyU3PGpioSimpleGetValue (FPGA_INIT_B, &xFpga_Init_B);
      if( (xFpga_Init_B != CyTrue) || (apiRetStatus != CY_U3P_SUCCESS) ){

          return apiRetStatus;
    }

      /* Start shifting out configuration data */
    for(uiIdx = 0; (uiIdx < uiLen) && glIsApplnActive; uiIdx += uiPacketSize ){
      //FX3 needs to receive data (fpga.bin) within 2000 ms after 0xB2
      if(CyU3PDmaChannelGetBuffer (&glChHandleUtoCPU, &inBuf_p, 2000) != CY_U3P_SUCCESS){ // Wait 2000 ms(?)
    	  glConfigDone = CyFalse;

    	  apiRetStatus = CY_U3P_ERROR_TIMEOUT;
            break;
      }

      apiRetStatus = CyU3PSpiTransmitWords(inBuf_p.buffer , uiPacketSize);
      if (apiRetStatus != CY_U3P_SUCCESS){

    	  glConfigDone = CyFalse;
    	  break;
      }

            if(CyU3PDmaChannelDiscardBuffer (&glChHandleUtoCPU) != CY_U3P_SUCCESS){ // Wait 2000 ms(?)
            	glConfigDone = CyFalse;

            	apiRetStatus = CY_U3P_ERROR_TIMEOUT;
            break;
            }
    }

    CyU3PThreadSleep(10);

    apiRetStatus |= CyU3PGpioSimpleGetValue (FPGA_DONE, &xFpga_Done);
    if( (xFpga_Done != CyTrue) ){
    	glConfigDone = CyFalse;
      apiRetStatus = CY_U3P_ERROR_FAILURE;
    }

    return apiRetStatus;

}

void
CyFxConfigFpgaApplnStart (
        void)
{
    uint16_t size = 0;
    CyU3PEpConfig_t epCfg;
    CyU3PDmaChannelConfig_t dmaCfg;
    CyU3PReturnStatus_t apiRetStatus = CY_U3P_SUCCESS;
    CyU3PUSBSpeed_t usbSpeed = CyU3PUsbGetSpeed();


    CyU3PDebugPrint (4, "CyFxConfigFpgaApplnStart...");
    /* First identify the usb speed. Once that is identified,
     * create a DMA channel and start the transfer on this. */

    /* Based on the Bus Speed configure the endpoint packet size */
    switch (usbSpeed)
    {
        case CY_U3P_FULL_SPEED:
            size = 64;
            break;

        case CY_U3P_HIGH_SPEED:
            size = 512;
            break;

        case  CY_U3P_SUPER_SPEED:
            size = 1024;
            break;

        default:
            CyU3PDebugPrint (4, "Error! Invalid USB speed.\n");
            CyFxAppErrorHandler (CY_U3P_ERROR_FAILURE);
            break;
    }

    CyU3PMemSet ((uint8_t *)&epCfg, 0, sizeof (epCfg));
    epCfg.enable = CyTrue;
    epCfg.epType = CY_U3P_USB_EP_BULK;
    epCfg.burstLen = 1;
    epCfg.streams = 0;
    epCfg.pcktSize = size;

    uiPacketSize = size;


    /* EP2OUT configuration */
    apiRetStatus = CyU3PSetEpConfig(P_DCONFIG_EP2OUT, &epCfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "P_DCONFIG_EP2OUT config failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler (apiRetStatus);
    }

    /* Create a DMA MANUAL channel for U2CPU transfer.
     * DMA size is set based on the USB speed. */
    dmaCfg.size  = size;
    dmaCfg.count = CY_FX_SLFIFO_DMA_BUF_COUNT;
    dmaCfg.prodSckId = CY_FX_P1_USB_SOCKET;
    dmaCfg.consSckId = CY_U3P_CPU_SOCKET_CONS;
    dmaCfg.dmaMode = CY_U3P_DMA_MODE_BYTE;
    /* Enabling the callback for produce event. */
    dmaCfg.notification = 0;
    dmaCfg.cb = NULL;
    dmaCfg.prodHeader = 0;
    dmaCfg.prodFooter = 0;
    dmaCfg.consHeader = 0;
    dmaCfg.prodAvailCount = 0;

    apiRetStatus = CyU3PDmaChannelCreate (&glChHandleUtoCPU,
    		CY_U3P_DMA_TYPE_MANUAL_IN, &dmaCfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PDmaChannelCreate (glChHandleUtoCPU) failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Flush the Endpoint memory */
    CyU3PUsbFlushEp(P_DCONFIG_EP2OUT);

    /* Set DMA channel transfer size. */
    apiRetStatus = CyU3PDmaChannelSetXfer (&glChHandleUtoCPU, CY_FX_SLFIFO_DMA_TX_SIZE);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PDmaChannelSetXfer failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }


    /* Update the status flag. */
    glIsApplnActive = CyTrue;

}


void
CyFxConfigFpgaApplnStop(
		void)
{

	CyU3PDebugPrint (4, "CyFxConfigFpgaApplnStop...\n\r");
	//CyU3PEpConfig_t epCfg;
	CyU3PReturnStatus_t apiRetStatus = CY_U3P_SUCCESS;

	CyU3PGpioDeInit();
	apiRetStatus = CyU3PSpiDeInit();
	if (apiRetStatus != CY_U3P_SUCCESS)
	{
		CyU3PDebugPrint (4, "CyU3PSetEpConfig failed, Error code = %d\n", apiRetStatus);
		CyFxAppErrorHandler (apiRetStatus);
	}

    /* Update the flag. */
    glIsApplnActive = CyFalse;

    CyU3PUsbGetEpSeqNum(P_DCONFIG_EP2OUT, &seqnum_p);

    /* Flush the endpoint memory */
    CyU3PUsbFlushEp(P_DCONFIG_EP2OUT);

    /* Destroy the channel */
    apiRetStatus = CyU3PDmaChannelDestroy (&glChHandleUtoCPU);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
		CyU3PDebugPrint (4, "CyU3PDmaChannelDestroy failed, Error code = %d\n", apiRetStatus);
		CyFxAppErrorHandler (apiRetStatus);
	}

#if 0
    /* Disable endpoints. */
	CyU3PMemSet ((uint8_t *)&epCfg, 0, sizeof (epCfg));
	epCfg.enable = CyFalse;

        /* Producer endpoint configuration. */
	apiRetStatus = CyU3PSetEpConfig(P_DCONFIG_EP2OUT, &epCfg);
	if (apiRetStatus != CY_U3P_SUCCESS)
	{
		CyU3PDebugPrint (4, "CyU3PSetEpConfig failed, Error code = %d\n", apiRetStatus);
		CyFxAppErrorHandler (apiRetStatus);
	}
#endif

}


void
CyFxConfigFpgaApplnInit (void)
{

    CyU3PGpioClock_t gpioClock;
    CyU3PGpioSimpleConfig_t gpioConfig;
    CyU3PSpiConfig_t spiConfig;
    CyU3PReturnStatus_t apiRetStatus = CY_U3P_SUCCESS;

    uint32_t    i;
    static uint8_t CyFxUSBSerialDesc[] __attribute__ ((aligned (32))) =
    {
        0x22,                           /* Descriptor size */
        CY_U3P_USB_STRING_DESCR,        /* Device descriptor type */
        '0',0x00,'0',0x00,'0',0x00,'0',0x00,
        '0',0x00,'0',0x00,'0',0x00,'0',0x00,
        '0',0x00,'0',0x00,'0',0x00,'0',0x00,
        '0',0x00,'0',0x00,'0',0x00,'0',0x00,
    };

    apiRetStatus = CyU3PEventCreate(&glFxConfigFpgaAppEvent);
    if (apiRetStatus != CY_U3P_SUCCESS)
		{
			CyU3PDebugPrint (4, "event create failed, Error Code = %d\r\n",apiRetStatus);
		}

        /* Start the SPI module and configure the master. */
    apiRetStatus = CyU3PSpiInit();
        if (apiRetStatus != CY_U3P_SUCCESS)
        {
        	CyU3PDebugPrint (4, "SPI init failed, Error Code = %d\r\n",apiRetStatus);
        }

        /* Start the SPI master block. Run the SPI clock at 25MHz
         * and configure the word length to 8 bits. Also configure
         * the slave select using FW. */
        CyU3PMemSet ((uint8_t *)&spiConfig, 0, sizeof(spiConfig));
        spiConfig.isLsbFirst = CyFalse;
        spiConfig.cpol       = CyTrue;
        spiConfig.ssnPol     = CyFalse;
        spiConfig.cpha       = CyTrue;
        spiConfig.leadTime   = CY_U3P_SPI_SSN_LAG_LEAD_HALF_CLK;
        spiConfig.lagTime    = CY_U3P_SPI_SSN_LAG_LEAD_HALF_CLK;
        spiConfig.ssnCtrl    = CY_U3P_SPI_SSN_CTRL_FW;
        spiConfig.clock      = 25000000;
        spiConfig.wordLen    = 8;

        apiRetStatus = CyU3PSpiSetConfig (&spiConfig, NULL);
        if (apiRetStatus != CY_U3P_SUCCESS)
        {
        	CyU3PDebugPrint (4, "SPI config failed, Error Code = %d\r\n",apiRetStatus);
        }

    /******************/
    /* Configure GPIO */
    /******************/

    /* Init the GPIO module */
        gpioClock.fastClkDiv = 2;
        gpioClock.slowClkDiv = 0;
        gpioClock.simpleDiv = CY_U3P_GPIO_SIMPLE_DIV_BY_2;
        gpioClock.clkSrc = CY_U3P_SYS_CLK;
        gpioClock.halfDiv = 0;

        /* Initialize Gpio interface */
        apiRetStatus = CyU3PGpioInit(&gpioClock, NULL);
        if (apiRetStatus != 0)
        {
            /* Error Handling */
            CyU3PDebugPrint (4, "GPIO Init failed, Error Code = %d\r\n",apiRetStatus);
            CyFxAppErrorHandler(apiRetStatus);
        }

        /* Configure ADC_CLK_EN (GPIO 51) as output */
        gpioConfig.outValue = CyFalse;    //< Initial value of the GPIO if configured as output:
		gpioConfig.inputEn = CyFalse;    //< Enable the input stage
		gpioConfig.driveLowEn = CyTrue;  //< Enable output driver for outValue = CyTrue
		gpioConfig.driveHighEn = CyTrue; //< Enable output driver for outValue = CyFalse
		gpioConfig.intrMode = CY_U3P_GPIO_NO_INTR;
        apiRetStatus = CyU3PGpioSetSimpleConfig(ADC_CLK_EN, &gpioConfig);
        if (apiRetStatus != CY_U3P_SUCCESS)
        {
            /* Error handling */
            CyU3PDebugPrint (4, "CyU3PGpioSetSimpleConfig failed, error code = %d\n",
                    apiRetStatus);
            CyFxAppErrorHandler(apiRetStatus);
        }

        //TODO: Configure GPIO pin ADC_RESETN
        gpioConfig.outValue = CyTrue; // default ADC state is not in reset
        gpioConfig.driveLowEn = CyTrue;
        gpioConfig.driveHighEn = CyTrue;
        gpioConfig.inputEn = CyFalse;
        gpioConfig.intrMode = CY_U3P_GPIO_NO_INTR;
        /* Enable ADC_RESETN as an output pin to control ADC reset pin */
        apiRetStatus = CyU3PDeviceGpioOverride (ADC_RESETN, CyTrue);
        if (apiRetStatus != 0)
        	CyU3PDebugPrint(4, "CyU3PDeviceGpioOverride ADC_RESETN failed, error code = %d\n",apiRetStatus);
        apiRetStatus = CyU3PGpioSetSimpleConfig(ADC_RESETN, &gpioConfig);
        if (apiRetStatus != CY_U3P_SUCCESS)
        	CyU3PDebugPrint(4, "CyU3PGpioSetSimpleConfig ADC_RESETN failed, error code = %d\n",apiRetStatus);

        CyU3PGpioSetValue(ADC_RESETN, CyTrue);

        /* Configure GPIOs for FPGA config */

        //toggle PROG_B to reset FPGA
        apiRetStatus = CyU3PSpiSetSsnLine(CyFalse);
        CyU3PThreadSleep(10);
        apiRetStatus = CyU3PSpiSetSsnLine(CyTrue);

          /* Configure GPIO 52 as input */
          gpioConfig.outValue = CyTrue;     //< Initial value of the GPIO if configured as output:
		  gpioConfig.inputEn = CyTrue;      //< Enable the input stage
		  gpioConfig.driveLowEn = CyFalse;  //< Enable output driver for outValue = CyTrue
		  gpioConfig.driveHighEn = CyFalse; //< Enable output driver for outValue = CyFalse
		  gpioConfig.intrMode = CY_U3P_GPIO_INTR_BOTH_EDGE;
          apiRetStatus = CyU3PGpioSetSimpleConfig(FPGA_INIT_B, &gpioConfig);
          if (apiRetStatus != CY_U3P_SUCCESS)
          {
              /* Error handling */
              CyU3PDebugPrint (4, "CyU3PGpioSetSimpleConfig failed, error code = %d\n",
                      apiRetStatus);
              CyFxAppErrorHandler(apiRetStatus);
          }

          /* Configure GPIO 50 as input with interrupt enabled for both edges */
            apiRetStatus = CyU3PGpioSetSimpleConfig(FPGA_DONE, &gpioConfig);
            if (apiRetStatus != CY_U3P_SUCCESS)
            {
                /* Error handling */
                CyU3PDebugPrint (4, "CyU3PGpioSetSimpleConfig failed, error code = %d\n",
                        apiRetStatus);
                CyFxAppErrorHandler(apiRetStatus);
            }


          /*********************/
          /* Configure GPIO end*/
          /*********************/

    /* Start the USB functionality. */
    apiRetStatus = CyU3PUsbStart();
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PUsbStart failed to Start, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* The fast enumeration is the easiest way to setup a USB connection,
     * where all enumeration phase is handled by the library. Only the
     * class / vendor requests need to be handled by the application. */
    CyU3PUsbRegisterSetupCallback(CyFxSlFifoApplnUSBSetupCB, CyTrue);

    /* Setup the callback to handle the USB events. */
    CyU3PUsbRegisterEventCallback(CyFxSlFifoApplnUSBEventCB);

    /* Register a callback to handle LPM requests from the USB 3.0 host. */
    CyU3PUsbRegisterLPMRequestCallback(CyFxApplnLPMRqtCB);

    /* Set the USB Enumeration descriptors */

    /* Super speed device descriptor. */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_SS_DEVICE_DESCR, 0, (uint8_t *)CyFxUSB30DeviceDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB set device descriptor failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* High speed device descriptor. */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_HS_DEVICE_DESCR, 0, (uint8_t *)CyFxUSB20DeviceDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB set device descriptor failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* BOS descriptor */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_SS_BOS_DESCR, 0, (uint8_t *)CyFxUSBBOSDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB set configuration descriptor failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Device qualifier descriptor */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_DEVQUAL_DESCR, 0, (uint8_t *)CyFxUSBDeviceQualDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB set device qualifier descriptor failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Super speed configuration descriptor */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_SS_CONFIG_DESCR, 0, (uint8_t *)CyFxUSBSSConfigDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB set configuration descriptor failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* High speed configuration descriptor */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_HS_CONFIG_DESCR, 0, (uint8_t *)CyFxUSBHSConfigDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB Set Other Speed Descriptor failed, Error Code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Full speed configuration descriptor */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_FS_CONFIG_DESCR, 0, (uint8_t *)CyFxUSBFSConfigDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB Set Configuration Descriptor failed, Error Code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* String descriptor 0 */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_STRING_DESCR, 0, (uint8_t *)CyFxUSBStringLangIDDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB set string descriptor failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* String descriptor 1 */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_STRING_DESCR, 1, (uint8_t *)CyFxUSBManufactureDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB set string descriptor 1 failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* String descriptor 2 */
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_STRING_DESCR, 2, (uint8_t *)CyFxUSBProductDscr);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB set string descriptor 2 failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* String descriptor 3 */
    // TODO: EFUSE_DIE_ID
    CyU3PReadDeviceRegisters(EFUSE_DIE_ID, 2, die_id);
    for (i = 0; i < 2; i++) {
        CyFxUSBSerialDesc[i*16+ 2] = hexchar[(die_id[i] >> 28) & 0xF];
        CyFxUSBSerialDesc[i*16+ 4] = hexchar[(die_id[i] >> 24) & 0xF];
        CyFxUSBSerialDesc[i*16+ 6] = hexchar[(die_id[i] >> 20) & 0xF];
        CyFxUSBSerialDesc[i*16+ 8] = hexchar[(die_id[i] >> 16) & 0xF];
        CyFxUSBSerialDesc[i*16+10] = hexchar[(die_id[i] >> 12) & 0xF];
        CyFxUSBSerialDesc[i*16+12] = hexchar[(die_id[i] >>  8) & 0xF];
        CyFxUSBSerialDesc[i*16+14] = hexchar[(die_id[i] >>  4) & 0xF];
        CyFxUSBSerialDesc[i*16+16] = hexchar[(die_id[i] >>  0) & 0xF];
    }
    //apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_STRING_DESCR, 3, (uint8_t *)CyFxUSBSerialNumDesc);
    apiRetStatus = CyU3PUsbSetDesc(CY_U3P_USB_SET_STRING_DESCR, 3, (uint8_t *)CyFxUSBSerialDesc);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB set string descriptor 3 failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Register a buffer into which the USB driver can log relevant events. */
    gl_UsbLogBuffer = (uint8_t *)CyU3PDmaBufferAlloc (CYFX_USBLOG_SIZE);
    if (gl_UsbLogBuffer)
    	CyU3PUsbInitEventLog (gl_UsbLogBuffer, CYFX_USBLOG_SIZE);

    //Connect the USB Pins with super speed operation enabled.
    //apiRetStatus = CyU3PUsbControlUsb2Support (CyFalse); //disables USB 2.0
    apiRetStatus = CyU3PConnectState(CyTrue, CyTrue);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "USB Connect failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

}



/*
 * Main function
 */
int
main (void)
{
    CyU3PIoMatrixConfig_t io_cfg;
    CyU3PReturnStatus_t status = CY_U3P_SUCCESS;
    CyU3PSysClockConfig_t clkCfg;

        /* setSysClk400 clock configurations */
        clkCfg.setSysClk400 = CyTrue;   /* FX3 device's master clock is set to a frequency > 400 MHz */
        clkCfg.cpuClkDiv = 2;           /* CPU clock divider */
        clkCfg.dmaClkDiv = 2;           /* DMA clock divider */
        clkCfg.mmioClkDiv = 2;          /* MMIO clock divider */
        clkCfg.useStandbyClk = CyFalse; /* device has no 32KHz clock supplied */
        clkCfg.clkSrc = CY_U3P_SYS_CLK; /* Clock source for a peripheral block  */

    /* Initialize the device */
    status = CyU3PDeviceInit (&clkCfg);
    if (status != CY_U3P_SUCCESS)
    {
        goto handle_fatal_error;
    }

    /* Initialize the caches. Enable instruction cache and keep data cache disabled.
     * The data cache is useful only when there is a large amount of CPU based memory
     * accesses. When used in simple cases, it can decrease performance due to large
     * number of cache flushes and cleans and also it adds to the complexity of the
     * code. */
    status = CyU3PDeviceCacheControl (CyTrue, CyFalse, CyFalse);
    if (status != CY_U3P_SUCCESS)
    {
        goto handle_fatal_error;
    }

    /* Configure the IO matrix for the device. On the FX3 DVK board, the COM port
     * is connected to the IO(53:56). This means that either DQ32 mode should be
     * selected or lppMode should be set to UART_ONLY. Here we are choosing
     * UART_ONLY configuration for 16 bit slave FIFO configuration and setting
     * isDQ32Bit for 32-bit slave FIFO configuration. */
    //TODO: Configure IO matrix at boot
    io_cfg.useUart   = CyTrue;
    io_cfg.useI2C    = CyTrue;
    io_cfg.useI2S    = CyFalse;
    io_cfg.useSpi    = CyTrue;
    //io_cfg.useSpi    = CyFalse;  						  // <= enable this for debugging
    io_cfg.isDQ32Bit = CyFalse;
    io_cfg.lppMode   = CY_U3P_IO_MATRIX_LPP_DEFAULT;
    //io_cfg.lppMode   = CY_U3P_IO_MATRIX_LPP_UART_ONLY;  // <= enable this for debugging
    /* GPIOs: 50(DONE), 51(CLK_EN) and 52(INIT_B) are enabled. */
    io_cfg.gpioSimpleEn[0]  = 0x00000000;   // first set of GPIOs [ 31,30,......,2,1,0 ]
    io_cfg.gpioSimpleEn[1]  = 0x001C0000;   //second set of GPIOs [ 63,62,...,34,33,32 ]
    io_cfg.gpioComplexEn[0] = 0;
    io_cfg.gpioComplexEn[1] = 0;
    status = CyU3PDeviceConfigureIOMatrix (&io_cfg);
    if (status != CY_U3P_SUCCESS)
    {
        goto handle_fatal_error;
    }

    // set lower current drive for GPIF bus
    status = CyU3PSetPportDriveStrength(CY_U3P_DS_QUARTER_STRENGTH);
    if (status != CY_U3P_SUCCESS)
    {
        goto handle_fatal_error;
    }
    // set lower current drive for GPIO, I2S & SPI
    CyU3PSetGpioDriveStrength(CY_U3P_DS_QUARTER_STRENGTH);
    CyU3PSetSerialIoDriveStrength(CY_U3P_DS_QUARTER_STRENGTH);
    // set lower current drive for I2C
    CyU3PSetI2cDriveStrength(CY_U3P_DS_FULL_STRENGTH);


    /* This is a non returnable call for initializing the RTOS kernel */
    CyU3PKernelEntry ();

    /* Dummy return to make the compiler happy */
    return 0;

handle_fatal_error:

    /* Cannot recover from this error. */
    while (1);
}

