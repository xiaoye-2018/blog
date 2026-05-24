---
theme: condensed-night-purple
---
已发布掘金：
https://juejin.cn/post/7426916970661232650#heading-21

## Tomcat 网络实现分析

> 网络请求流程图解：<br>
> <https://www.processon.com/view/link/68b7aea13d4ce166652fba82?cid=62edd83e0791292e9d3652ad>

### 核心类

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/e79b844d034945e8a2b8ecf3b5d82fbb~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=zT85duT47y6pwJpPBVGWGMWJJrQ%3D)

### 网络模型

springboot 中的内嵌tomcat 默认采用Nio模式， 具体实现：NioEndpoint， Nio2Endpoint 为异步IO的实现。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/6dc78f47948a4a19855ad1d25fd7b918~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=%2BUCGJJ0xWDa68yz4Iaz6Xl6A2PU%3D)

Nio 网络核心代码：

org.apache.tomcat.util.net.NioEndpoint#startInternal

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/cb016a31f60b4aa0886ba2f37c8937a1~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=IKPVjyC7raBhuUwEok%2FjeKrY%2FnQ%3D)

首先会创建一个线程池，用来处理网络请求任务，该线程池不同于JDK默认线程池。

核心 --> 最大线程 ---> 队列（无界）

然后创建一个acceptor 线程用来接受网络连接事件，一个poller 线程用来处理 read、write事件

acceptor中的ServerSocketChannel 对象初始化：

org.apache.tomcat.util.net.NioEndpoint#initServerSocket：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/add54461fa5e40e4bde555da07c7f299~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=xojnS2%2B79N6SMRCgzUsMs6zme9A%3D)

这里设置为阻塞模式， 不需要使用Selector来监听，因为tomcat中主要还是IO吧，连接数不会太多。

（而Netty默认为非阻塞模式，会注册到一个selector上，为了支持多个ServerSocketChannel对象同时监听连接事件）

当acceptor 接受到一个连接时，会将连接对象包装为一个NioSocketWrapper对象 注册到poller的**events**中

poller：

这里有一个events() 方法，会遍历events 数组，如果是register类型，会注册该连接对象到Selector中，同时绑定READ事件

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/b37a8f16bf7c4441b9f234bc2405dc0a~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=mkLZ0DWc1kachD%2F98MLaHtF0yf8%3D)

处理事件时，将会创建SocketProcessorBase 任务， 提交到线程池执行。

总结： NioEndpoint采用 一个线程处理accept， 一个线程处理Selector上的read、write事件。当read、write事件发生时，交给线程池进行处理。

#### NIO事件转换：

基本HTTP 请求 事件处理如下：

      客户端连接建立
            ↓
        OP_ACCEPT (accept 新连接，添加任务到events)
            ↓
        OP_READ (遍历 events，将其注册OP_READ)
            ↓
        开始处理OP_READ事件 (Poller#run --> processKey)
            ↓
      处理事件开始 (processKey： unreg(), 取消 所有事件: 即之前的OP_READ )
            ↓
       业务逻辑处理 (ConnectionHandler#process)
            ↓
        处理完毕( 上面正常返回OPEN状态(异步也是)，执行registerReadInterest，从新向events注册OP_READ的EVENT对象)
            ↓
      Poller继续监听事件

### 网络请求流程跟踪

当浏览器发起一个URL请求时，tomcat 是如何一步一步进入到Servlet 中的？

整理流程图如下：\
![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/f65770afe949464ab241a647fc53bdab~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=P9oEaw0p2c2cgrD54RHulQnqNdI%3D)

首先发起连接后，poller 会监听到相关read事件。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/c0e692d7fcc147dba9849e5e4f7be92c~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=ffVCV75cuV%2BiB3bUuOUqMCDt%2FoE%3D)

首先取消感兴趣的事件。防止干扰其他线程socket

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/82c34f1b3a424eef93e00f36eead5943~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=KPpPvAbLixo9B2T2VQdJQBmZZhE%3D)

