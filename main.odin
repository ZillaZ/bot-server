package main

import "core:net"
import "core:slice"
import "core:fmt"
import "core:strings"
import "odin-http/client"
import http "odin-http"
import "core:encoding/json"

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
    fmt.println(request.headers)
    http.body(request, -1, response, acknowledge)
}

PingBody :: struct {
    type: u8
}

acknowledge :: proc(response: rawptr, body: http.Body, err: http.Body_Error) {
    fmt.println(body)
    response := cast(^http.Response)response
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

make_request :: proc(url: string, headers: ^http.Headers) -> (string, bool) {
    request: client.Request
    client.request_init(&request)
    request.headers = headers^
        response, err := client.request(&request, url)
    if err != nil {
        return "Internal Server Error", false
    }

    if !http.status_is_success(response.status) {
        fmt.println("failed")
        return http.status_string(response.status), false
    }
    fmt.println(http.status_string(response.status))
    type, _, e := client.response_body(&response)
    if e != nil {
        return "Internal server error while reading response body", false
    }
    return type.(client.Body_Plain), true
}
