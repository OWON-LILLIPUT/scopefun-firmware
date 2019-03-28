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

#include "cyfxslfifosync.h"

/* Standard device descriptor for USB 3.0 */
const uint8_t CyFxUSB30DeviceDscr[] __attribute__ ((aligned (32))) =
{
    0x12,                           /* Descriptor size */
    CY_U3P_USB_DEVICE_DESCR,        /* Device descriptor type */
    0x00,0x03,                      /* USB 3.0 */
    0x00,                           /* Device class */
    0x00,                           /* Device sub-class */
    0x00,                           /* Device protocol */
    0x09,                           /* Maxpacket size for EP0 : 2^9 */
    0x50,0x1d,                      /* Vendor ID (little-endian)*/
    0x04,0x61,                      /* Product ID (little-endian)*/
    0x11,0x00,                      /* Device release number */
    0x01,                           /* Manufacture string index */
    0x02,                           /* Product string index */
    0x03,                           /* Serial number string index */
    0x01                            /* Number of configurations */
};

/* Standard device descriptor for USB 2.0 */
const uint8_t CyFxUSB20DeviceDscr[] __attribute__ ((aligned (32))) =
{
    0x12,                           /* Descriptor size */
    CY_U3P_USB_DEVICE_DESCR,        /* Device descriptor type */
    0x10,0x02,                      /* USB 2.10 */
    0x00,                           /* Device class */
    0x00,                           /* Device sub-class */
    0x00,                           /* Device protocol */
    0x40,                           /* Maxpacket size for EP0 : 64 bytes */
    0x50,0x1d,                      /* Vendor ID (little-endian)*/
    0x04,0x61,                      /* Product ID (little-endian)*/
    0x11,0x00,                      /* Device release number */
    0x01,                           /* Manufacture string index */
    0x02,                           /* Product string index */
    0x03,                           /* Serial number string index */
    0x01                            /* Number of configurations */
};

/* Binary device object store descriptor */
const uint8_t CyFxUSBBOSDscr[] __attribute__ ((aligned (32))) =
{
    0x05,                           /* Descriptor size */
    CY_U3P_BOS_DESCR,               /* Device descriptor type */
    0x16,0x00,                      /* Length of this descriptor and all sub descriptors */
    0x02,                           /* Number of device capability descriptors */

    /* USB 2.0 extension */
    0x07,                           /* Descriptor size */
    CY_U3P_DEVICE_CAPB_DESCR,       /* Device capability type descriptor */
    CY_U3P_USB2_EXTN_CAPB_TYPE,     /* USB 2.0 extension capability type */
    0x02,0x00,0x00,0x00,            /* Supported device level features: LPM support  */

    /* SuperSpeed device capability */
    0x0A,                           /* Descriptor size */
    CY_U3P_DEVICE_CAPB_DESCR,       /* Device capability type descriptor */
    CY_U3P_SS_USB_CAPB_TYPE,        /* SuperSpeed device capability type */
    0x00,                           /* Supported device level features  */
    0x0E,0x00,                      /* Speeds supported by the device : SS, HS and FS */
    0x03,                           /* Functionality support */
    0x00,                           /* U1 Device Exit latency */
    0x00,0x00                       /* U2 Device Exit latency */
};

/* Standard device qualifier descriptor */
const uint8_t CyFxUSBDeviceQualDscr[] __attribute__ ((aligned (32))) =
{
    0x0A,                           /* Descriptor size */
    CY_U3P_USB_DEVQUAL_DESCR,       /* Device qualifier descriptor type */
    0x00,0x02,                      /* USB 2.0 */
    0x00,                           /* Device class */
    0x00,                           /* Device sub-class */
    0x00,                           /* Device protocol */
    0x40,                           /* Maxpacket size for EP0 : 64 bytes */
    0x01,                           /* Number of configurations */
    0x00                            /* Reserved */
};