这里提交SocketProcessorBase对象，即一个任务。包含了当前channel attach的NioSocketWrapper对象信息

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/d05d1f4cd49e4102bbe8110ca2f47e55~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=XYHHBT%2F6EX9yntNb71CRJ0fun3U%3D)

#### Poller#timeout

poller线程在处理事件时，会执行timeout 检查是否有超时的事件。

注意： 在任务处理前，会将相关的事件取消掉，完成后会重新注册相关事件。因此在任务执行过程中，是不会检查超时的。（异步任务检查除外）

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/234f03aa91ea48d2bb29798d58572b61~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=cigu8IwV5DlOwuaIQ50%2BFRrxt8M%3D)

**超时时间更新：**

这里有一个keptAlive参数：首次进来为false，当解析出一个完成的HTTP请求后，执行业务结束后，会赋值为true，在第二次调用parseRequestLine时没有读取到任务数据时，就会将timeout 的事件设置为keepAliveTimeout，即该连接维持的最长时间。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/923c32bd5a404dd9b80fcf5488b4deb9~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=IQIGd30lKE2IneLL9FkWXB0m8jo%3D)

org.apache.coyote.http11.Http11InputBuffer#parseRequestLine

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/799fb9a83a7f4e18abdc7bddd8241ad2~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=6uY5AUEw0kgCUqa16TaVxJQo790%3D)

#### 线程池执行doRun：

getHandler： 即NioEndpoint对象初始化时创建的ConnnectionHandler：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/9b149cc588a5437a9ce9dd288e653f22~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=SZAMImSeDlzegf8j5zMdwvPbzeQ%3D)

创建Http11Processor， 执行process

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/651a5b95ed7145b98078cec5f7d2d81e~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=qxFcPlCLZ4KMA7hwaRv76ZLx87s%3D)

当上面正常执行结束后，会返回OPEN，会重新向poller 注册事件，用于检查超时。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/288c36cd809e43038c908840ddd50731~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=nwwQVX3nrrvDjhJW%2FMCdgA6psj4%3D)

Http11Processor extends AbstractProcessorLight：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/920982b55ad54761b944a78f16bf4612~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=ZcHiv1ArSnaGzaYrsf4HKulI8L0%3D)

#### Http11Processor#service方法：

1.  首先会解析 request header
2.  调用CoyoteAdapter#service\
    这里的while 通常会执行两次，第一次解析出一个完整的对象后，会向下传递最终执行Servlet。执行完毕后这里会继续尝试解析，如果没有数据后才会退出该while。

<!---->

1.  1.  parseRequestLine 这里会设置超时参数，用于**poller**检查连接超时。\
        ![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/39f8b0c8d83c493ca3dbef5aa579e012~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=BY58%2FT10hzBS9UtGvgDtNwdcEig%3D)

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/cd3041ac5dc341c8966ab25e4731de34~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=XlD62iBuoJnXMuIxbRsinLzH9PE%3D)

getContainer： 当前为 Engine对象， Engine 中pipeline默认只有一个basic的

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/ff48a85eecc84c11b476451dea083019~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=9TJzYeIyZf2PXR%2BoEs%2F4rYvzFhA%3D)

engine中继续获取host执行：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/ad3ec2fd632543f9ba0d5ac07d680838~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=w3oQ1j2FPUz1Dm%2F3Py5tpcozqT0%3D)

执行Context pipeline：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/cf12d3b87f3c43abacb2a732c3f9005f~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=Sq2o3yV12WZNppbDQQGnxmqQ9pc%3D)

ContextValve

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/7f3034846a7647499c3e3404c495102f~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=3q72HgfLGhRHn64r%2F%2FO4mORiGpk%3D)

