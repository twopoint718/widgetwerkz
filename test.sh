#!/usr/bin/expect -f
set timeout -1
spawn curl -XPOST -H "Content-Type: application/json" -d "{\"email\":\"cwilson@8thlight.com\",\"password\":\"my_password\"}" http://widgetwerkz.development/rpc/signup
expect "{\"msg\" : \"ok\"}"
