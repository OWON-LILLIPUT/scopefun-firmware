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

#ifndef _INCLUDED_CYFXSLFIFOASYNC_H_
#define _INCLUDED_CYFXSLFIFOASYNC_H_

#include "cyu3externcstart.h"
#include "cyu3types.h"
#include "cyu3usbconst.h"

/* 16/32 bit GPIF Configuration select */
/* Set CY_FX_SLFIFO_GPIF_16_32BIT_CONF_SELECT = 0 for 16 bit GPIF data bus.
 * Set CY_FX_SLFIFO_GPIF_16_32BIT_CONF_SELECT = 1 for 32 bit GPIF data bus.
 */
#define CY_FX_SLFIFO_GPIF_16_32BIT_CONF_SELECT (1)
/* set up DMA channel for loopback/short packet/ZLP transfers */
#define LOOPBACK_SHRT_ZLP
//#define MANUAL
/* set up DMA channel for stream IN/OUT transfers */
//#define STREAM_IN_OUT
//#define EXPLORE_GPIF_NOISE

//#define USB_2_0

#ifdef LOOPBACK_SHRT_ZLP
#define DMA_BUF_SIZE						  (1)  /* If sending data from fpga whose size is less than the
                                                      DMA buffer size, then it is counted as a short packet.
                                                      A short packet can be committed to the USB host from
                                                      GPIF end by using the PKTEND# */
#define CY_FX_SLFIFO_DMA_BUF_COUNT_P_2_U      (64)  /* Slave FIFO P_2_U channel buffer count */
#define CY_FX_SLFIFO_DMA_BUF_COUNT_U_2_P 	  (2)    /* Slave FIFO U_2_P channel buffer count */
#endif

#define CY_FX_SLFIFO_DMA_TX_SIZE        (0)	                  /* DMA transfer size is set to infinite */
#define CY_FX_SLFIFO_DMA_RX_SIZE        (0)	                  /* DMA transfer size is set to infinite */
#define CY_FX_SLFIFO_THREAD_STACK       (0x0800)              /* Slave FIFO application thread stack size */
#define CY_FX_SLFIFO_THREAD_PRIORITY    (8)                   /* Slave FIFO application thread priority */

/* Endpoint and socket definitions for the Slave FIFO application */

/* To change the Producer and Consumer EP enter the appropriate EP numbers for the #defines.
 * In the case of IN endpoints enter EP number along with the direction bit.
 * For eg. EP 6 IN endpoint is 0x86
 *     and EP 6 OUT endpoint is 0x06.
 * To change sockets mention the appropriate socket number in the #defines. */

/* Note: For USB 2.0 the endpoints and corresponding sockets are one-to-one mapped
         i.e. EP 1 is mapped to UIB socket 1 and EP 2 to socket 2 so on */

#define P_DCONFIG_EP2OUT              0x02    /* EP 2 OUT */
#define P_DGENERATOR_EP4OUT           0x04    /* EP 4 OUT */
#define C_DFRAME_EP6IN                0x86    /* EP 6 IN */

#define CY_FX_P1_USB_SOCKET    CY_U3P_UIB_SOCKET_PROD_2    /* USB Socket 2 is producer */
#define CY_FX_P2_USB_SOCKET    CY_U3P_UIB_SOCKET_PROD_4    /* USB Socket 4 is producer */
#define CY_FX_C1_USB_SOCKET    CY_U3P_UIB_SOCKET_CONS_6    /* USB Socket 6 is consumer */

/* Used with FX3 Silicon. */
#define CY_FX_P1_PPORT_SOCKET    CY_U3P_PIB_SOCKET_0    /* P-port Socket 0 is producer */
#define CY_FX_C2_PPORT_SOCKET    CY_U3P_PIB_SOCKET_2    /* P-port Socket 2 is consumer */
#define CY_FX_C1_PPORT_SOCKET    CY_U3P_PIB_SOCKET_3    /* P-port Socket 3 is consumer */

#ifdef STREAM_IN_OUT
#ifdef USB_2_0
#define BURST_LEN 1  //for USB2.0
#else
#define BURST_LEN 16 //for USB3.0
#endif
#endif
#ifdef LOOPBACK_SHRT_ZLP
#define BURST_LEN 1
#endif

/* Extern definitions for the USB Descriptors */
extern const uint8_t CyFxUSB20DeviceDscr[];
extern const uint8_t CyFxUSB30DeviceDscr[];
extern const uint8_t CyFxUSBDeviceQualDscr[];
extern const uint8_t CyFxUSBFSConfigDscr[];
extern const uint8_t CyFxUSBHSConfigDscr[];
extern const uint8_t CyFxUSBBOSDscr[];
extern const uint8_t CyFxUSBSSConfigDscr[];
extern const uint8_t CyFxUSBStringLangIDDscr[];
extern const uint8_t CyFxUSBManufactureDscr[];
extern const uint8_t CyFxUSBProductDscr[];
extern const uint8_t CyFxUSBSerialNumDesc[];

/* Extern definitions for the MS OS String and Feature Descriptors */
extern const uint8_t CyFxUsbOSDscr[];
extern const uint8_t CyFxUsbExtCompatIdOSFeatureDscr[];
extern const uint8_t CyFxUsbExtPropertiesOSFeatureDscr[];

#include "cyu3externcend.h"

#endif /* _INCLUDED_CYFXSLFIFOASYNC_H_ */

/*[]*/
