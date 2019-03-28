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
#include "cyu3i2c.h"
#include "cyu3gpio.h"
#include "cyu3spi.h"
#include "cyu3uart.h"
#include "cyfxslfifosync.h"
#include "cyu3gpif.h"
#include "cyu3pib.h"
#include "pib_regs.h"
#include "cyfxconfigfpga.h"
#include "cyfxusbi2cregmode.h"
#include "cyfxgpif2config.h"

/* USB and GPIF initialization  */
/* Vendor requests handling     */

CyU3PThread slFifoAppThread;	        /* Slave FIFO application thread structure */
CyU3PDmaChannel glChHandleSlFifoUtoP_EP2OUT;  /* DMA Channel handle for U2P transfer. */
CyU3PDmaChannel glChHandleSlFifoUtoP_EP4OUT;  /* DMA Channel handle for U2P transfer. */
CyU3PDmaChannel glChHandleSlFifoPtoU_EP6IN;   /* DMA Channel handle for P2U transfer. */


uint32_t glDMARxCount = 0;               /* Counter to track the number of buffers received from USB. */
uint32_t glDMATxCount = 0;               /* Counter to track the number of buffers sent to USB. */
volatile CyBool_t glIsApplnActive = CyFalse;    /* Whether the loopback application is active or not. */
//uint8_t glEp0Buffer[32];                		/* Buffer used for sending EP0 data.    */
uint8_t glEp0Buffer[4096] __attribute__ ((aligned (32)));
/* Firmware ID variable that may be used to verify I2C firmware. */
const uint8_t glFirmwareID[32]  __attribute__ ((aligned (32))) =
	{ 'S','c','o','p','e','F','u','n',' ','v','1','.','0','0','\0'};

static uint8_t CacheAlignedBuffer[32] __attribute__ ((aligned (32))) ;
uint8_t *Ep0Buffer=(uint8_t *)CacheAlignedBuffer;

uint8_t a;

uint8_t *seqnum_p;

//define variables for storing GPIF R/W error counters
static volatile uint16_t glThr0_WR_OVERRUN_Cnt = 0;
static volatile uint16_t glThr2_WR_OVERRUN_Cnt = 0;
static volatile uint16_t glThr3_WR_OVERRUN_Cnt = 0;
static volatile uint16_t glThr0_RD_UNDERRUN_Cnt = 0;
static volatile uint16_t glThr2_RD_UNDERRUN_Cnt = 0;
static volatile uint16_t glThr3_RD_UNDERRUN_Cnt = 0;

#ifdef EXPLORE_GPIF_NOISE
static volatile int glErrorResetFlag=0;
static volatile uint64_t glPhyErrorCount = 0;
static volatile uint64_t glLnkErrorCount = 0;
static volatile uint32_t glUSBDisconnectCount = 0;
#endif

/* Application Error Handler */
void
CyFxAppErrorHandler (
        CyU3PReturnStatus_t apiRetStatus    /* API return status */
        )
{
    /* Application failed with the error code apiRetStatus */

    /* Add custom debug or recovery actions here */

    /* Loop Indefinitely */
    for (;;)
    {
        /* Thread sleep : 100 ms */
        //CyU3PThreadSleep (100);
    	/* flash debug LED */
	    for (;;)
	    {
	        /* Thread sleep : 100 ms */
	    	{
	    		CyU3PSpiSetSsnLine (CyFalse);
	    		CyU3PThreadSleep(500);
	    		CyU3PSpiSetSsnLine (CyTrue);
	    		CyU3PThreadSleep(500);
	    	}
	    }
    }
}

/* This function initializes the debug module. The debug prints
 * are routed to the UART and can be seen using a UART console
 * running at 115200 baud rate. */
void
CyFxSlFifoApplnDebugInit (void)
{
    CyU3PUartConfig_t uartConfig;
    CyU3PReturnStatus_t apiRetStatus = CY_U3P_SUCCESS;
    /* Initialize the UART for printing debug messages */
    apiRetStatus = CyU3PUartInit();
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        /* Error handling */
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Set UART configuration */
    CyU3PMemSet ((uint8_t *)&uartConfig, 0, sizeof (uartConfig));
    uartConfig.baudRate = CY_U3P_UART_BAUDRATE_115200;
    uartConfig.stopBit = CY_U3P_UART_ONE_STOP_BIT;
    uartConfig.parity = CY_U3P_UART_NO_PARITY;
    uartConfig.txEnable = CyTrue;
    uartConfig.rxEnable = CyFalse;
    uartConfig.flowCtrl = CyFalse;
    uartConfig.isDma = CyTrue;

    apiRetStatus = CyU3PUartSetConfig (&uartConfig, NULL);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Set the UART transfer to a really large value. */
    apiRetStatus = CyU3PUartTxSetBlockXfer (0xFFFFFFFF);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Initialize the debug module. */
    apiRetStatus = CyU3PDebugInit (CY_U3P_LPP_SOCKET_UART_CONS, 8);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyFxAppErrorHandler(apiRetStatus);
    }
}

/* Callback function to check for PIB ERROR*/
void gpif_error_cb(CyU3PPibIntrType cbType, uint16_t cbArg)
{
	if(cbType==CYU3P_PIB_INTR_ERROR)
	{
		switch(CYU3P_GET_PIB_ERROR_TYPE(cbArg))
		{
          case CYU3P_PIB_ERR_THR0_WR_OVERRUN:
        	  CyU3PDebugPrint (4, "CYU3P_PIB_ERR_THR0_WR_OVERRUN");
        	  glThr0_WR_OVERRUN_Cnt++;
          break;

          case CYU3P_PIB_ERR_THR2_WR_OVERRUN:
        	  CyU3PDebugPrint (4, "CYU3P_PIB_ERR_THR2_WR_OVERRUN");
        	  glThr2_WR_OVERRUN_Cnt++;
          break;

          case CYU3P_PIB_ERR_THR3_WR_OVERRUN:
        	  CyU3PDebugPrint (4, "CYU3P_PIB_ERR_THR3_WR_OVERRUN");
        	  glThr3_WR_OVERRUN_Cnt++;
          break;

          case CYU3P_PIB_ERR_THR0_RD_UNDERRUN:
        	  CyU3PDebugPrint (4, "CYU3P_PIB_ERR_THR0_RD_UNDERRUN");
        	  glThr0_RD_UNDERRUN_Cnt++;
          break;

          case CYU3P_PIB_ERR_THR2_RD_UNDERRUN:
        	  CyU3PDebugPrint (4, "CYU3P_PIB_ERR_THR2_RD_UNDERRUN");
        	  glThr2_RD_UNDERRUN_Cnt++;
          break;

          case CYU3P_PIB_ERR_THR3_RD_UNDERRUN:
        	  CyU3PDebugPrint (4, "CYU3P_PIB_ERR_THR3_RD_UNDERRUN");
        	  glThr3_RD_UNDERRUN_Cnt++;
          break;

          default:
        	  CyU3PDebugPrint (4, "No Underrun/Overrun Error");
          break;
		}
	}
}