#### **Servlet入口核心类：**

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/99c099d19cdb4a0fb767264ab1aecba6~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=JpqFCLIJ8syv98yUz%2Be5LBA2VDs%3D)

分配Servlet对象

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/0d5bc80b0ee649c095296869d9d468a7~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=cHoVJZPR%2FKWZpt%2Fq1UYIXHeXju8%3D)

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/9f9b85cb02b345f1a23d87e85b7b0693~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=HL5gYV8u3qzJzPrLPgYpKmBlH0c%3D)

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/c466b516e1004a0fa605ddb279359db0~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=PrqVY34uZ89umKCI%2F%2BEznJL1rpw%3D)

过滤出满足当前URL的filter：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/fd1c889157b74f809f7bc98c8e1fd6c6~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=HOVYD2WHr0GfLgMqYGuBg7kIucU%3D)

执行filter链

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/347fc22e61704a168c6b54d8be8741f5~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=%2BLw6QQ6FiV02A5E%2BXW4E75711WY%3D)

doFilter：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/2c3adb151f4d41dc9decca6fb6157288~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=bfJCJA0LnPHz6jMC%2FEafDtH1cN4%3D)

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/545cbf11793a4d5b91fc8beb7cbe6bfc~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=Dr16WDQaDrYIwfuvZP3Vfe1KlsE%3D)

filter 执行完后，执行service方法：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/5b6d47eee94e45e0be967818b6ef0b86~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=OlO54ISb9AyS1qFEOpFFzS5LXko%3D)

### Servlet异步分析

通常使用如下：

可以手动调用AsyncContext#setTimeout设置异步超时时间。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/e5858814c09b4782aec90d8d3bd49c8c~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=8uQCy6M3Ytvfll%2FH64Vk4RO1O%2BY%3D)

异步上下文使用状态机进行管理状态信息（AsyncStateMachine），整体状态流转: DISPATCHED 为AsyncStateMachine对象默认状态

\--> STARTING --> STARTED --> COMPLETING --> DISPATCHED

如果没有调用complete方法(Spring 返回callable)， 状态可能为：STARTED --> DISPATCHING --> DISPATCHED

1.  startAsync() 方法 将当前request对象开启异步支持\
    Request#startAsync: 会创建AsyncContext对象用来管理异步上下文信息， startAsync() 方法执行结束后为STARTING![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/a5164e31a20c41edba82eb414229d10c~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=9%2FtUdHjTtwyy3VY%2Bz3IoBU5lx4o%3D)

<!---->

2.  当Controller中返回后，最终执行下面逻辑。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/d7deef2d068f45c4baf41a4aa406c6f8~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=0uyOAx2yNZ8YXSheO%2B2ws3jugdo%3D)继续返回：\
![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/61b6575d65954e6c879f5accf4b41c8c~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=8BdkJkrXxV0TFmQdTJOGOBibfVw%3D)

异步将会返回LONG：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/04b202a1185948fa8a97039a92f4c5c2~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=uOhmpmEyDBXJj56Et7jXpwefUeg%3D)

3.  这里会修改状态为STARTED![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/ff615b8855ef4e35b4e233a54e42e966~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=21%2BaKaT707z0d3njjK0mjl5pvzs%3D)

对于异步这里会将processor加入到 等待线程池队列，Http11Processor 包含了SocketWrapperBase 任务对象![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/b6f7fc1275b4459b8068e295a6c045fc~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=SZRKRHye8jg8k0vyyIHVDo5lGoI%3D)

#### 异步超时检测

processors 最终在这里处理，没1s中检查一次是否超时， 默认30s ，Connector#asyncTimeout，如果超时将会发布timeout事件到线程池， 会自动关闭异步上下文对象，同时执行AsyncContext对象中的listener。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/3b926980c1c24bb2a7236b252c097d61~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=3QExqcgdpzeVsSqnHnjJJMQDX%2F4%3D)

