#!/usr/bin/env python3
"""
Virtual IPP Printer for BurePrint Testing
==========================================
Simulates an RFC 8010/8011 compliant IPP/IPPS network printer.
Accepts Get-Printer-Attributes queries, handles Print-Job submissions,
and dumps the received printed document to a local PDF file.

Usage:
    python3 tool/virtual_ipp_printer.py [PORT]
    Default port: 8631 (Use 631 with sudo if preferred)
"""

import sys
import os
import time
from http.server import HTTPServer, BaseHTTPRequestHandler

DEFAULT_PORT = 8631

def build_ipp_attribute(tag: int, name: str, value: bytes) -> bytes:
    name_bytes = name.encode("utf-8")
    return (
        bytes([tag])
        + len(name_bytes).to_bytes(2, "big")
        + name_bytes
        + len(value).to_bytes(2, "big")
        + value
    )

def build_attributes_response(request_id: int) -> bytes:
    """Builds a Get-Printer-Attributes IPP 1.1 successful-ok response."""
    res = bytearray()
    res += b"\x01\x01"  # IPP version 1.1
    res += b"\x00\x00"  # status-code: successful-ok
    res += request_id.to_bytes(4, "big")

    # Group 1: Operation attributes
    res += b"\x01"  # operation-attributes-tag
    res += build_ipp_attribute(0x47, "attributes-charset", b"utf-8")
    res += build_ipp_attribute(0x48, "attributes-natural-language", b"en")

    # Group 2: Printer attributes
    res += b"\x04"  # printer-attributes-tag
    res += build_ipp_attribute(0x42, "printer-name", b"Virtual Wi-Fi IPP Printer")
    res += build_ipp_attribute(0x42, "printer-make-and-model", b"BurePrint Test DeskJet 9000")
    res += build_ipp_attribute(0x23, "printer-state", b"\x03")  # 3 = idle
    res += build_ipp_attribute(0x21, "operations-supported", b"\x00\x02")  # 2 = Print-Job
    res += build_ipp_attribute(0x49, "document-format-supported", b"application/pdf")
    res += build_ipp_attribute(0x44, "document-format-supported", b"image/pwg-raster")
    res += build_ipp_attribute(0x44, "media-supported", b"iso_a4_210x297mm")

    # Marker supplies (Toner/Ink)
    res += build_ipp_attribute(0x42, "marker-names", b"Black Toner")
    res += build_ipp_attribute(0x21, "marker-levels", (85).to_bytes(4, "big"))
    res += build_ipp_attribute(0x44, "marker-colors", b"#000000")

    # End of attributes
    res += b"\x03"
    return bytes(res)

def build_job_response(request_id: int, job_id: int = 1) -> bytes:
    """Builds a Print-Job IPP 1.1 successful-ok response."""
    res = bytearray()
    res += b"\x01\x01"
    res += b"\x00\x00"  # successful-ok
    res += request_id.to_bytes(4, "big")

    # Operation attributes
    res += b"\x01"
    res += build_ipp_attribute(0x47, "attributes-charset", b"utf-8")
    res += build_ipp_attribute(0x48, "attributes-natural-language", b"en")

    # Job attributes
    res += b"\x02"  # job-attributes-tag
    res += build_ipp_attribute(0x21, "job-id", job_id.to_bytes(4, "big"))
    res += build_ipp_attribute(0x23, "job-state", b"\x09")  # 9 = completed

    res += b"\x03"  # End of attributes
    return bytes(res)

class IPPRequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # Clean custom logging
        pass

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        if len(body) < 8:
            self.send_error(400, "Malformed IPP header")
            return

        version = f"{body[0]}.{body[1]}"
        op_or_status = int.from_bytes(body[2:4], "big")
        request_id = int.from_bytes(body[4:8], "big")

        print(f"\n[+] Incoming IPP Connection on {self.path}")
        print(f"    Version: {version} | Op ID: 0x{op_or_status:04X} | Req ID: {request_id}")

        if op_or_status == 0x000B:  # Get-Printer-Attributes
            print("    -> Responding to Get-Printer-Attributes (Status: idle, Supplies: Black Toner 85%)")
            response = build_attributes_response(request_id)
        elif op_or_status in (0x0002, 0x0005, 0x0006):  # Print-Job, Create-Job, Send-Document
            print(f"    -> Print Job Received! Payload total size: {len(body)} bytes")

            # Extract document payload following 0x03 (end-of-attributes-tag)
            end_tag_pos = body.find(b"\x03", 8)
            doc_data = b""
            if end_tag_pos != -1:
                doc_data = body[end_tag_pos + 1 :]

            timestamp = int(time.time())
            filename = f"received_print_job_{timestamp}.pdf"
            if len(doc_data) > 0:
                with open(filename, "wb") as f:
                    f.write(doc_data)
                print(f"    -> SUCCESS: Extracted document data ({len(doc_data)} bytes)")
                print(f"    -> Saved document to: ./{filename}")
            else:
                print("    -> (Document bytes sent in separate chunk or empty)")

            response = build_job_response(request_id, job_id=timestamp % 1000)
        else:
            print(f"    -> Acknowledging generic IPP operation 0x{op_or_status:04X}")
            response = build_job_response(request_id)

        self.send_response(200)
        self.send_header("Content-Type", "application/ipp")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

def main():
    import subprocess
    port = DEFAULT_PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port: {sys.argv[1]}")
            sys.exit(1)

    avahi_proc = None
    try:
        avahi_cmd = [
            "avahi-publish",
            "-s",
            "Virtual Wi-Fi IPP Printer",
            "_ipp._tcp",
            str(port),
            "rp=ipp/print",
            "ty=BurePrint Test DeskJet 9000",
            "pdl=application/pdf",
        ]
        avahi_proc = subprocess.Popen(
            avahi_cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        print(f"[*] Broadcasted mDNS service via avahi-publish (_ipp._tcp port {port})")
    except Exception as e:
        print(f"[!] mDNS broadcast not started: {e}")

    server = HTTPServer(("0.0.0.0", port), IPPRequestHandler)
    print("=" * 64)
    print(f"   BurePrint Virtual IPP Wi-Fi Printer Server")
    print("=" * 64)
    print(f"[*] Server running on all interfaces at port {port}")
    print(f"[*] PC IP for BurePrint: 10.174.137.245")
    print(f"[*] Testing Instructions:")
    print(f"    1. Open BurePrint on your phone.")
    print(f"    2. In 'Printers', tap 'Scan' or '+' (Add by IP/Host):")
    print(f"         Host: 10.174.137.245")
    print(f"         Port: {port}")
    print(f"         Queue Path: /ipp/print")
    print(f"         Security: Plain IPP")
    print(f"    3. Go to 'Documents' -> Tap 'Print Settings'.")
    print(f"    4. Select the printer -> Tap 'Print Now'.")
    print("=" * 64)
    print("[*] Waiting for incoming print jobs... (Press Ctrl+C to stop)\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Stopping Virtual IPP Printer server.")
        server.server_close()
    finally:
        if avahi_proc:
            avahi_proc.terminate()

if __name__ == "__main__":
    main()