/* DMA callback function to handle the produce events for U to P transfers. */
void
CyFxSlFifoUtoPDmaCallback (
        CyU3PDmaChannel   *chHandle,
        CyU3PDmaCbType_t  type,
        CyU3PDmaCBInput_t *input
        )
{
    CyU3PReturnStatus_t status = CY_U3P_SUCCESS;

    if (type == CY_U3P_DMA_CB_PROD_EVENT)
    {
        /* This is a produce event notification to the CPU. This notification is 
         * received upon reception of every buffer. The buffer will not be sent
         * out unless it is explicitly committed. The call shall fail if there
         * is a bus reset / usb disconnect or if there is any application error. */
        status = CyU3PDmaChannelCommitBuffer (chHandle, input->buffer_p.count, 0);
        if (status != CY_U3P_SUCCESS)
        {
            CyU3PDebugPrint (4, "CyU3PDmaChannelCommitBuffer failed, Error code = %d\n", status);
        }

        /* Increment the counter. */
        glDMARxCount++;
    }
}

/* DMA callback function to handle the produce events for P to U transfers. */
void
CyFxSlFifoPtoUDmaCallback (
        CyU3PDmaChannel   *chHandle,
        CyU3PDmaCbType_t  type,
        CyU3PDmaCBInput_t *input
        )
{
    CyU3PReturnStatus_t status = CY_U3P_SUCCESS;

    if (type == CY_U3P_DMA_CB_PROD_EVENT)
    {
        /* This is a produce event notification to the CPU. This notification is 
         * received upon reception of every buffer. The buffer will not be sent
         * out unless it is explicitly committed. The call shall fail if there
         * is a bus reset / usb disconnect or if there is any application error. */
        status = CyU3PDmaChannelCommitBuffer (chHandle, input->buffer_p.count, 0);
        if (status != CY_U3P_SUCCESS)
        {
            CyU3PDebugPrint (4, "CyU3PDmaChannelCommitBuffer failed, Error code = %d\n", status);
        }

        /* Increment the counter. */
        glDMATxCount++;
    }
}


/* This function starts the slave FIFO loop application. This is called
 * when a SET_CONF event is received from the USB host. The endpoints
 * are configured and the DMA pipe is setup in this function. */
