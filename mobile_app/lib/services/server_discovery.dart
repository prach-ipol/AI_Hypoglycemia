// Finds the Glucose Companion backend on the local network so a physical
// phone works without hard-coding the PC's (frequently changing) IP.
//
// Native platforms scan the phone's Wi-Fi subnet; web returns null because
// browsers cannot open raw sockets (and web uses the page's own host anyway).
export 'server_discovery_stub.dart'
    if (dart.library.io) 'server_discovery_io.dart';
