package main

import "core:net"
import "core:slice"
import "core:fmt"
import "core:strings"
import "odin-http/client"
import http "odin-http"
import "core:encoding/json"
import "core:crypto/ed25519"
import "core:encoding/hex"
import "core:os"

PUBLIC_API_KEY := os.get_env("PUBLIC_API_KEY")

main :: proc() {
    server : http.Server
    http.server_shutdown_on_interrupt(&server)
    router : http.Router
    http.router_init(&router)
    defer http.router_destroy(&router)
    http.route_post(&router, "/", http.handler(index))
    routed := http.router_handler(&router)
    http.listen_and_serve(&server, routed, net.Endpoint {
        address = net.IP4_Address{127, 0, 0, 1},
        port = 7777
    })
}
index :: proc(request: ^http.Request, response: ^http.Response) {
    timestamp := request.headers._kv["x-signature-timestamp"]
    signature := request.headers._kv["x-signature-ed25519"]
    http.headers_set(&response.headers, "signature", signature)
    http.headers_set(&response.headers, "timestamp", timestamp)
    http.body(request, -1, response, acknowledge)
}

PingBody :: struct {
    type: u8
}

acknowledge :: proc(response: rawptr, body: http.Body, err: http.Body_Error) {
    fmt.println(body)

    response := cast(^http.Response)response

    timestamp := http.headers_get(response.headers, "timestamp")
    signature := http.headers_get(response.headers, "signature")

    concatenated, _ := strings.concatenate({timestamp, body})
    decoded_signature, _ := hex.decode(transmute([]u8)signature)
    decoded_public_key, _ := hex.decode(transmute([]u8)PUBLIC_API_KEY)

    public_key : ed25519.Public_Key
    ed25519.public_key_set_bytes(&public_key, decoded_public_key)

    if !ed25519.verify(&public_key, transmute([]u8)concatenated, decoded_signature) {
        http.respond_with_status(response, http.Status.Unauthorized)
        return
    }

    if err != nil {
        http.respond(response, http.body_error_status(err))
        return
    }

    ping : PingBody
    marshal_err := json.unmarshal(transmute([]u8)body, &ping)
    if marshal_err != nil {
        http.respond_with_status(response, http.Status.Bad_Request)
        return
    }
    if ping.type == 0 {
        http.respond_with_status(response, http.Status.No_Content)
        return
    }
    http.respond_with_status(response, http.Status.Bad_Request)
}