void
CyFxSlFifoApplnStart (void)
{
	uint16_t size = 0;
    CyU3PEpConfig_t epCfg;
    CyU3PDmaChannelConfig_t dmaCfg;
    CyU3PReturnStatus_t apiRetStatus = CY_U3P_SUCCESS;
    CyU3PUSBSpeed_t usbSpeed = CyU3PUsbGetSpeed();

    /* First identify the usb speed. Once that is identified,
     * create a DMA channel and start the transfer on this. */

    /* Based on the Bus Speed configure the endpoint packet size */
    switch (usbSpeed)
    {
        case CY_U3P_FULL_SPEED:
            //size = 64;
            size = 1024;
            break;

        case CY_U3P_HIGH_SPEED:
            //size = 512;
            size = 1024;
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
    epCfg.burstLen = BURST_LEN;
    epCfg.streams = 0;
    epCfg.pcktSize = size;

    /*
	EP2 is re-configured to enable burst transfers to support high-bandwidth data
	transfers after the Slave FIFO interface is  enabled.  So  the  CyU3PSetEpConfig
	API  is  called  twice  for configuring the  same  endpoint.  This  API clears
	the sequence  number  associated  with  the endpoint. Data  transfers  fail  when
	the USB  3.0 Host  and  FX3  device  find a mismatch in the sequence number.
	Therefore, you need  to  restore  the  sequence  number so  that  the  USB  3.0
	Host can perform successful data transfers even after reconfiguring the EP1.
	This is valid only for USB 3.0 data transfers.
     */

    /* Producer EP2OUT endpoint re-configuration */
    apiRetStatus = CyU3PSetEpConfig(P_DCONFIG_EP2OUT, &epCfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PSetEpConfig failed (P_DCONFIG_EP2OUT), Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler (apiRetStatus);
    }

    CyU3PUsbSetEpSeqNum (P_DCONFIG_EP2OUT, seqnum_p);

    /* Producer EP4OUT endpoint configuration */
    apiRetStatus = CyU3PSetEpConfig(P_DGENERATOR_EP4OUT, &epCfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PSetEpConfig failed (P_DGENERATOR_EP4OUT), Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler (apiRetStatus);
    }

    /* Consumer EP6IN endpoint configuration */
    apiRetStatus = CyU3PSetEpConfig(C_DFRAME_EP6IN, &epCfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PSetEpConfig failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler (apiRetStatus);
    }



#ifdef MANUAL
    /* Create a DMA MANUAL channel for U2P transfer.
     * DMA size is set based on the USB speed. */
    dmaCfg.size  = size;
    dmaCfg.count = CY_FX_SLFIFO_DMA_BUF_COUNT;
    dmaCfg.prodSckId = CY_FX_P1_USB_SOCKET;
    dmaCfg.consSckId = CY_FX_C1_PPORT_SOCKET;
    dmaCfg.dmaMode = CY_U3P_DMA_MODE_BYTE;
    /* Enabling the callback for produce event. */
    dmaCfg.notification = CY_U3P_DMA_CB_PROD_EVENT;
    dmaCfg.cb = CyFxSlFifoUtoPDmaCallback;
    dmaCfg.prodHeader = 0;
    dmaCfg.prodFooter = 0;
    dmaCfg.consHeader = 0;
    dmaCfg.prodAvailCount = 0;

    apiRetStatus = CyU3PDmaChannelCreate (&glChHandleSlFifoUtoP,
            CY_U3P_DMA_TYPE_MANUAL, &dmaCfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PDmaChannelCreate failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Create a DMA MANUAL channel for P2U transfer. */
    dmaCfg.prodSckId = CY_FX_P1_PPORT_SOCKET;
    dmaCfg.consSckId = CY_FX_C1_USB_SOCKET;
    dmaCfg.cb = CyFxSlFifoPtoUDmaCallback;
    apiRetStatus = CyU3PDmaChannelCreate (&glChHandleSlFifoPtoU,
            CY_U3P_DMA_TYPE_MANUAL, &dmaCfg);

#else


        /* Create a DMA AUTO channel for P_DCONFIG_EP2OUT U2P transfer.
           DMA size is set based on the USB speed. */

       dmaCfg.size  = DMA_BUF_SIZE* size;
	   dmaCfg.count = CY_FX_SLFIFO_DMA_BUF_COUNT_U_2_P;
	   dmaCfg.prodSckId = CY_FX_P1_USB_SOCKET;
       dmaCfg.consSckId = CY_FX_C1_PPORT_SOCKET;
       dmaCfg.dmaMode = CY_U3P_DMA_MODE_BYTE;
       /* Enabling the callback for produce event. */
       dmaCfg.notification = 0;
       dmaCfg.cb = NULL;
       dmaCfg.prodHeader = 0;
       dmaCfg.prodFooter = 0;
       dmaCfg.consHeader = 0;
       dmaCfg.prodAvailCount = 0;

       apiRetStatus = CyU3PDmaChannelCreate (&glChHandleSlFifoUtoP_EP2OUT,
               CY_U3P_DMA_TYPE_AUTO, &dmaCfg);
       if (apiRetStatus != CY_U3P_SUCCESS)
       {
           CyU3PDebugPrint (4, "CyU3PDmaChannelCreate P_DCONFIG_EP2OUT failed, Error code = %d\n", apiRetStatus);
           CyFxAppErrorHandler(apiRetStatus);
       }

       /* Create a DMA AUTO channel for P_DGENERATOR_EP4OUT U2P transfer.*/
 	  dmaCfg.prodSckId = CY_FX_P2_USB_SOCKET;
      dmaCfg.consSckId = CY_FX_C2_PPORT_SOCKET;
      apiRetStatus = CyU3PDmaChannelCreate (&glChHandleSlFifoUtoP_EP4OUT,
              CY_U3P_DMA_TYPE_AUTO, &dmaCfg);
      if (apiRetStatus != CY_U3P_SUCCESS)
      {
          CyU3PDebugPrint (4, "CyU3PDmaChannelCreate P_DGENERATOR_EP4OUT failed, Error code = %d\n", apiRetStatus);
          CyFxAppErrorHandler(apiRetStatus);
      }

       /* TODO: Create a DMA AUTO channel for C_DFRAME_EP6IN P2U transfer.  *
	    * External master should count the data being written or read *
	    * and ensure that it does not exceed the buffer size          *
        * It is generally good practice to declare buffer sizes       *
        * which are a multiple of endpoint packet size.               */
       // increase buffer SIZE for higher performance
       dmaCfg.size  = DMA_BUF_SIZE*size;
       /* Number of buffers in the DMA channel does not really have a relation to endpoint config.
        * But it is good practice to have as many buffers as the burst size configured in endpoint config.*/
       // increase buffer count for higher performance
       dmaCfg.count = CY_FX_SLFIFO_DMA_BUF_COUNT_P_2_U;
       dmaCfg.prodSckId = CY_FX_P1_PPORT_SOCKET;
       dmaCfg.consSckId = CY_FX_C1_USB_SOCKET;
	   // If there is at least one buffer available to be filled with data, the DMA ready flag is deasserted
       dmaCfg.cb = NULL;
       apiRetStatus = CyU3PDmaChannelCreate (&glChHandleSlFifoPtoU_EP6IN,
               CY_U3P_DMA_TYPE_AUTO, &dmaCfg);


#endif


    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PDmaChannelCreate C_DFRAME_EP6IN failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }


    /* Flush the Endpoint memory */
    CyU3PUsbFlushEp(P_DCONFIG_EP2OUT);
    CyU3PUsbFlushEp(P_DGENERATOR_EP4OUT);
    CyU3PUsbFlushEp(C_DFRAME_EP6IN);

    /* Set DMA channel transfer size. */
    apiRetStatus = CyU3PDmaChannelSetXfer (&glChHandleSlFifoUtoP_EP2OUT, CY_FX_SLFIFO_DMA_TX_SIZE);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PDmaChannelSetXfer Failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }
    apiRetStatus = CyU3PDmaChannelSetXfer (&glChHandleSlFifoUtoP_EP4OUT, CY_FX_SLFIFO_DMA_TX_SIZE);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PDmaChannelSetXfer Failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }
    apiRetStatus = CyU3PDmaChannelSetXfer (&glChHandleSlFifoPtoU_EP6IN, CY_FX_SLFIFO_DMA_RX_SIZE);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PDmaChannelSetXfer Failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Update the status flag. */
    glIsApplnActive = CyTrue;
}

/* This function stops the slave FIFO loop application. This shall be called
 * whenever a RESET or DISCONNECT event is received from the USB host. The
 * endpoints are disabled and the DMA pipe is destroyed by this function. */
void
CyFxSlFifoApplnStop (
        void)
{
    CyU3PEpConfig_t epCfg;
    CyU3PReturnStatus_t apiRetStatus = CY_U3P_SUCCESS;

    /* Update the flag. */
    glIsApplnActive = CyFalse;

    /* Flush the endpoint memory */
    CyU3PUsbFlushEp(P_DCONFIG_EP2OUT);
    CyU3PUsbFlushEp(P_DGENERATOR_EP4OUT);
    CyU3PUsbFlushEp(C_DFRAME_EP6IN);

    /* Destroy the channel */
    CyU3PDmaChannelDestroy (&glChHandleSlFifoUtoP_EP4OUT);
    CyU3PDmaChannelDestroy (&glChHandleSlFifoUtoP_EP2OUT);
    CyU3PDmaChannelDestroy (&glChHandleSlFifoPtoU_EP6IN);

    /* Disable endpoints. */
    CyU3PMemSet ((uint8_t *)&epCfg, 0, sizeof (epCfg));
    epCfg.enable = CyFalse;

    /* Producer P_DCONFIG_EP2OUT configuration. */
    apiRetStatus = CyU3PSetEpConfig(P_DCONFIG_EP2OUT, &epCfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PSetEpConfig P_DCONFIG_EP2OUT failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler (apiRetStatus);
    }

    /* Producer P_DGENERATOR_EP4OUT configuration. */
    apiRetStatus = CyU3PSetEpConfig(P_DGENERATOR_EP4OUT, &epCfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PSetEpConfig P_DGENERATOR_EP4OUT failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler (apiRetStatus);
    }

    /* Consumer endpoint configuration. */
    apiRetStatus = CyU3PSetEpConfig(C_DFRAME_EP6IN, &epCfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PSetEpConfig failed, Error code = %d\n", apiRetStatus);
        CyFxAppErrorHandler (apiRetStatus);
    }
}