4.  调用complete() 方法会修改状态为 COMPLETING ， 这里会发布事件任务到线程池（并不是poller 监听的读写事件）

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/a639b38176f846d2a7ae341ab9f7ff87~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=OxPwbPqEe7PaqC4n2OOfz6clVho%3D)

5.  由于上面发布了read 事件任务到线程池， 线程池执行该任务最终到：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/96462598d4d24d7bbcf069d92cefe735~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=5wniQL8oBAafMc1qTPFwfAG9LL8%3D)

如果没有执行Complete方法，在执行到AbstractProcessorLight#process时：

1.  首先status为OPEN\_READ， 会往Servlet 流程执行
2.  下面逻辑是一个while ， 异步在后面会更新status，下一次进入下面红框的逻辑。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/75513f29325b4140abead39a03303a3c~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=jkbFt2ZYS%2BuxbSC7wJ5Omy0WfVY%3D)

上面while 为true，继续循环， 将会执行到下面ASYNC\_END 条件成立分支：这里有两个方法

*   dispatch：如果request 处于 dispatching 状态，会继续向Servlet 调用。Spring MVC 中返回callable。

<!---->

*   *   dispatch 里面也可能会触发执行asyncContext对象 listener

<!---->

*   ![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/8229b1d6311241838f5bd94669e305eb~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=1v9P1lKvGK%2BQSQK%2BwoTXYkXeOpw%3D)
*   checkForPipelinedData：检查channel是否还有数据没有读取完 **。** 可能会抛出异常。正常情况返回OPEN，异常则为CLOSE。 这里有一个keptAlive参数，会修改超时时间。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/9bb1791288e24403b16432203a23cf5d~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=zyDmO3xvWnXI7id1aunZwG7Zp%2BU%3D)

debug时由于超时，socket关闭，因此返回-1，没有数据返回0，不会抛出异常

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/2346597d199d4e7b881d2235ee1d0a58~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=kV3S3kVPoul2197gPggWYi6Z0Yg%3D)

正常情况下，上面返回0。返回到checkForPipelinedData，最终为OPEN 或 CLOSE（连接被关闭）， while循环结束，线程结束。

**总结：**

当开启异步上下文，从Servlet返回后，tomcat线程会向注册一个事件到waitingProcessors中。退出tomcat线程

内部线程（catalina 线程）会遍历waitingProcessors，检查是否达到异步超时时间，达到则会向**线程池** 注册一个timeout的event。使tomcat线程 关闭异步上下文

在asynContext调用complete时，会**重新发布READ事件任务**到tomcat线程池 继续处理异步上下文的剩余过程。

#### 连接关闭

自动检测到连接对象超时：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/30a0d96467bb4bb8a0b4dc7f848cd4a1~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=LzT%2Fjo8IuhFdysQfr5Y8zT8nZJM%3D)

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/eeba4687296e4eb393a308b9fd04fd7e~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=vlTrLMo60uWuz5kwcuVstzb8wHM%3D)

上面返回CLOSE后，关闭相关的selectionKey

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/30005388c9ab4806b7ce5b80c2c811cb~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=qiSSP1DSjZgDrTEO2UjvyaxpxOk%3D)

### Spring MVC 中的异步

这里使用callable 作为返回值进行分析： WebAsyncTask、CompletableFuture、DeferredResult 类似

异步上下文不同于上面Servlet的使用：状态为：STARTED --> DISPATCHING --> DISPATCHED

这里不会调用Complete。

执行controller后在这里处理返回值：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/0230f8d88c0d4b2799c6323c5c354f16~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=r1d%2Bc9xGHtJQRKklqiItf8jlhmY%3D)

这里会根据返回值类型来选择对应的处理器：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/b8b26980b6f948e684d410651d31d986~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=Y78uk%2FaRDwklkk2%2B0koOVku8Jko%3D)

选择适合的处理器

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/51f4612bc00c4f2a9bf7126876deb1f8~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=Qio6%2BlcWhXkkwbLwDKX2m4%2BuRNQ%3D)

