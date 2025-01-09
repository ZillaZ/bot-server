package main

import "core:net"
import "core:slice"
import "core:fmt"
import "core:strings"
import "odin-http/client"
import http "odin-http"

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
    port = 2469
  })
}

index :: proc(request: ^http.Request, response: ^http.Response) {
  http.body(request, -1, response, download_files)
}

download_files :: proc(response: rawptr, body: http.Body, err: http.Body_Error) {
  response := cast(^http.Response)response
  if err != nil {
    http.respond(response, http.body_error_status(err))
  }
  line_count := strings.count(body, "\n")
  req_headers: http.Headers
  http.headers_init(&req_headers)
  for header in strings.split(body, "\n") {
    if header == "Url:" {break};
    index := strings.index(header, ":")
    key, _ := strings.substring(header, 0, index)
    value, _ := strings.substring(header, index+1, len(header))
    req_headers._kv[key] = value
  }
  data, ok := make_request(slice.last(strings.split_lines(body)), &req_headers)
  headers: http.Headers
  http.headers_init(&headers)
  headers._kv["Access-Control-Allow-Origin"] = "*"
  headers._kv["Access-Control-Allow-Methods"] = "*"
  response.headers = headers
  if ok {
    response.status = http.Status.OK
    http.respond_file_content(response, "file.ts", transmute([]u8)data)
  }else{
    http.respond_with_status(response, http.Status.Bad_Request)
  }
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