/* Callback to handle the USB setup requests. */
CyBool_t
CyFxSlFifoApplnUSBSetupCB (
        uint32_t setupdat0,
        uint32_t setupdat1
    )
{
    /* Fast enumeration is used. Only requests addressed to the interface, class,
     * vendor and unknown control requests are received by this function.
     * This application does not support any class or vendor requests. */

    uint8_t  bRequest, bReqType;
    uint8_t  bType, bTarget;
    uint16_t wValue, wIndex, wLength;
    CyBool_t isHandled = CyFalse;
    CyU3PReturnStatus_t status = CY_U3P_SUCCESS;
    uint8_t  i2cAddr;

    /* Decode the fields from the setup request. */
    bReqType = (setupdat0 & CY_U3P_USB_REQUEST_TYPE_MASK);
    bType    = (bReqType & CY_U3P_USB_TYPE_MASK);
    bTarget  = (bReqType & CY_U3P_USB_TARGET_MASK);
    bRequest = ((setupdat0 & CY_U3P_USB_REQUEST_MASK) >> CY_U3P_USB_REQUEST_POS);
    wValue   = ((setupdat0 & CY_U3P_USB_VALUE_MASK)   >> CY_U3P_USB_VALUE_POS);
    wIndex   = ((setupdat1 & CY_U3P_USB_INDEX_MASK)   >> CY_U3P_USB_INDEX_POS);
    wLength  = ((setupdat1 & CY_U3P_USB_LENGTH_MASK)  >> CY_U3P_USB_LENGTH_POS);

    CyU3PDebugPrint (2, "\b\bINFO: Received req. from host ...\r\n", bReqType);
    CyU3PDebugPrint (2, "\b\bbReqType : 0x%x\r\n", bReqType);
	CyU3PDebugPrint (2, "\b\bbType    : 0x%x\r\n", bType);
	CyU3PDebugPrint (2, "\b\bbTarget  : 0x%x\r\n", bTarget);
	CyU3PDebugPrint (2, "\b\bbRequest : 0x%x\r\n", bRequest);
	CyU3PDebugPrint (2, "\b\bwValue   : 0x%x\r\n", wValue);
	CyU3PDebugPrint (2, "\b\bwIndex   : 0x%x\r\n", wIndex);
	CyU3PDebugPrint (2, "\b\bwLength  : 0x%x\r\n", wLength);

    if (bType == CY_U3P_USB_STANDARD_RQT)
    {
        /* Handle SET_FEATURE(FUNCTION_SUSPEND) and CLEAR_FEATURE(FUNCTION_SUSPEND)
         * requests here. It should be allowed to pass if the device is in configured
         * state and failed otherwise. */
        if ((bTarget == CY_U3P_USB_TARGET_INTF) && ((bRequest == CY_U3P_USB_SC_SET_FEATURE)
                    || (bRequest == CY_U3P_USB_SC_CLEAR_FEATURE)) && (wValue == 0))
        {
            if (glIsApplnActive)
                CyU3PUsbAckSetup ();
            else
                CyU3PUsbStall (0, CyTrue, CyFalse);

            isHandled = CyTrue;
        }

        /* Handle Microsoft OS String Descriptor request. */
        if ((bTarget == CY_U3P_USB_TARGET_DEVICE) && (bRequest == CY_U3P_USB_SC_GET_DESCRIPTOR) &&
                (wValue == ((CY_U3P_USB_STRING_DESCR << 8) | 0xEE)))
        {
            /* Make sure we do not send more data than requested. */
            if (wLength > CyFxUsbOSDscr[0])
                wLength = CyFxUsbOSDscr[0];

            CyU3PUsbSendEP0Data (wLength, (uint8_t *)CyFxUsbOSDscr);
            isHandled = CyTrue;
            CyU3PDebugPrint (4, "OS String Descriptor Requested\r\n");
    		for (a=0; a < wLength; a=a+1)
    		{
    			if (CyFxUsbOSDscr[a] > 15)
    				CyU3PDebugPrint (2, "\b\b%x ", CyFxUsbOSDscr[a]);
    			else
    				CyU3PDebugPrint (2, "\b\b0%x ", CyFxUsbOSDscr[a]);
    		}
    		CyU3PDebugPrint (4, "\b\b\r\n");
        }

        /* CLEAR_FEATURE request for endpoint is always passed to the setup callback
         * regardless of the enumeration model used. When a clear feature is received,
         * the previous transfer has to be flushed and cleaned up. This is done at the
         * protocol level. Since this is just a loopback operation, there is no higher
         * level protocol. So flush the EP memory and reset the DMA channel associated
         * with it. If there are more than one EP associated with the channel reset both
         * the EPs. The endpoint stall and toggle / sequence number is also expected to be
         * reset. Return CyFalse to make the library clear the stall and reset the endpoint
         * toggle. Or invoke the CyU3PUsbStall (ep, CyFalse, CyTrue) and return CyTrue.
         * Here we are clearing the stall. */
        if ((bTarget == CY_U3P_USB_TARGET_ENDPT) && (bRequest == CY_U3P_USB_SC_CLEAR_FEATURE)
                && (wValue == CY_U3P_USBX_FS_EP_HALT))
        {
            if (glIsApplnActive)
            {
                if (wIndex == P_DCONFIG_EP2OUT)
                {
                	//CyU3PUsbSetEpNak (P_DCONFIG_EP2OUT, CyTrue);
                	//CyU3PBusyWait (100);
                	CyU3PDmaChannelReset (&glChHandleSlFifoUtoP_EP2OUT);
                    CyU3PUsbFlushEp(P_DCONFIG_EP2OUT);
                    //CyU3PUsbSetEpNak (P_DCONFIG_EP2OUT, CyFalse);
                    CyU3PUsbResetEp (P_DCONFIG_EP2OUT);
                    CyU3PDmaChannelSetXfer (&glChHandleSlFifoUtoP_EP2OUT, CY_FX_SLFIFO_DMA_TX_SIZE);
                }

                if (wIndex == P_DGENERATOR_EP4OUT)
                {
                    CyU3PDmaChannelReset (&glChHandleSlFifoUtoP_EP4OUT);
                    CyU3PUsbFlushEp(P_DGENERATOR_EP4OUT);
                    CyU3PUsbResetEp (P_DGENERATOR_EP4OUT);
                    CyU3PDmaChannelSetXfer (&glChHandleSlFifoUtoP_EP4OUT, CY_FX_SLFIFO_DMA_TX_SIZE);
                }

                if (wIndex == C_DFRAME_EP6IN)
                {
                    CyU3PDmaChannelReset (&glChHandleSlFifoPtoU_EP6IN);
                    CyU3PUsbFlushEp(C_DFRAME_EP6IN);
                    CyU3PUsbResetEp (C_DFRAME_EP6IN);
                    CyU3PDmaChannelSetXfer (&glChHandleSlFifoPtoU_EP6IN, CY_FX_SLFIFO_DMA_RX_SIZE);
                }

                CyU3PUsbStall (wIndex, CyFalse, CyTrue);
                isHandled = CyTrue;
            }
        }

    }
    /* handle vendor requests */
    else if (bType == CY_U3P_USB_VENDOR_RQT)
    		{
    		//TODO: Vendor requests
        	switch (bRequest)
        		{
				case VND_CMD_SLAVESER_CFGLOAD:  //B2
					if ((bReqType & 0x80) == 0)
					{
						/* enable ADC clock before starting FPGA configuration */
						CyU3PGpioSimpleSetValue(ADC_CLK_EN, CyTrue);
						// wait 10 ms for clock to stabilise
						CyU3PThreadSleep(10);
						/* Reset ADC: this initiates ADC calibration */
						CyU3PGpioSetValue(ADC_RESETN, CyFalse);
						CyU3PThreadSleep(10); // wait 10 ms
						CyU3PGpioSetValue(ADC_RESETN, CyTrue);

						//read file length from control EP (32 bytes)
						CyU3PUsbGetEP0Data (wLength, glEp0Buffer, NULL);
						filelen = (uint32_t)(glEp0Buffer[3]<<24)|(glEp0Buffer[2]<<16)|(glEp0Buffer[1]<<8)|glEp0Buffer[0];
						glConfigDone = CyTrue;
						/* Set CONFIGFPGAAPP_START_EVENT to start configuring FPGA */
						CyU3PEventSet(&glFxConfigFpgaAppEvent, CY_FX_CONFIGFPGAAPP_START_EVENT,
								CYU3P_EVENT_OR);
						isHandled = CyTrue;
					}
					break;

				case VND_CMD_SLAVESER_CFGSTAT:  //B1
					if ((bReqType & 0x80) == 0x80)
					{
						glEp0Buffer [0]= glConfigStarted && glConfigDone;
						CyU3PUsbSendEP0Data (wLength, glEp0Buffer);

						/* Switch to slaveFIFO interface if FPGA is configured successfully */
						if (glConfigStarted && glConfigDone)
						{
							CyU3PEventSet(&glFxConfigFpgaAppEvent, CY_FX_CONFIGFPGAAPP_SW_TO_SLFIFO_EVENT,
													CYU3P_EVENT_OR);
						}
						/* else, disable ADC clock to save power */
						else
						{
							CyU3PGpioSetValue(ADC_RESETN, CyFalse);
						}
						isHandled = CyTrue;

					}
					break;

				case CY_FX_RQT_ID_CHECK:		//B0: send firmware ID
					CyU3PUsbSendEP0Data (16, (uint8_t *)glFirmwareID);
					isHandled = CyTrue;
					break;

				case CY_FX_RQT_I2C_EEPROM_WRITE:
					i2cAddr = 0xA0 | ((wValue & 0x0003) << 1);
					status  = CyU3PUsbGetEP0Data(wLength, glEp0Buffer, NULL);
					if (status == CY_U3P_SUCCESS)
					{
						CyFxUsbI2cTransfer (wIndex, i2cAddr, wLength,
								glEp0Buffer, CyFalse);
					}
					isHandled = CyTrue;
					break;

				case CY_FX_RQT_I2C_EEPROM_READ:
					i2cAddr = 0xA0 | ((wValue & 0x0003) << 1);
					CyU3PMemSet (glEp0Buffer, 0, sizeof (glEp0Buffer));
					status = CyFxUsbI2cTransfer (wIndex, i2cAddr, wLength,
							glEp0Buffer, CyTrue);
					if (status == CY_U3P_SUCCESS)
					{
						status = CyU3PUsbSendEP0Data(wLength, glEp0Buffer);
					}
					isHandled = CyTrue;
					break;

				case 0xE0:  //ADC & FPGA CLOCK <ENABLE> (use it before fpga is configured)
				{
					CyU3PUsbAckSetup();
					CyU3PGpioSimpleSetValue(ADC_CLK_EN, CyTrue);
				    // wait 10 ms for clock to stabilise
			        CyU3PThreadSleep(10);
				    /* Reset ADC: this initiates ADC internal calibration */
			        CyU3PGpioSetValue(ADC_RESETN, CyFalse);
			        CyU3PThreadSleep(10); // wait 10 ms
			        CyU3PGpioSetValue(ADC_RESETN, CyTrue);
				}
				isHandled = CyTrue;

				break;

				case 0xE1:  /*ADC & FPGA CLOCK <DISABLE> -this is not working after FPGA is configured
					        * because GPIO is not initialised after GPIF reconfiguration to 32-bit */

				{
					CyU3PUsbAckSetup();
					status = CyU3PGpioSimpleSetValue(ADC_CLK_EN, CyFalse); // maybe we should use GPIO override instead
					if (status != CY_U3P_SUCCESS)
					{
					    CyU3PDebugPrint (4, "Set ADC_CLK_EN failed, Error code = %d\n", status);
					    CyFxAppErrorHandler (status);
					}
				}
				isHandled = CyTrue;
				break;

				case 0xEE:
					{
						CyU3PUsbAckSetup();
				        //toggle PROG_B to reset FPGA
				        CyU3PSpiSetSsnLine(CyFalse);
				        CyU3PThreadSleep(10);
				        CyU3PSpiSetSsnLine(CyTrue);
						CyU3PThreadSleep(100);  /* wait for 100 ms */
						CyU3PDeviceReset(CyFalse);
					}
					isHandled = CyTrue;
					break;

                case 0xEF:
                    /* Send the USB event log buffer content to the host. */
                    if (wLength != 0)
                    {
                        if (wLength < CYFX_USBLOG_SIZE)
                            CyU3PUsbSendEP0Data (wLength, gl_UsbLogBuffer);
                        else
                            CyU3PUsbSendEP0Data (CYFX_USBLOG_SIZE, gl_UsbLogBuffer);
                    }
                    else
                        CyU3PUsbAckSetup ();
					isHandled = CyTrue;
                    break;

		        case VND_CMD_GET_MS_DESCRIPTOR:
		        	/* bReqType (when recipient is device)    : 0xC0
	        		   bReqType (when recipient is interface) : 0xC1
		        	   Extended compat ID wIndex  : 0x0004
	        		   Extended properties wIndex : 0x0005 */
		        	/* Handle OS Feature Compatible IDs descriptor request. */
		        	if ((bReqType == 0xC0) && (wIndex == 0x04))
		        	{
			            if (wLength > CyFxUsbExtCompatIdOSFeatureDscr[0])
			                wLength = CyFxUsbExtCompatIdOSFeatureDscr[0];
		        		CyU3PUsbSendEP0Data (wLength, (uint8_t *)CyFxUsbExtCompatIdOSFeatureDscr);
		        		CyU3PDebugPrint (4, "\bOS Feature Descriptor Requested: Ext. compat ID\r\n");
		        		for (a=0; a < wLength; a=a+1)
		        		{
		        			if (CyFxUsbExtCompatIdOSFeatureDscr[a] > 15)
		        				CyU3PDebugPrint (2, "\b\b%x ", CyFxUsbExtCompatIdOSFeatureDscr[a]);
		        			else
		        				CyU3PDebugPrint (2, "\b\b0%x ", CyFxUsbExtCompatIdOSFeatureDscr[a]);
		        		}
		        		CyU3PDebugPrint (4, "\b\b \r\n");
		        		isHandled = CyTrue;
		        	}
					/* Handle OS Feature Extended Properties descriptor request. */
		        	else if ((bReqType == 0xC0 || bReqType == 0xC1) && (wIndex == 0x05))
		        	{
		                if (wLength > CyFxUsbExtPropertiesOSFeatureDscr[0])
		                    wLength = CyFxUsbExtPropertiesOSFeatureDscr[0];
		        		CyU3PUsbSendEP0Data (wLength, (uint8_t *)CyFxUsbExtPropertiesOSFeatureDscr);
		        		CyU3PDebugPrint (4, "\bOS Feature Descriptor Requested: Ext. properties\r\n");
		        		for (a=0; a < wLength; a=a+1)
		        		{
		        			if (CyFxUsbExtPropertiesOSFeatureDscr[a] > 15)
		        				CyU3PDebugPrint (2, "\b\b%x ", CyFxUsbExtPropertiesOSFeatureDscr[a]);
		        			else
		        				CyU3PDebugPrint (2, "\b\b0%x ", CyFxUsbExtPropertiesOSFeatureDscr[a]);
		        		}
		        		CyU3PDebugPrint (4, "\b\b\r\n");
						isHandled = CyTrue;
		        	}
		        	break;

#ifdef EXPLORE_GPIF_NOISE
		        case 0xEA:

					int zf=glErrorResetFlag;

					*(uint64_t *)(Ep0Buffer+0) = zf?0:glPhyErrorCount;  //64-bit counter
					*(uint64_t *)(Ep0Buffer+8) = zf?0:glLnkErrorCount;  //64-bit counter
					*(uint32_t *)(Ep0Buffer+16)= glUSBDisconnectCount;      //32-bit counter
					Ep0Buffer[20] = CyU3PUsbGetSpeed(); // Error counters have meaning only in USB 3.0 SuperSpeed mode

					// if wValue!=0 then, as side effect, reset PHY and LINK error counters
					if (wValue)
					{
						glErrorResetFlag=1;
					}

					if (wLength)
					{
						CyU3PUsbSendEP0Data(CY_U3P_MIN(wLength, 21), (uint8_t *)Ep0Buffer);
					}
					else
					{
						CyU3PUsbAckSetup ();
					}
					// request is handled
					isHandled = CyTrue;
                    break;
#endif
		        case 0xEB:

		        	*(uint16_t *)(Ep0Buffer+0) = glThr0_WR_OVERRUN_Cnt;   //16-bit counter
					*(uint16_t *)(Ep0Buffer+2) = glThr2_WR_OVERRUN_Cnt;   //16-bit counter
					*(uint16_t *)(Ep0Buffer+4) = glThr3_WR_OVERRUN_Cnt;   //16-bit counter
					*(uint16_t *)(Ep0Buffer+6) = glThr0_RD_UNDERRUN_Cnt;  //16-bit counter
					*(uint16_t *)(Ep0Buffer+8) = glThr2_RD_UNDERRUN_Cnt;  //16-bit counter
					*(uint16_t *)(Ep0Buffer+10) = glThr3_RD_UNDERRUN_Cnt; //16-bit counter

                    /* Send the GPIF error counters to the host. */
					if (wLength != 0)
					{
						if (wLength < 0x000C)
							CyU3PUsbSendEP0Data (wLength, (uint8_t *)Ep0Buffer);
						else
							CyU3PUsbSendEP0Data (0x000C, (uint8_t *)Ep0Buffer);
					}
					else
					{
						CyU3PUsbAckSetup ();
					}

					// if wValue!=0 then reset GPIF error counters
					if (wValue != 0)
					{
						glThr0_WR_OVERRUN_Cnt = 0;
						glThr2_WR_OVERRUN_Cnt = 0;
						glThr3_WR_OVERRUN_Cnt = 0;
						glThr0_RD_UNDERRUN_Cnt = 0;
						glThr2_RD_UNDERRUN_Cnt = 0;
						glThr3_RD_UNDERRUN_Cnt = 0;
					}
					// request is handled
					isHandled = CyTrue;
                    break;

		        default:
					/* This is unknown request. */
					isHandled = CyFalse;
					break;
        		}

           }
    		return isHandled;
 }