返回值为callable时：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/888f7a82eea14d7880ec306082b1f44d~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=Rw6008tZc4ySj5G6%2BcDj6hpw%2Bao%3D)

**startCallableProcessing：开启异步上下文，同时将任务扔给线程池**

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/8764e562801a433b981b4db443848fdb~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=gcxy3naa6302qOQ9OJ%2FG6to3s8A%3D)

上图中间执行startAsyncProcessing方法， 最终会执行startAsync方法开启异步：

需要注意这里还有一个addListener(): 会向tomcat 注册监听器， 当异步对象超时，异常，tomcat 会进行回调。超时默认值也在这里处理的。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/0d00fc9c0c3e42da99c7ce7ecb6a6d2b~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=e1GVAOOtEAaTQM2VlTc2i5aEs0g%3D)

在callable任务执行完毕后，会执行setConcurrentResultAndDispatch方法会将值set到WebAsyncManager# concurrentResult 中， tomcat 下一次事件发生了 可以直接获取该值。

同时会执行asyncContext.dispatch()， 使AsyncContext状态变为DISPATCHING，同时发布OPEN\_READ事件任务给tomcat线程，让其下一次获取执行结果返回。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/6bde61e7900842b48e4911f8e52243e4~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=x8fanVPws9O3VcKXOXz3GKbsgYk%3D)

action

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/88d8c8be31844d3c9efca42813798c57~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=wJ1DbelaZE3q6USINO3m8Y4Vl5k%3D)

上面提到的发布OPEN\_READ事件任务，tomcat 线程在AbstractProcessorLight#process 的while 中调用dispatch() 最终就会执行到这里，进而走向Servlet。 对于前面提到的使用Servlet原生异步来开启，再次执行Servlet并不是这里的入口。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/d0097b4c1b4040da9e3cb2df8a9beaac~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=bAvHSgEvnWQfviQLnl57HinvlrI%3D)

上面提到使用callable作为返回值的时候，会调用两次Servlet。 因此Filter 也就会执行多次，因此Spring 中出现了OncePerRequestFilter 类，可以用来控制同一个请求是否需要多次执行filter逻辑

### tomcat常用配置参数

    server:
      tomcat:
        # 能接受的最大连接数， 超过则使用backlog,  
        # 也就是最多处理 max-connections + accept-count 个
        max-connections: 10     # accept所能接受的最大数量（默认 8192）
        accept-count: 2         # OS backlog， 系统队列。（默认100）
        # IO 线程池配置
        threads:
          max: 2       # 最大工作线程（默认200）
          min-spare: 1  # 最小工作线程（默认10）
        connection-timeout: 3s  # socket 超时，即三次握手后，到发送数据的等待时间（如何模拟）。tomcat初始化会设置默认60s.
        keep-alive-timeout: 50s # 有keep-alive(貌似不是HTTP的keep-alive)， 则使用该参数作为 连接超时. 同时会返回给客户端

    spring:
      mvc:
        async:
          request-timeout: 20s    # 返回callable、DeferredResult 时作为超时时间

### tomcat相关线程

Acceptor：接受accept连接请求

Poller： 监听连接对象是否发生事件 (Selector)

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/0ef5fd3ce9e940a995a8939b6b79a9df~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=yihV9cJNvC81DZs1iVM9muuzJ4k%3D)

**IO线程池：**

处理IO 事件线程池：

默认，min：10， max：200

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/82ac37271dde469fadba1ebe1c915383~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=hejSZBy9IRn83BXV9KGAt5BcvcU%3D)

**Catalina线程池：**\
内部监听等待超时的任务：比如Servlet异步的超时检查。

AbstractProtocol#waitingProcessors

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/94f71fd42ec243f28ce35f215ad184a4~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=7n5EQJbeXoy8jpT9%2ByEQj0aajXo%3D)

