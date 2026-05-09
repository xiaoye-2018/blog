

| 协议               | 并发模型                           | 典型客户端/服务端限制（常见默认）                            |
| ------------------ | ---------------------------------- | ------------------------------------------------------------ |
| **HTTP/1.1**       | 多条 TCP 连接并行                  | **每主机 6**（Chrome 官方文档）；Firefox 也长期默认 6（可调隐藏项）。([IETF Datatracker](https://datatracker.ietf.org/doc/html/rfc2616?utm_source=chatgpt.com), [kb.mozillazine.org](https://kb.mozillazine.org/Network.http.max-persistent-connections-per-server?utm_source=chatgpt.com)) |
| **HTTP/2**         | 单连接内多路复用（并发**流**）     | 规范**建议 ≥100 流**；Apache **100**、Nginx **128** 默认；部分客户端存在**\~256** 保护上限的社区报告。([IETF HTTP Working Group](https://httpwg.org/specs/rfc7540.html), [httpd.apache.org](https://httpd.apache.org/docs/current/mod/mod_http2.html?utm_source=chatgpt.com), [nginx.org](https://nginx.org/en/docs/http/ngx_http_v2_module.html?utm_source=chatgpt.com), [谷歌群组](https://groups.google.com/a/chromium.org/g/chromium-discuss/c/I9eB4ajAXIw?utm_source=chatgpt.com)) |
| **HTTP/3（QUIC）** | 单连接内多路复用（并发**双向流**） | 规范/实现普遍**建议 ≥100 流**；H2O 等服务器默认 **100**。([GitHub](https://github.com/dotnet/runtime/issues/51775?utm_source=chatgpt.com), [h2o.examp1e.net](https://h2o.examp1e.net/configure/http3_directives.html?utm_source=chatgpt.com)) |



## HTTP 1.0

每一个 HTTP 请求都由它自己独立的连接完成；这意味着发起每一个 HTTP 请求之前都会有一次 TCP 握手，而且是连续不断的。

## HTTP 1.1

支持长连接、流水线处理。在一个TCP连接上可以传送多个HTTP请求和响应，减少了建立和关闭连接的消耗和延迟，在HTTP1.1中默认开启Connection： keep-alive，一定程度上弥补了HTTP1.0每次请求都要创建连接的缺点。



存在**队头阻塞**问题： pipeline 为若干请求排队单线程处理，其中的某个请求超时，后续请求只能被阻塞。 因此现代浏览器默认并没有使用该功能



## HTTP 2

基于二进制格式、多路复用、header压缩、服务端推送。



多个请求可同时在**一个连接**上并行执行（由于支持二进制的格式，可以无序）某个请求任务耗时严重，不会影响到其它连接的正常执行







### Springboot 配置HTTP 2

所有主流的浏览器都不支持明文HTTP/2 (h2c)

```shell
# -I : 只显示header
# -v：
# --trace http2_trace.log：  日志
curl --http2-prior-knowledge -I https://localhost:8080/test

# 专业诊断工具
sudo apt install nghttp2-client

nghttp -v http://192.168.31.16:8080/test
```



## **HTTP/3（QUIC）**