/* This is the callback function to handle the USB events. */
void
CyFxSlFifoApplnUSBEventCB (
    CyU3PUsbEventType_t evtype,
    uint16_t            evdata
    )
{
    switch (evtype)
    {
        case CY_U3P_USB_EVENT_SETCONF:
            /* Stop the application before re-starting. */
            if (glIsApplnActive)
            {
                CyFxSlFifoApplnStop ();

            }
            CyU3PUsbLPMDisable();
            /* Start the loop back function. */
            CyFxConfigFpgaApplnStart();
            break;

        case CY_U3P_USB_EVENT_RESET:
        case CY_U3P_USB_EVENT_DISCONNECT:
            /* Stop the loop back function. */
            if (glIsApplnActive)
            {
                /* Reset the I2C channels. */
                //CyU3PDmaChannelReset (&glI2cTxHandle);
                //CyU3PDmaChannelReset (&glI2cRxHandle);
                CyFxSlFifoApplnStop ();
            }
            break;

        default:
            break;
    }
}

/* Callback function to handle LPM requests from the USB 3.0 host. This function is invoked by the API
   whenever a state change from U0 -> U1 or U0 -> U2 happens. If we return CyTrue from this function, the
   FX3 device is retained in the low power state. If we return CyFalse, the FX3 device immediately tries
   to trigger an exit back to U0.

   This application does not have any state in which we should not allow U1/U2 transitions; and therefore
   the function always return CyTrue.
 */