### 网络相关错误

在tomcat 中，如果在执行Controller 发生IO 异常，大多都会被tomcat内部捕获，且默认只输出debug日志。SpringMVC 将不会捕获到该异常（即全局异常处理器无法捕获）。

#### EOFException

java.io.EOFException

当对端连接关闭后，这里再次解析时，内部会抛出EOFException。 正常情况下，这里的while 只有在无法继续解析HTTP对象的时候才会退出。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/62416909edf04a39bd311694539bd716~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=ZxJYsatB0PL%2Fp86cLZ9oSkvqLIs%3D)

输出debug日志：

在调用setErrorState时，还会再次输出相同的debug 日志

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/8dfba2b2ea3544bdb102d91a6871c30e~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=KGxeYntQEEWaBqAAV2jxYMXXnBE%3D)

#### IOException

**windows**：

java.io.IOException: **远程主机强迫关闭了一个现有的连接**。

**Linux**：

java.io.IOException: **Connection reset by peer**

java.io.IOException: **Broken pipe， 貌似多次触发才会报错**

当从socket中读取或写入 数据的时候，对端已经关闭了连接。

从堆栈中可以看到调用的底层网络api：**read0/write0**

日志内容如下：

**win**

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/fe707c6208594cc9b48349a97c10327c~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=ocLrL%2Bus6gXzY5VaG%2FSmWsBX0%2Fg%3D)

或：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/27147441a05a4b3493783c60dbbf7a93~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=k4FakUXxSSjTK7SfYWbNM72HfE8%3D)

linux： 多次触发才行。1、2次貌似不行\
curl --max-time 1 <http://192.168.241.129:8080/test_timeout?c=3>

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/0d45a0c30c92468abb229ff0280dac42~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=sonrL2d2OqD6T0rAjWmTe%2Bx2xGM%3D)

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/7587bbbbe2a54b36bb8b721253a78e1c~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=OtkLwnbIvsxUG4blsHfQEPClT1g%3D)

**tomcat 捕获错误**：

通常情况下在下面两种场景中会抛出IOException

1.  controller 中 使用 Servlet 对象主动向底层写手动调用flush时，连接被关闭：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/e4a1e8c49f114b8abef7c6c78c5f473a~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=WC%2B2%2FgwoeQ8vyJcQSLzzg9zRFNs%3D)

HandleIOException方法：内部调用 setErrorState， 如果开启了DEBUG ，则输出上面日志信息

2.  当Servlet处理完成，向客户端响应数据时连接被关闭：

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/6e7320967a1b4067bf6edbb553c5804a~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=DBcAll8JHYzunNCxVk5xvgOWu48%3D)

#### Filter 捕获异常

由于在发生异常时，tomcat会执行下面方法，进行保存Exception信息。如果是在**filter前**发生的异常，可以通过获取response的错误信息（比如主动调用flush 时，连接关闭）， 连接关闭貌似不能马上通知到应用层，

当response.getWrite() 调用flush 时, 会首先进入该方法，执行ob.flush()， 当内部执行抛出IOException时，这里会设置**error = true**。 当下一次执行write 、 flush 时会判断该状态，如果已经是true，那么直接return。不会调用底层的IO接口。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/a70372696e13429bb46a920a47052d90~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=iHmKFYe9WdcBUq4FR2wtK7h9QuI%3D)

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/11cfefacbcb644a983a09444f970aea4~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=9jof9jzW%2BoJrORyeR0p0BpKdO5A%3D)

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/9186c23a61c64fb79dbc633ac5c17024~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=zhHNUInsPtAZR8RFAAVzwmNwZtk%3D)

handleIOException： 这里会设置异常到Request对象中。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/3d713befb73c4d888f4bc5653b1c9128~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=0%2BAd3CvPzHfbAIC3AFhYUmJdM%2F8%3D)

filter 中通过对象获取异常：

