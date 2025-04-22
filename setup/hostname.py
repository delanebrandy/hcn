# Author: Delane Brandy
# Description: Hostname to IP address using socket

import socket
import sys

hostname = sys.argv[1]

try:
    ip = socket.gethostbyname(hostname)
    print(ip)
except socket.gaierror as e:
    print(e)