CyBool_t
CyFxApplnLPMRqtCB (
        CyU3PUsbLinkPowerMode link_mode)
{
    return CyTrue;
}


/* This function initializes the GPIF interface and initializes
 * the USB interface. */
void
CyFxSlFifoApplnInit (void)
{
    CyU3PPibClock_t pibClock;
    CyU3PReturnStatus_t apiRetStatus = CY_U3P_SUCCESS;

    /* Initialize the p-port block. */
    pibClock.clkDiv = 2;
    pibClock.clkSrc = CY_U3P_SYS_CLK;
    pibClock.isHalfDiv = CyFalse;
    /* Disable DLL for sync GPIF */
    pibClock.isDllEnable = CyFalse;
    apiRetStatus = CyU3PPibInit(CyTrue, &pibClock);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "P-port Initialization failed, Error Code = %d\n",apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* Register a callback for notification of PIB interrupts */
    CyU3PPibRegisterCallback(gpif_error_cb, 0xffff);

    /* Load the GPIF configuration for Slave FIFO sync mode. */
    apiRetStatus = CyU3PGpifLoad (&CyFxGpifConfig);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PGpifLoad failed, Error Code = %d\n",apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

    /* FLAGD is EP6OUT FULL flag, active LOW */
    /* Set FLAGD watermark level to 9 => this means that 5 more data words
     * will be available in FX3 fifo after flagd asserted low */
    //CyU3PGpifSocketConfigure (0,CY_U3P_PIB_SOCKET_0,9,CyFalse,1); // SOCKET FOR EP6IN (data)
    //CyU3PGpifSocketConfigure (2,CY_U3P_PIB_SOCKET_2,2,CyFalse,1); // SOCKET FOR EP4OUT (signal)
    //CyU3PGpifSocketConfigure (3,CY_U3P_PIB_SOCKET_3,2,CyFalse,1); // SOCKET FOR EP2OUT (control)

    /* Start the state machine. */
    apiRetStatus = CyU3PGpifSMStart (RESET,ALPHA_RESET);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
        CyU3PDebugPrint (4, "CyU3PGpifSMStart failed, Error Code = %d\n",apiRetStatus);
        CyFxAppErrorHandler(apiRetStatus);
    }

}
void
CyFxSwitchtoslFifo (
		void)
{

	CyU3PIoMatrixConfig_t io_cfg;
    CyU3PReturnStatus_t apiRetStatus = CY_U3P_SUCCESS;
    CyU3PGpioSimpleConfig_t gpioConfig;
    CyU3PGpioClock_t gpioClock;

	io_cfg.useUart   = CyTrue;
    io_cfg.useI2C    = CyFalse;
    io_cfg.useI2S    = CyFalse;
    io_cfg.useSpi    = CyFalse;
    io_cfg.isDQ32Bit = CyTrue;
    //io_cfg.isDQ32Bit  = CyFalse;   	                  // <= enable this for debugging
    io_cfg.lppMode   = CY_U3P_IO_MATRIX_LPP_DEFAULT;
    //io_cfg.lppMode   = CY_U3P_IO_MATRIX_LPP_UART_ONLY;  // <= enable this for debugging
    /* Enable only GPIO for FPGA clock enable (45) */
    io_cfg.gpioSimpleEn[0]  = 0x00000000;  // first set of GPIOs [ 31,30,......,2,1,0 ]
    io_cfg.gpioSimpleEn[1]  = 0x00000000;  //second set of GPIOs [ 63,62,...,34,33,32 ]
    //io_cfg.gpioSimpleEn[1]  = 0x00002000;  //second set of GPIOs [ 63,62,...,34,33,32 ]
    io_cfg.gpioComplexEn[0] = 0;
    io_cfg.gpioComplexEn[1] = 0;
    apiRetStatus = CyU3PDeviceConfigureIOMatrix (&io_cfg);
    if (apiRetStatus != CY_U3P_SUCCESS)
    {
    	while (1);		/* Cannot recover from this error. */
    }
    CyU3PDebugPrint (4, "Re-Configure IO Matrix success!\r\n");

#if 0
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

        /* Configure GPIO 45 as output */
        gpioConfig.outValue = CyTrue;    //< Initial value of the GPIO if configured as output:
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

          /*********************/
          /* Configure GPIO end*/
          /*********************/
#endif

#if 0
        CyU3PIoMatrixConfig_t io_cfg;
    	CyU3PReturnStatus_t status = CY_U3P_SUCCESS;
    	io_cfg.useUart   = CyTrue;
        io_cfg.useI2C    = CyFalse;
        io_cfg.useI2S    = CyFalse;
        io_cfg.useSpi    = CyFalse;
    #if (CY_FX_SLFIFO_GPIF_16_32BIT_CONF_SELECT == 0)
        io_cfg.isDQ32Bit = CyFalse;
        io_cfg.lppMode   = CY_U3P_IO_MATRIX_LPP_UART_ONLY;
        /*io_cfg.lppMode   = CY_U3P_IO_MATRIX_LPP_DEFAULT;*/
    #else
        io_cfg.isDQ32Bit = CyFalse;
        io_cfg.lppMode   = CY_U3P_IO_MATRIX_LPP_UART_ONLY;
    #endif
        /* No GPIOs are enabled. */
        io_cfg.gpioSimpleEn[0]  = 0x00000000;
        io_cfg.gpioSimpleEn[1]  = 0;
        io_cfg.gpioComplexEn[0] = 0;
        io_cfg.gpioComplexEn[1] = 0;
        status = CyU3PDeviceConfigureIOMatrix (&io_cfg);
        if (status != CY_U3P_SUCCESS)
        {
        	while (1);		/* Cannot recover from this error. */
        }
        CyU3PDebugPrint (4, "CyU3PDeviceConfigureIOMatrix success!\r\n");
#endif

}

