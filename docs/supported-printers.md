# Printer compatibility matrix

No physical printer models have been validated by this scaffold yet.

| Model | Connection | Protocol | Input format | Result |
|---|---|---|---|---|
| HP LaserJet P1008 (0x03F0:0x4917) | USB OTG | XQX (ZjStream) + sihpP1006.dl firmware | PDF, DOCX, TXT, Images | Driver implemented & firmware bundled; awaiting user real-device print test |
| HP LaserJet P1006 (0x03F0:0x3E17) | USB OTG | XQX (ZjStream) + sihpP1006.dl firmware | PDF, DOCX, TXT, Images | Driver implemented & firmware bundled |
| HP LaserJet P1005 (0x03F0:0x3D17) | USB OTG | XQX (ZjStream) + sihpP1005.dl firmware | PDF, DOCX, TXT, Images | Driver implemented & firmware bundled |
| HP LaserJet P1007 (0x03F0:0x4817) | USB OTG | XQX (ZjStream) + sihpP1005.dl firmware | PDF, DOCX, TXT, Images | Driver implemented & firmware bundled |
| HP LaserJet M1005 MFP (0x03F0:0x3B17) | USB OTG | XQX (ZjStream) (onboard ROM firmware) | PDF, DOCX, TXT, Images | Driver implemented |
| HP LaserJet P1505 / P1505n | USB OTG | XQX (ZjStream) | PDF, DOCX, TXT, Images | Driver implemented |
| Brother HL-L2320D / HL-2200 series | USB OTG | Brother PJL / GDI (brlaser) | PDF, DOCX, TXT, Images | Driver implemented |
| ESC/POS Thermal Printers | USB OTG | ESC/POS (0x1D 0x76 0x30, 256-dot bands) | PDF, Images | Driver implemented |
| Standard PCL3 / PCL5 / PCL6 Printers | USB OTG | PCL Mode 2 (PackBits) | PDF, DOCX, Images | Driver implemented |
| Epson EcoTank & WorkForce (0x04B8) | USB OTG | Epson ESC/P-R (ESC . raster) | PDF, DOCX, TXT, Images | Driver implemented |
| Samsung ML / SCX / CLP / SL-M (0x04E8) | USB OTG | Samsung SPL / QPDL (0x1B 0x7E) | PDF, DOCX, TXT, Images | Driver implemented |
| TSPL Thermal Label Printers (Munbyn, TSC, Xprinter) | USB OTG | TSPL / TSPL2 (SIZE, BITMAP, PRINT) | PDF, Images | Driver implemented |
| IPP-over-USB Printers (Mopria, AirPrint) | USB OTG | PWG Raster (IEEE-ISTO 5102.4 RaS2) | PDF, DOCX, TXT, Images | Driver implemented |

Only mark a combination as confirmed physical hardware verified after successful real-device print tests.