/* Standard super speed configuration descriptor */
const uint8_t CyFxUSBSSConfigDscr[] __attribute__ ((aligned (32))) =
{
    /* Configuration descriptor */
    0x09,                           /* Descriptor size */
    CY_U3P_USB_CONFIG_DESCR,        /* Configuration descriptor type */
    0x39,0x00,                      /* Length of this descriptor and all sub descriptors 2c */
    0x01,                           /* Number of interfaces */
    0x01,                           /* Configuration number */
    0x00,                           /* COnfiguration string index */
    0x80,                           /* Config characteristics - Bus powered */
    0x70,                           /* Max power consumption of device (in 8mA unit) : 896mA */

    /* Interface descriptor */
    0x09,                           /* Descriptor size */
    CY_U3P_USB_INTRFC_DESCR,        /* Interface Descriptor type */
    0x00,                           /* Interface number */
    0x00,                           /* Alternate setting number */
    0x03,                           /* Number of end points */
    0xFF,                           /* Interface class */
    0x00,                           /* Interface sub class */
    0x00,                           /* Interface protocol code */
    0x00,                           /* Interface descriptor string index */

    /* Endpoint descriptor for producer EP P_DCONFIG_EP2OUT */
    0x07,                           /* Descriptor size */
    CY_U3P_USB_ENDPNT_DESCR,        /* Endpoint descriptor type */
    P_DCONFIG_EP2OUT,              /* Endpoint address and description */
    CY_U3P_USB_EP_BULK,             /* Bulk endpoint type */
    0x00,0x04,                      /* Max packet size = 1024 bytes */
    0x00,                           /* Servicing interval for data transfers : 0 for bulk */

    /* Super speed endpoint companion descriptor for producer EP P_DCONFIG_EP2OUT */
    0x06,                           /* Descriptor size */
    CY_U3P_SS_EP_COMPN_DESCR,       /* SS endpoint companion descriptor type */
  //  0x00,                           /* Max no. of packets in a burst : 0: burst 1 packet at a time */
    BURST_LEN-1,						/* Max no. of packets in a burst : 0: burst 1 packet at a time */
    0x00,                           /* Max streams for bulk EP = 0 (No streams) */
    0x00,0x00,                      /* Service interval for the EP : 0 for bulk */

    /* Endpoint descriptor for producer EP P_DGENERATOR_EP4OUT */
    0x07,                           /* Descriptor size */
    CY_U3P_USB_ENDPNT_DESCR,        /* Endpoint descriptor type */
    P_DGENERATOR_EP4OUT,              /* Endpoint address and description */
    CY_U3P_USB_EP_BULK,             /* Bulk endpoint type */
    0x00,0x04,                      /* Max packet size = 1024 bytes */
    0x00,                           /* Servicing interval for data transfers : 0 for bulk */

    /* Super speed endpoint companion descriptor for producer EP P_DGENERATOR_EP4OUT */
    0x06,                           /* Descriptor size */
    CY_U3P_SS_EP_COMPN_DESCR,       /* SS endpoint companion descriptor type */
  //  0x00,                           /* Max no. of packets in a burst : 0: burst 1 packet at a time */
    BURST_LEN-1,						/* Max no. of packets in a burst : 0: burst 1 packet at a time */
    0x00,                           /* Max streams for bulk EP = 0 (No streams) */
    0x00,0x00,                      /* Service interval for the EP : 0 for bulk */

    /* Endpoint descriptor for consumer EP */
    0x07,                           /* Descriptor size */
    CY_U3P_USB_ENDPNT_DESCR,        /* Endpoint descriptor type */
    C_DFRAME_EP6IN,              /* Endpoint address and description */
    CY_U3P_USB_EP_BULK,             /* Bulk endpoint type */
    0x00,0x04,                      /* Max packet size = 1024 bytes */
    0x00,                           /* Servicing interval for data transfers : 0 for Bulk */

    /* Super speed endpoint companion descriptor for consumer EP */
    0x06,                           /* Descriptor size */
    CY_U3P_SS_EP_COMPN_DESCR,       /* SS endpoint companion descriptor type */
 //   0x00,                           /* Max no. of packets in a burst : 0: burst 1 packet at a time */
    BURST_LEN-1,						/* Max no. of packets in a burst : 0: burst 1 packet at a time */
    0x00,                           /* Max streams for bulk EP = 0 (No streams) */
    0x00,0x00                       /* Service interval for the EP : 0 for bulk */
};