Exception attribute = (Exception) request.getAttribute(RequestDispatcher.ERROR\_EXCEPTION);\
![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/c7b536301bca41ca86bd236c4c622d6e~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=Dz8bCnkdlATEgn7UUM5Tt8IiRNM%3D)

### Linux 中的网络异常分析

#### **Connection reset by peer：**

当服务端发起RST 后，客户端继续从缓存区读取数据将会抛出该异常。 服务端正常关闭通常是发送FIN 优雅关闭，因此不会触发该异常。

server：

    import socket
    import struct

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", 12345))
    server.listen(1)

    print("Server is listening...")
    conn, addr = server.accept()
    print(f"Connection from {addr}")

    # 配置 SO_LINGER，强制发送 RST 包
    linger_struct = struct.pack('ii', 1, 0)  # 开启 SO_LINGER，超时时间为 0
    conn.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, linger_struct)

    print("Closing connection with RST...")
    conn.close()  # 强制关闭连接，发送 RST 包
    server.close()

\*\*client：

\*\*

    import socket
    import time
    try:
        client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        client.connect(("127.0.0.1", 12345))
        time.sleep(1)  # 确保收到了RST，后面的操作都会触发异常
        
        client.send(b"Hello, server!")  # 尝试发送消息。
        # 强制探测连接状态
        data = client.recv(1024)  # 这里会触发异常，因为连接被重置
        print(f"Received: {data}")
    except socket.error as e:
        print(f"Socket error: {e}")

这里是构造的一个 RST、ACK包，表示收到了一个非法的包（连接已经关闭）

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/3554c15c628d4ce9a318f8df94667688~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=kM8w%2B%2FXcbzyVTQejdNlQXikrXhc%3D)

#### **Broken pipe：**

当client正常关闭后，client 继续像socket缓冲区写入数据，将会收到**SIGPIPE**信号，**应用将会停止。同时不会产生core dump**

***

**第一次write 不会收到SIGPIPE 信号。当调用第二次时就会触发该信号，同时抛出异常，结束进程。**

当client 关闭连接后，会发送FIN数据包给server，server会立即回复ACK。当调用write将数据发送给对方时，对方已经关闭了socket，处于不接受数据的状态，此时收到数据后立即回复RST，使client立即关闭。

由于server 本身也已经关闭socket，因此第二次调用write 就会收到sigpipe信号。

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/1d47aac3595e467584cf4e0f58ef34b3~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=3QH5Syqqb%2FHkxjJKdliEDOsvzpY%3D)

***

![](https://p0-xtjj-private.juejin.cn/tos-cn-i-73owjymdk6/15ca2fbbe302440b940708cd315624f6~tplv-73owjymdk6-jj-mark-v1:0:0:0:0:5o6Y6YeR5oqA5pyv56S-5Yy6IEAgeGlhb3llMjAxOA==:q75.awebp?policy=eyJ2bSI6MywidWlkIjoiMTUzMDk3NDYzMTM3MjYwMCJ9&rk3s=f64ab15b&x-orig-authkey=f32326d3454f2ac7e96d3d06cdbb035152127018&x-orig-expires=1780132918&x-orig-sign=0VNaL43dG1xBzsZfQzuPa0ys7yw%3D)

需要注意，一些框架像glibc可能会忽略SIGPIPE信号，防止进程终止。 因此为了模拟需要开启默认行为：

    // 恢复 SIGPIPE 的默认行为,
    signal(SIGPIPE, SIG_DFL);

    struct sigaction sa;
    sigaction(SIGPIPE, NULL, &sa); // 获取 SIGPIPE 当前行为
    if (sa.sa_handler == SIG_IGN) {    
        printf("SIGPIPE is ignored\n");
    } else if (sa.sa_handler == SIG_DFL) {
        printf("SIGPIPE has default behavior\n");
    } else {
        printf("SIGPIPE has a custom handler\n");
    }
