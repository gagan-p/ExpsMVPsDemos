blockdiag { 
group{
orientation = portrait
AppGW -> Redis
}
group{
orientation = portrait
RTSP -> RTSP_DB
}
group{
orientation = portrait
TokenServer -> TOMAS_DB
}
AppGW -> RTSP -> TokenServer
DTSP -> AppGW
NPCI_Switch -> RTSP
UPI -> RTSP
RTSP -> BIG
BIG -> CBS_EIS
SMS_GW -> BIG
WebServer -> AppGW
MobileApp -> WebServer
MerchantPortal -> WebServer
AdminPortal -> WebServer
UPI -> WebServer
}