/* Standard high speed configuration descriptor */
const uint8_t CyFxUSBHSConfigDscr[] __attribute__ ((aligned (32))) =
{
    /* Configuration descriptor */
    0x09,                           /* Descriptor size */
    CY_U3P_USB_CONFIG_DESCR,        /* Configuration descriptor type */
    0x27,0x00,                      /* Length of this descriptor and all sub descriptors */
    0x01,                           /* Number of interfaces */
    0x01,                           /* Configuration number */
    0x00,                           /* COnfiguration string index */
    0x80,                           /* Config characteristics - bus powered */
    0xFA,                           /* Max power consumption of device (in 2mA unit) : 500mA */

    /* Interface descriptor */
    0x09,                           /* Descriptor size */
    CY_U3P_USB_INTRFC_DESCR,        /* Interface Descriptor type */
    0x00,                           /* Interface number */
    0x00,                           /* Alternate setting number */
    0x03,                           /* Number of endpoints */
    0xFF,                           /* Interface class */
    0x00,                           /* Interface sub class */
    0x00,                           /* Interface protocol code */
    0x00,                           /* Interface descriptor string index */

    /* Endpoint descriptor for producer EP P_DCONFIG_EP2OUT */
    0x07,                           /* Descriptor size */
    CY_U3P_USB_ENDPNT_DESCR,        /* Endpoint descriptor type */
    P_DCONFIG_EP2OUT,              /* Endpoint address and description */
    CY_U3P_USB_EP_BULK,             /* Bulk endpoint type */
    0x00,0x02,                      /* Max packet size = 512 bytes */
    0x00,                           /* Servicing interval for data transfers : 0 for bulk */

    /* Endpoint descriptor for producer EP P_DGENERATOR_EP4OUT */
    0x07,                           /* Descriptor size */
    CY_U3P_USB_ENDPNT_DESCR,        /* Endpoint descriptor type */
    P_DGENERATOR_EP4OUT,              /* Endpoint address and description */
    CY_U3P_USB_EP_BULK,             /* Bulk endpoint type */
    0x00,0x02,                      /* Max packet size = 512 bytes */
    0x00,

    /* Endpoint descriptor for consumer EP */
    0x07,                           /* Descriptor size */
    CY_U3P_USB_ENDPNT_DESCR,        /* Endpoint descriptor type */
    C_DFRAME_EP6IN,              /* Endpoint address and description */
    CY_U3P_USB_EP_BULK,             /* Bulk endpoint type */
    0x00,0x02,                      /* Max packet size = 512 bytes */
    0x00                            /* Servicing interval for data transfers : 0 for bulk */
};

