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

#ifndef _INCLUDED_CYFXUSBI2CREGMODE_H_
#define _INCLUDED_CYFXUSBI2CREGMODE_H_

#include "cyu3types.h"
#include "cyu3usbconst.h"
#include "cyu3externcstart.h"

/* EEPROM part number used is M24M02-DR. The capacity of the EEPROM is 256K bytes */

/* The following constant is defined based on the page size that the I2C
 * device support. M24M02-DR support 256 byte page write. */
#define CY_FX_USBI2C_I2C_PAGE_SIZE      (64)

/* I2C Data rate */
#define CY_FX_USBI2C_I2C_BITRATE        (400000)

/* Give a timeout value of 5s for any programming.  */
//#define CY_FX_USB_I2C_TIMEOUT                (5000)

/* USB vendor requests supported by the application. */

/* USB vendor request to read the 8 byte firmware ID. This will return content 
 * of glFirmwareID array. */
#define CY_FX_RQT_ID_CHECK                      (0xB0)

/* USB vendor request to write to I2C EEPROM connected. The EEPROM page size is
 * fixed to 64 bytes. The I2C EEPROM address is provided in the value field. The
 * memory address to start writing is provided in the index field of the request.
 * The maximum allowed request length is 4KB. */
#define CY_FX_RQT_I2C_EEPROM_WRITE              (0xBA)

/* USB vendor request to read from I2C EEPROM connected. The EEPROM page size is
 * fixed to 64 bytes. The I2C EEPROM address is provided in the value field. The
 * memory address to start reading from is provided in the index field of the
 * request. The maximum allowed request length is 4KB. */
#define CY_FX_RQT_I2C_EEPROM_READ               (0xBB)

extern CyU3PReturnStatus_t CyFxI2cInit (
		uint16_t pageLen);

extern CyU3PReturnStatus_t CyFxUsbI2cTransfer (
		uint16_t  byteAddress,
		uint8_t   devAddr,
		uint16_t  byteCount,
		uint8_t  *buffer,
		CyBool_t  isRead);

extern void CyFxI2cDeinit (
		void);

#include "cyu3externcend.h"

#endif /* _INCLUDED_CYFXUSBI2CREGMODE_H_ */

/*[]*/