/* Entry function for the slFifoAppThread. */
/* TODO: SlFifoAppThread_Entry */
void
SlFifoAppThread_Entry (
        uint32_t input)
{
	uint32_t eventFlag;
	CyU3PReturnStatus_t txApiRetStatus = CY_U3P_SUCCESS;

	/* Initialize the debug module */
    CyFxSlFifoApplnDebugInit();
    CyU3PDebugPrint (1, "\n\nDebug initialized\r\n");

    /* Initialize the I2C application */
    txApiRetStatus = CyFxI2cInit (CY_FX_USBI2C_I2C_PAGE_SIZE);
    if (txApiRetStatus != CY_U3P_SUCCESS)
    {
        goto handle_error;
    }

    /* Initialize the FPGA configuration application */
    CyFxConfigFpgaApplnInit();

    for (;;)
    {
        /*CyU3PThreadSleep (1000);*/
        if (glIsApplnActive)
        {

        	/* Wait for events to configure FPGA */
        	        txApiRetStatus = CyU3PEventGet (&glFxConfigFpgaAppEvent,
        	                (CY_FX_CONFIGFPGAAPP_START_EVENT | CY_FX_CONFIGFPGAAPP_SW_TO_SLFIFO_EVENT),
        	                CYU3P_EVENT_OR_CLEAR, &eventFlag, CYU3P_WAIT_FOREVER);
        	        if (txApiRetStatus == CY_U3P_SUCCESS)
        	        {
        	            if (eventFlag & CY_FX_CONFIGFPGAAPP_START_EVENT)
        	            {
        	                /* Start configuring FPGA */
        	            	CyU3PDebugPrint (6, "Starting FPGA config; seqnum: %d\r\n", seqnum_p);
        	            	CyFxConfigFpga(filelen);

        	            }
        	            else if ((eventFlag & CY_FX_CONFIGFPGAAPP_SW_TO_SLFIFO_EVENT))
        	            {
        	                /* Switch to SlaveFIFO interface */
        	            	//CyU3PDebugPrint (6, "CyFxI2cDeinit\r\n");
        	            	//CyFxI2cDeinit();
        	            	//CyU3PDebugPrint (6, "CyFxConfigFpgaApplnStop\r\n");
        	            	CyFxConfigFpgaApplnStop();
        	            	//CyU3PDebugPrint (6, "Data tracker: seqnum_p: %d \r\n", seqnum_p);
							//CyU3PDebugPrint (6, "CyFxSwitchtoslFifo\r\n");
        	            	CyFxSwitchtoslFifo();
							//CyU3PDebugPrint (6, "SlFifoApplnInit\r\n");
        	            	CyFxSlFifoApplnInit();
							CyFxSlFifoApplnStart();
							CyU3PDebugPrint (6, "SLAVE FIFO APP ACTIVE!\r\n");
        	            }
        	        }

            /* Print the number of buffers received so far from the USB host. */
            //CyU3PDebugPrint (6, "Data tracker: buffers received: %d, buffers sent: %d.\r\n",glDMARxCount, glDMATxCount);
        }
#ifdef EXPLORE_GPIF_NOISE
    	// Query for error counts once per second.
    	// Hopefully internal 16-bit counters do not overflow with that time.
    	CyU3PThreadSleep (1000);
		{
        	uint16_t phy_err_cnt = 0;
			uint16_t lnk_err_cnt = 0;
			CyU3PReturnStatus_t status = CyU3PUsbGetErrorCounts(&phy_err_cnt, &lnk_err_cnt);
			if (glErrorResetFlag)
			{
				// User wanted to reset counters
				glPhyErrorCount = 0;
				glLnkErrorCount = 0;
				glErrorResetFlag=0;
			}
			else if (CY_U3P_SUCCESS==status)
			{
				glPhyErrorCount += phy_err_cnt;
				glLnkErrorCount += lnk_err_cnt;
			}
		}
#endif
    }

    handle_error:
        CyU3PDebugPrint (4, "%x: Application failed to initialize. Error code: %d.\n", txApiRetStatus);
        while (1);
}