/* Standard full speed configuration descriptor */
const uint8_t CyFxUSBFSConfigDscr[] __attribute__ ((aligned (32))) =
{
    /* Configuration descriptor */
    0x09,                           /* Descriptor size */
    CY_U3P_USB_CONFIG_DESCR,        /* Configuration descriptor type */
    0x27,0x00,                      /* Length of this descriptor and all sub descriptors */
    0x01,                           /* Number of interfaces */
    0x01,                           /* Configuration number */
    0x00,                           /* COnfiguration string index */
    0x80,                           /* Config characteristics - bus powered */
    0x64,                           /* Max power consumption of device (in 2mA unit) : 200mA */

    /* Interface descriptor */
    0x09,                           /* Descriptor size */
    CY_U3P_USB_INTRFC_DESCR,        /* Interface descriptor type */
    0x00,                           /* Interface number */
    0x00,                           /* Alternate setting number */
    0x03,                           /* Number of endpoints */
    0xFF,                           /* Interface class */
    0x00,                           /* Interface sub class */
    0x00,                           /* Interface protocol code */
    0x00,                           /* Interface descriptor string index */

    /* Endpoint descriptor for producer EP P_DCONFIG_EP2OUT */
    0x07,                           /* Descriptor size */
    CY_U3P_USB_ENDPNT_DESCR,        /* Endpoint descriptor type */
    P_DCONFIG_EP2OUT,              /* Endpoint address and description */
    CY_U3P_USB_EP_BULK,             /* Bulk endpoint type */
    0x40,0x00,                      /* Max packet size = 64 bytes */
    0x00,                           /* Servicing interval for data transfers : 0 for bulk */

    /* Endpoint descriptor for producer EP P_DGENERATOR_EP4OUT */
    0x07,                           /* Descriptor size */
    CY_U3P_USB_ENDPNT_DESCR,        /* Endpoint descriptor type */
    P_DGENERATOR_EP4OUT,              /* Endpoint address and description */
    CY_U3P_USB_EP_BULK,             /* Bulk endpoint type */
    0x40,0x00,                      /* Max packet size = 64 bytes */
    0x00,

    /* Endpoint descriptor for consumer EP */
    0x07,                           /* Descriptor size */
    CY_U3P_USB_ENDPNT_DESCR,        /* Endpoint descriptor type */
    C_DFRAME_EP6IN,              /* Endpoint address and description */
    CY_U3P_USB_EP_BULK,             /* Bulk endpoint type */
    0x40,0x00,                      /* Max packet size = 64 bytes */
    0x00                            /* Servicing interval for data transfers : 0 for bulk */
};

/* Standard language ID string descriptor */
const uint8_t CyFxUSBStringLangIDDscr[] __attribute__ ((aligned (32))) =
{
    0x04,                           /* Descriptor size */
    CY_U3P_USB_STRING_DESCR,        /* Device descriptor type */
    0x09,0x04                       /* Language ID supported */
};

/* Standard manufacturer string descriptor */
const uint8_t CyFxUSBManufactureDscr[] __attribute__ ((aligned (32))) =
{
    0x12,                           /* Descriptor size */
    CY_U3P_USB_STRING_DESCR,        /* Device descriptor type */
    'S',0x00,
    'c',0x00,
    'o',0x00,
    'p',0x00,
    'e',0x00,
    'F',0x00,
    'u',0x00,
    'n',0x00
};

/* Standard product string descriptor */
const uint8_t CyFxUSBProductDscr[] __attribute__ ((aligned (32))) =
{
    0x2C,                           /* Descriptor size */
    CY_U3P_USB_STRING_DESCR,        /* Device descriptor type */
    'S',0x00,
    'c',0x00,
    'o',0x00,
    'p',0x00,
    'e',0x00,
    'F',0x00,
    'u',0x00,
    'n',0x00,
    ' ',0x00,
    'O',0x00,
    's',0x00,
    'c',0x00,
    'i',0x00,
    'l',0x00,
    'l',0x00,
    'o',0x00,
    's',0x00,
    'c',0x00,
    'o',0x00,
    'p',0x00,
    'e',0x00
};

/* Serial number string descriptor */

const uint8_t CyFxUSBSerialNumDesc[] __attribute__ ((aligned (32))) =
{
    0x22,                           /* Descriptor size */
    CY_U3P_USB_STRING_DESCR,        /* Device descriptor type */
    '0',0x00,'0',0x00,'0',0x00,'0',0x00,
    '0',0x00,'0',0x00,'0',0x00,'0',0x00,
    '0',0x00,'0',0x00,'0',0x00,'0',0x00,
    '0',0x00,'0',0x00,'0',0x00,'0',0x00,
};