/* Application define function which creates the threads. */
void
CyFxApplicationDefine (
        void)
{
    void *ptr = NULL;
    uint32_t retThrdCreate = CY_U3P_SUCCESS;

    /* Allocate the memory for the thread */
    ptr = CyU3PMemAlloc (CY_FX_SLFIFO_THREAD_STACK);

    /* Create the thread for the application */
    retThrdCreate = CyU3PThreadCreate (&slFifoAppThread,           /* Slave FIFO app thread structure */
                          "21:Slave_FIFO_sync",                    /* Thread ID and thread name */
                          SlFifoAppThread_Entry,                   /* Slave FIFO app thread entry function */
                          0,                                       /* No input parameter to thread */
                          ptr,                                     /* Pointer to the allocated thread stack */
                          CY_FX_SLFIFO_THREAD_STACK,               /* App Thread stack size */
                          CY_FX_SLFIFO_THREAD_PRIORITY,            /* App Thread priority */
                          CY_FX_SLFIFO_THREAD_PRIORITY,            /* App Thread pre-emption threshold */
                          CYU3P_NO_TIME_SLICE,                     /* No time slice for the application thread */
                          CYU3P_AUTO_START                         /* Start the thread immediately */
                          );

    /* Check the return code */
    if (retThrdCreate != 0)
    {
        /* Thread Creation failed with the error code retThrdCreate */

        /* Add custom recovery or debug actions here */

        /* Application cannot continue */
        /* Loop indefinitely */
        while(1);
    }
}



/* [ ] */