/* Microsoft OS Descriptor. */
const uint8_t CyFxUsbOSDscr[] __attribute__ ((aligned (32))) =
{
    0x12,                           /* bLength: Length of the descriptor */
    CY_U3P_USB_STRING_DESCR,        /* bDescriptorType: Descriptor type */
    'M',0x00,                       /* qwSignature: Signature field */
    'S',0x00,
    'F',0x00,
    'T',0x00,
    '1',0x00,
    '0',0x00,
    '0',0x00,
    0xDD,                           /* bMS_VendorCode: Vendor code */
    0x00                            /* bPad: Pad field */
};

/* Extended Compat ID OS Feature Descriptor as per WinUSB requirement */
const uint8_t CyFxUsbExtCompatIdOSFeatureDscr[] __attribute__ ((aligned (32))) =
{
    // Header Section
    0x28,0x00,0x00,0x00,                     /* dwLength: 40 = 16 + 24 */
    0x00,0x01,                               /* bcdVersion: The descriptor’s version number */
    0x04,0x00,                               /* wIndex: Extended compat ID descriptor */
    0x01,                                    /* bCount: Number of function sections */
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,      /* RESERVED */
    // Function Sections
    0x00,                                    /* bFirstInterfaceNumber */
    0x01,                                    /* RESERVED */
    'W','I','N','U','S','B',0x00,0x00,       /* compatibleID */
    0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00, /* subCompatibleID */
    0x00,0x00,0x00,0x00,0x00,0x00            /* RESERVED */
};

/* Extended Properties OS Feature Descriptor as per WinUSB (USB 3.0) requirement */
const uint8_t CyFxUsbExtPropertiesOSFeatureDscr[] __attribute__ ((aligned (32))) =
{
    // Header Section
    0x8E,0x00,0x00,0x00,                     /* dwLength: 142 = 10 + 132 */
    0x00,0x01,                               /* bcdVersion: The descriptor’s version number */
    0x05,0x00,                               /* wIndex: Extended property OS descriptor */
    0x01,0x00,                               /* bCount: Number of properties */
    // Custom Property Section 1
    0x84,0x00,0x00,0x00,                     /* dwSize: 132 = 14 + 40 + 78 */
    0x01,0x00,0x00,0x00,                     /* dwPropertyDataType: A NULL-terminated Unicode String (REG_SZ) */
    0x28,0x00,                               /* wPropertyNameLength: 40 */
                                             /* bPropertyName: "DeviceInterfaceGUID" */
    'D',0x00,'e',0x00,'v',0x00,'i',0x00,'c',0x00,'e',0x00,
    'I',0x00,'n',0x00,'t',0x00,'e',0x00,'r',0x00,'f',0x00,'a',0x00,'c',0x00,'e',0x00,
    'G',0x00,'U',0x00,'I',0x00,'D',0x00,
    0x00,0x00,
    0x4E,0x00,0x00,0x00,                     /* dwPropertyDataLength: 78 */
    										 /* Select random GIUD */
                                             /* bPropertyData: "{5a6c1154-04c8-4998-9a3a-d953c87eaa35}" */
    '{',0x00,
    '5',0x00,'A',0x00,'6',0x00,'C',0x00,'1',0x00,'1',0x00,'5',0x00,'4',0x00,'-',0x00,
    '0',0x00,'4',0x00,'C',0x00,'8',0x00,'-',0x00,
    '4',0x00,'9',0x00,'9',0x00,'8',0x00,'-',0x00,
    '9',0x00,'A',0x00,'3',0x00,'A',0x00,'-',0x00,
    'D',0x00,'9',0x00,'5',0x00,'3',0x00,'C',0x00,'8',0x00,'7',0x00,'E',0x00,'A',0x00,'A',0x00,'3',0x00,'5',0x00,
    '}',0x00,
    0x00,0x00
};

/* Place this buffer as the last buffer so that no other variable / code shares
 * the same cache line. Do not add any other variables / arrays in this file.
 * This will lead to variables sharing the same cache line. */
const uint8_t CyFxUsbDscrAlignBuffer[32] __attribute__ ((aligned (32)));

/* [ ] */
