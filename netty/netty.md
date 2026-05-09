## NIO
JDK 提供的高性能网络实现，底层采用Selector机制实现多路复用，在不同的平台采用不同的技术实现：win 采用 IOCP、Linux 采用EPoll，mac 采用Kqueue
### JDK Buffer

![image-20230424215904759](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20230424215904759.png)

Buffer接口定义下面属性：用于记录相关位置

```java
// Invariants: mark <= position <= limit <= capacity
 *     private int mark = -1; // 标记位置
 *     private int position = 0;  // 读取位置
 *     private int limit;    // 最大读取位置
 *     private final int capacity;  // 最大长度
```



Buffer相关方法：

```java
ByteBuffer buffer = ByteBuffer.wrap("hello world".getBytes());
buffer.get(array); // 将buffer中的数据写入目标： 会更新buffer的position
// buffer.mark(); // 标记读取位置，方便下一次继续从这个位置读取： mark = position
// buffer.reset(); // 恢复到标记位置， position = mark
buffer.rewind(); // 回退到起始位置， position = 0， mark = 0
mappedByteBuffer.put(buffer); // 将buffer的数据写入到mappedByteBuffer

```



### NIO Server

```java
public class NIOServer {
    public static void main(String[] args) throws Exception {
        ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
        serverSocketChannel.socket().bind(new InetSocketAddress(6666));
        serverSocketChannel.configureBlocking(false);

        // 创建一个Selector对象
        Selector selector = Selector.open();
        serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);

        // System.out.println(selector);
        while (true) {
            // select方法会 阻塞2s
            while (selector.select(2000) == 0) {
                System.out.println("not found connect...");
                continue;
            }
            // 有事件发生的selectKey数量
            System.out.println("selectedKeys" + selector.selectedKeys().size());
            // 所有注册到selector中的selectKey数量
            System.out.println("keys" + selector.keys().size());

            // SelectionKey： 同一个链接使用一个SelectionKey对象，也只会对应一个channel对象， 多次请求都是同一个对象
            // SelectionKey 处理后，必须remove掉，否则下次继续处理可能并没有相应的事件而产生错误，
            // 当有事件发生是仅仅是调用的add添加事件：sun.nio.ch.SelectorImpl.processReadyEvents
            Set<SelectionKey> selectionKeys = selector.selectedKeys();
            Iterator<SelectionKey> keyIterator = selectionKeys.iterator();
            while (keyIterator.hasNext()) {
                SelectionKey selectionKey = keyIterator.next();

                if (selectionKey.isAcceptable()) {
                    SocketChannel socketChannel = serverSocketChannel.accept();

                    socketChannel.configureBlocking(false);
                    socketChannel.register(selector, SelectionKey.OP_READ, ByteBuffer.allocate(1024));
                    System.out.println("from client" + socketChannel.hashCode());
                }

                if (selectionKey.isReadable()) {
                    SocketChannel channel = (SocketChannel) selectionKey.channel();

                    ByteBuffer attachment = (ByteBuffer) selectionKey.attachment();
                    channel.read(attachment);
                    System.out.println("client send: " + new String(attachment.array()));
                }

                keyIterator.remove();    // 如果这里不remove，那么下次依然会得到之前已经处理过的SelectionKey，再次处理就会报错
            }
        }
    }
}
```



关于remove方法：

在SelectorImpl类中有下面方法，当有相关事件发生时，会将相应的SelectionKey添加到selectedKeys，如果处理完当前事件后不移除相应的SelectionKey，那么下次其他channel 触发相应的事件时，会遍历到之前已经处理过的selectionKey，此时尝试操作该selectionKey 可能会发生错误。



![image-20230422102138924](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20230422102138924.png)





流程图：
https://www.processon.com/view/5f572bc1e0b34d6f59e612dc?fromnew=1

Selector 、 Channel 和 Buffer 的关系图(简单版)
关系图的说明:
每个channel 都会对应一个Buffer
Selector 对应一个线程， 一个线程对应多个channel(连接)
该图反应了有三个channel 注册到 该selector //程序
程序切换到哪个channel 是有事件决定的, Event 就是一个重要的概念
Selector 会根据不同的事件，在各个通道上切换
Buffer 就是一个内存块 ， 底层是有一个数组
数据的读取写入是通过Buffer, 这个和BIO , BIO 中要么是输入流，或者是输出流, 不能双向，但是NIO的Buffer 是可以读也可以写, 需要 flip 方法切换
channel 是双向的, 可以返回底层操作系统的情况, 比如Linux ， 底层的操作系统通道就是双向的.

![image-20210126093818338](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20210126093818338.png)

```java
// 有事件发生的selectKey数量
System.out.println("selectedKeys" + selector.selectedKeys().size());
// 所有注册到selector中的selectKey数量
System.out.println("keys" + selector.keys().size());
```





NioEventLoopGroup 下包含多个 NioEventLoop 

每个 NioEventLoop 中包含有一个 Selector，一个 taskQueue 

每个 NioEventLoop 的 Selector 上可以注册监听多个 NioChannel 

每个 NioChannel 只会绑定在唯一的 NioEventLoop 上 

每个 NioChannel 都绑定有一个自己的 ChannelPipeline













## Netty架构

![image-20210731181134928](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20210731181134928.png)





Netty 抽象出两组线程池 BossGroup 专门负责接收客户端的连接, WorkerGroup 专门负责网络的读写 


1. BossGroup 和 WorkerGroup 类型都是 NioEventLoopGroup NioEventLoopGroup 相当于一个事件循环组, 这个组中含有多个事件循环 ，每一个事件循环是 NioEventLoop 
2. NioEventLoop 表示一个不断循环的执行处理任务的线程， 每个 NioEventLoop 都有一个 selector , 用于监听绑 定在其上的 socket 的网络通讯 
3. NioEventLoopGroup 可以有多个线程, 即可以含有多个 NioEventLoop 
4. 每个 Boss NioEventLoop 循环执行的步骤有 3 步
    - 轮询 accept 事件     
    - 处理 accept 事件 , 与 client 建立连接 , 生成 NioScocketChannel , 并将其注册到某个 worker NIOEventLoop 上 的 selector 
    - 处理任务队列的任务 ， 即 runAllTasks 

5. 每个 Worker NIOEventLoop 循环执行的步骤 
    - 轮询 read, write 
    - 事件 处理 i/o 事件， 即 read , write 事件，在对应 NioScocketChannel 处理 
    - 处理任务队列的任务 ， 即 runAllTasks 
6. 每个Worker NIOEventLoop 处理业务时，会使用pipeline(管道), pipeline 中包含了 channel , 即通过pipeline 可以获取到对应通道, 管道中维护了很多的 处理器 



![image-20210731094107478](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20210731094107478.png)







![image-20210731100005629](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20210731100005629.png)



## Pipeline 和 ChannelPipeline 

ChannelPipeline 是一个重点： 

1) ChannelPipeline 是一个 Handler 的集合，它负责处理和拦截 inbound 或者 outbound 的事件和操作，相当于 一个贯穿 Netty 的链。(也可以这样理解：ChannelPipeline 是 保存 ChannelHandler 的 List，用于处理或拦截 Channel 的入站事件和出站操作) 

2) ChannelPipeline 实现了一种高级形式的拦截过滤器模式，使用户可以完全控制事件的处理方式，以及 Channel 中各个的 ChannelHandler 如何相互交互 

3) 在 Netty 中每个 Channel 都有且仅有一个 ChannelPipeline 与之对应，它们的组成关系如下



![image-20210731102300275](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20210731102300275.png)





![image-20210731102615156](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20210731102615156.png)

![image-20210731102822956](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20210731102822956.png)



入站、出站是相对于client来说的





每个 NioEventLoop 实例内部都会有一个自己的 Thread 实例





initAndRegister() 这个方法我们已经接触过两次了，前面介绍了 1️⃣ Channel 的实例化，实例化过程中，会执行 Channel 内部 Unsafe 和 Pipeline 的实例化，以及在上面 2️⃣ init(channel) 方法中，会往 pipeline 中添加 handler（pipeline 此时是 head+channelnitializer+tail）。？









## 初始化源码剖析

> 部分源码为 4.1.92.Final



![image-20230423172432641](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20230423172432641.png)

**Client demo：**

Client模式创建**Bootstrap**，channel为NioSocketChannel.class

Server模式为ServerBootStrap，channel为NioServerSocketChannel.class


![image-20230423172432641](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20240608215151686.png)

如果需要建立多个client连接对象，可以对同一个Bootstrap connect到不同的地址。

如果内部有一些特殊的操作需要保证线程安全，可以使用Bootstrap.clone().connect()





### NioEventLoopGroup初始化

NioEventLoopGroup：事件循环组，用于处理IO事件。内部会创建一个NioEventLoop数组，每一个NioEventLoop绑定一个线程，绑定一个Selector，用于支持多个连接。



NioEventLoopGroup 继承MultithreadEventExecutorGroup，最终会进入MultithreadEventExecutorGroup：

默认创建2 * CPU 的NioEventLoop

![image-20240608215619799](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20240608215619799.png)



### Client 初始化

当Bootstrap调用connect方法后，进入doResolveAndConnect

![image-20260228210744909](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228210744909.png)

#### initAndRegister

newChannel：创建**NioSocketChannel**对象，封装JDK层面SocketChannel。初始化unsafe，pipeline。设置非阻塞模式

register：绑定一个NioEventLoop，同时register到Selector。

![image-20240608220058788](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20240608220058788.png)



register最中走向unsafe#register：

![image-20240608220730986](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20240608220730986.png)



##### NioEventLoop#execute

为当前**NioEventLoop**启动线程

![image-20240608221038008](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20240608221038008.png)



startThread方法会执行到doStartThread：

![image-20240608222206993](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20240608222206993.png)



executor.execute:

executor在SingleThreadEventExecutor 构造方法中定义， 即封装了ThreadPerTaskExecutor。

![image-20240608221648509](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20240608221648509.png)



##### register0

前面unsafe#register 提交了register0方法的任务。

![image-20260228213650341](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228213650341.png)



#### doResolveAndConnect0

这里发起真正的网络连接操作。



最前面执行doResolveAndConnect方法时，执行initAndRegister返回了一个ChannelFuture对象。

当future没有完成时，注册了一个listener函数，前面register0中执行的safeSetSuccess，将会回调这里的listener。

![image-20260228214025417](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228214025417.png)



![image-20260228214259869](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228214259869.png)

![image-20260228214337088](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228214337088.png)



##### pipeline#connect

![image-20260228214406990](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228214406990.png)

![image-20260228214430958](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228214430958.png)



tail#connect 过滤出connect状态的outbound handler， 一般直接就到HeadContext。

![image-20260228214857158](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228214857158.png)



![image-20260228215004276](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228215004276.png)



调用底层**`SocketChannel.connect()`**， 这个操作是非阻塞的，返回false表示正在进行中，如果配置了超时，会提交一个schedule，如果没有连接成功抛出异常：connection timed out: 

如果无法联通，JDK会报： Connection refused: no further information:

![image-20260301152107338](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260301152107338.png)



##### 执行真正的connect

![image-20260228215013657](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228215013657.png)

![image-20260228215112430](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260228215112430.png)



由于上面connect是非阻塞，连接结束后，会触发Connect事件，如果连接失败也会触发。

![image-20260301153143586](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260301153143586.png)



doFinishConnect：会再次检查连接状态

fulfillConnectPromise：完成一些状态设置，回调promise， 触发fireChannelActive

![image-20260301153306632](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260301153306632.png)







### Server 初始化

与Client不同，需要一个boosGroup、一个workerGroup。

boosGroup：用于处理accept事件，当接受到一个连接时，会将该连接（channel）注册到workerGroup。

workerGroup：处理read、write事件。

```java
// Configure the server.
EventLoopGroup bossGroup = new NioEventLoopGroup(1);
EventLoopGroup workerGroup = new NioEventLoopGroup();
final EchoServerHandler serverHandler = new EchoServerHandler();
try {
    ServerBootstrap b = new ServerBootstrap();
    b.group(bossGroup, workerGroup)
     .channel(NioServerSocketChannel.class)
     .option(ChannelOption.SO_BACKLOG, 100)
     .handler(new LoggingHandler(LogLevel.INFO)) // boosGroup的handler
     .childHandler(new ChannelInitializer<SocketChannel>() { // worker对应的handler
         @Override
         public void initChannel(SocketChannel ch) throws Exception {
             ChannelPipeline p = ch.pipeline();
             if (sslCtx != null) {
                 p.addLast(sslCtx.newHandler(ch.alloc()));
             }
             // p.addLast(new LoggingHandler(LogLevel.INFO));
             p.addLast(serverHandler);
         }
     });

    // Start the server.
    ChannelFuture f = b.bind(PORT).sync();

    // Wait until the server socket is closed.
    f.channel().closeFuture().sync();
```

大部分逻辑跟Client 类似。

#### doBind

ServerBootstrap#bind(port)， 进入AbstractBootstrap#doBind

```java
private ChannelFuture doBind(final SocketAddress localAddress) {
    // 初始化channal中的相关属性：options，attr， 在ChannelPipeline中添加ChannelInitializer
    // ChannelInitializer（ServerBootstrap#init）：会向pipeline 中添加用户自定义的handler，以及ServerBootstrapAcceptor
    // ServerBootstrapAcceptor（包含用户自定义的childHandler）
    final ChannelFuture regFuture = initAndRegister();
    final Channel channel = regFuture.channel();
    if (regFuture.cause() != null) {
        return regFuture;
    }

    if (regFuture.isDone()) {
        // At this point we know that the registration was complete and successful.
        ChannelPromise promise = channel.newPromise();
        doBind0(regFuture, channel, localAddress, promise);
        return promise;
    } else {
          regFuture.addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture future) throws Exception {
                 
                        promise.registered();

                        doBind0(regFuture, channel, localAddress, promise);
                    }
    }
}
```



#### initAndRegister

初始化NioServerSocketChannel，注册到Selector

```java
final ChannelFuture initAndRegister() {
    Channel channel = null;
    try {
        // 创建NioServerSocketChannel
        channel = channelFactory.newChannel();
        init(channel);
    } catch (Throwable t) {
    }
	// 注册channel到NioEventLoop
    ChannelFuture regFuture = config().group().register(channel);
    if (regFuture.cause() != null) {
        if (channel.isRegistered()) {
            channel.close();
        } else {
            channel.unsafe().closeForcibly();
        }
    }
}
```



##### init

为channel添加handler： 这里添加了一个**ServerBootstrapAcceptor**

```java
void init(Channel channel) throws Exception {
    ChannelPipeline p = channel.pipeline();

    final EventLoopGroup currentChildGroup = childGroup;
    final ChannelHandler currentChildHandler = childHandler;

    p.addLast(new ChannelInitializer<Channel>() {
        @Override
        public void initChannel(Channel ch) throws Exception {
            final ChannelPipeline pipeline = ch.pipeline();
            ChannelHandler handler = config.handler();
            if (handler != null) {
                pipeline.addLast(handler);
            }
            ch.eventLoop().execute(new Runnable() {
                @Override
                public void run() {
                    pipeline.addLast(new ServerBootstrapAcceptor(
                            currentChildGroup, currentChildHandler, currentChildOptions, currentChildAttrs));
                }
            });
        }
    });
}
```



##### register

完成注册Selector操作



SingleThreadEventLoop

```java
public ChannelFuture register(Channel channel) {
    return register(new DefaultChannelPromise(channel, this));
}
```

SingleThreadEventLoop

```java
public ChannelFuture register(final ChannelPromise promise) {
    ObjectUtil.checkNotNull(promise, "promise");
    promise.channel().unsafe().register(this, promise);
    return promise;
}
```



AbstractUnsafe

```java
public final void register(EventLoop eventLoop, final ChannelPromise promise) {
    if (eventLoop == null) {
        throw new NullPointerException("eventLoop");
    }
    if (isRegistered()) {
        promise.setFailure(new IllegalStateException("registered to an event loop already"));
        return;
    }
    if (!isCompatible(eventLoop)) {
        promise.setFailure(
                new IllegalStateException("incompatible event loop type: " + eventLoop.getClass().getName()));
        return;
    }

    AbstractChannel.this.eventLoop = eventLoop;

    if (eventLoop.inEventLoop()) {
        register0(promise);
    } else {
        try {
            eventLoop.execute(new Runnable() {
                @Override
                public void run() {
                    register0(promise);	// promise： 包含NioServerSocketChannel
                }
            });
        }
    }
}
```

AbstractUnsafe#register0

```java
private void register0(ChannelPromise promise) {
    try {
        // check if the channel is still open as it could be closed in the mean time when the register
        // call was outside of the eventLoop
        if (!promise.setUncancellable() || !ensureOpen(promise)) {
            return;
        }
        boolean firstRegistration = neverRegistered;
        doRegister();    // 注册selector
        neverRegistered = false;
        registered = true;

        // Ensure we call handlerAdded(...) before we actually notify the promise. This is needed as the
        // user may already fire events through the pipeline in the ChannelFutureListener.
        // 调用所有的handlerAdded方法
        pipeline.invokeHandlerAddedIfNeeded();

        safeSetSuccess(promise); // 回调
        // 调用channelRegistered
        pipeline.fireChannelRegistered();
        、、、、、
    }
}
```





##### doBind

当上面register0中调用safeSetSuccess方法后，会回调最前面doBind 的listener，进而执行底层真正的bind 端口操作。



最终执行到Unsafe， doBind后，发起channelActive的调用

![image-20260301120102439](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260301120102439.png)



##### 设置ACCEPT事件

前面发起fireChannelActive后，一路执行到HeadContext：

```java
public void channelActive(ChannelHandlerContext ctx) throws Exception {
    ctx.fireChannelActive();
    readIfIsAutoRead();  // tail.read(), --> outHandler.read() --> unsafe.beginRead();
}
```

DefaultChannelPipeline.HeadContext#read

```
public void read(ChannelHandlerContext ctx) {
    unsafe.beginRead();  
}
```



AbstractNioChannel

为SelectionKey 添加 **OP_ACCEPT** 事件

NioServerSocketChannel对象初始化时会指定readInterestOp 为 **OP_ACCEPT** 

```java
protected void doBeginRead() throws Exception {
    // Channel.read() or ChannelHandlerContext.read() was called
    final SelectionKey selectionKey = this.selectionKey;
    if (!selectionKey.isValid()) {
        return;
    }
    readPending = true;

    final int interestOps = selectionKey.interestOps();
    if ((interestOps & readInterestOp) == 0) {
        selectionKey.interestOps(interestOps | readInterestOp);
    }
}
```





#### ServerBootstrapAcceptor

当NioSocketChannel 接受到一个连接事件时，通过fireChannelRead方法执行到ServerBootstrapAcceptor.

这里主要为新连接添加childHandler，设置channel属性，同时注册到WorkerGroup中。



msg：为新连接生成的对象即NioSocketChannel。

```java
// ServerBootstrap.ServerBootstrapAcceptor
public void channelRead(ChannelHandlerContext ctx, Object msg) {
    final Channel child = (Channel) msg;
	// 向pipeline中添加childHandler （当前只有head、tail）
    // 会走到：DefaultChannelPipeline#addLast()， 设置PendingHandlerCallback为childHandler
    // childHandler 即启动类中指定的ChannelInitializer
    child.pipeline().addLast(childHandler);
    try {
        // AbstractUnsafe#register0
        // ChannelInitializer#handlerAdded --> ChannelInitializer#initChannel 
        // remove ChannelInitializer
        childGroup.register(child).addListener(new ChannelFutureListener() {
}
```



**handler的添加：**

DefaultChannelPipeline#addLast

```java
public final ChannelPipeline addLast(EventExecutorGroup group, String name, ChannelHandler handler) {
    final AbstractChannelHandlerContext newCtx;
    synchronized (this) {
        // 检查是否存在
        checkMultiplicity(handler);
		// 创建ChannelHandlerContext
        newCtx = newContext(group, filterName(name, handler), handler);
		// 添加到pipeline中
        addLast0(newCtx);

        // registered最开始为false，表示还没有注册在Eventloop
        if (!registered) {
            newCtx.setAddPending();
            // 创建PendingHandlerCallback 保存当前ChannelHandlerContext
            callHandlerCallbackLater(newCtx, true);
            return this;
        }

        EventExecutor executor = newCtx.executor();
        if (!executor.inEventLoop()) {
            newCtx.setAddPending();
            executor.execute(new Runnable() {
                @Override
                public void run() {
                    callHandlerAdded0(newCtx);
                }
            });
            return this;
        }
    }
    callHandlerAdded0(newCtx);
    return this;
}
```



### NioEventLoop

一个NioEventLoop （继承SingleThreadEventExecutor）对应**一个线程**处理，其上绑定了一个Selector，可以注册多个channel连接。

> NioEventLoop 会根据平台的不同创建不同的Selector实现（依赖JDK 的SelectorProvider）。

根据不同的平台，Netty 也提供了专门的EventLoop实现， 他们都是SingleThreadEventExecutor的子类

- linux： EpollEventLoop
- BSD：KQueueEventLoop

一般直接使用NioEventLoop 即可，在Netty 4.2 已经将专用的实现标记为过期了。





当前面NioEventLoopGroup 初始化NioEventLoop对象后，开始提交任务后，就会启动一个线程开始检查网络事件。

![image-20260301120852544](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260301120852544.png)

#### openSelector

> 会替换Selector的selectedKeys、publicSelectedKeys 为Netty的Set类型(数组实现)，提高效率

```java
private SelectorTuple openSelector() {
        final Selector unwrappedSelector;
    	// 创建底层Selector，根据OS平台的不同来创建, 如：WindowsSelectorImpl
        unwrappedSelector = provider.openSelector();
		// 默认开启优化
        if (DISABLE_KEY_SET_OPTIMIZATION) {
            return new SelectorTuple(unwrappedSelector);
        }
		
    	// jdk的SelectorImpl，publicKeys，keys 都是HashSet，
	    // netty会替换为SelectedSelectionKeySet
        Object maybeSelectorImplClass = sun.nio.ch.SelectorImpl.class
		.....
        final Class<?> selectorImplClass = (Class<?>) maybeSelectorImplClass;
    	// 内部实现为数组，用来替换jdk的SelectorImpl#publicKeys...
        final SelectedSelectionKeySet selectedKeySet = new SelectedSelectionKeySet();

        Object maybeException = AccessController.doPrivileged(new PrivilegedAction<Object>() {
            @Override
            public Object run() {
                try {
                    Field selectedKeysField = selectorImplClass.getDeclaredField("selectedKeys");
                    Field publicSelectedKeysField = selectorImplClass.getDeclaredField("publicSelectedKeys");
					...... 
                        //反射赋值
                    selectedKeysField.set(unwrappedSelector, selectedKeySet);
                    publicSelectedKeysField.set(unwrappedSelector, selectedKeySet);
                    return null;
                } catch (NoSuchFieldException e) {
                    return e;
                } catch (IllegalAccessException e) {
                    return e;
                }
            }
        });
        selectedKeys = selectedKeySet;
        logger.trace("instrumented a special java.util.Set into: {}", unwrappedSelector);
        return new SelectorTuple(unwrappedSelector,
                                 new SelectedSelectionKeySetSelector(unwrappedSelector, selectedKeySet));
    }
```



#### run

核心流程：

```java
select
processkey
runTask
```



```java
protected void run() {
    int selectCnt = 0;
    for (;;) {
        try {
            int strategy;
            try {
                   // 如果队列有任务，调用selectNow(), 否则直接返回SELECT
                strategy = selectStrategy.calculateStrategy(selectNowSupplier, hasTasks());
                switch (strategy) {
                case SelectStrategy.CONTINUE:
                    continue;

                case SelectStrategy.BUSY_WAIT:
                    // fall-through to SELECT since the busy-wait is not supported with NIO

                case SelectStrategy.SELECT:
                        // 返回定时任务最近的超时时间，没有返回-1
                    long curDeadlineNanos = nextScheduledTaskDeadlineNanos();
                    if (curDeadlineNanos == -1L) {
                        curDeadlineNanos = NONE; // nothing on the calendar
                    }
                    nextWakeupNanos.set(curDeadlineNanos);
                    try {
                        if (!hasTasks()) {
                            // 任务队列为空，指定超时时间为定时任务的超时时间
                            // 为NONE: select();
                            // 定时任务超时时间不大于当前0.995ms：selectNow()
                            // 						否则： select(timeout)
                            strategy = select(curDeadlineNanos);
                        }
                    } finally {
                        // This update is just to help block unnecessary selector wakeups
                        // so use of lazySet is ok (no race condition)
                        // 阻止不必要的唤醒操作，在提交任务后，当状态不为AWAKE才会唤醒
                        // 多个线程同时提交任务后，只有一个会调用wakeup()
                        // 这里延迟设置，没有必要保证可见性，提高效率
                        nextWakeupNanos.lazySet(AWAKE);
                    }
                    // fall through
                default:
                }
            } catch (IOException e) {
                // If we receive an IOException here its because the Selector is messed up. Let's rebuild
                // the selector and retry. https://github.com/netty/netty/issues/8566
                rebuildSelector0();
                selectCnt = 0;
                // 处理异常，仅仅sleep(1000),防止CPU 持续的触发异常
                handleLoopException(e);
                continue;
            }

            selectCnt++;
            cancelledKeys = 0;
            needsToSelectAgain = false;
            final int ioRatio = this.ioRatio;// 默认50，指定执行IO任务的时间比例
            boolean ranTasks;
            if (ioRatio == 100) {    // processKey()/runAllTasks 都不指定时间
                try {
                    if (strategy > 0) {
                        // 处理SelectionKey
                        processSelectedKeys();
                    }
                } finally {
                    // Ensure we always run tasks.
                    // 执行任务： 定时任务队列、taskQueue队列、tailTasks队列
                    ranTasks = runAllTasks();
                }
            } else if (strategy > 0) {
                final long ioStartTime = System.nanoTime();
                try {
                    processSelectedKeys();  // 处理SelectionKey
                } finally {
                    // Ensure we always run tasks.
                    final long ioTime = System.nanoTime() - ioStartTime;
                    // 执行任务的时间cpuTime：默认cpuTime = ioTime
                    // ioTime / (ioTime + cpuTime) = ioRatio/100
                    ranTasks = runAllTasks(ioTime * (100 - ioRatio) / ioRatio);
                }
            } else {
                // 最少的运行任务(最多一个任务)
                ranTasks = runAllTasks(0); // This will run the minimum number of tasks
            }

            if (ranTasks || strategy > 0) {
                if (selectCnt > MIN_PREMATURE_SELECTOR_RETURNS && logger.isDebugEnabled()) {
                    logger.debug("Selector.select() returned prematurely {} times in a row for Selector {}.",
                            selectCnt - 1, selector);
                }
                selectCnt = 0;
                
            }
            // 检查是否达到了持续过早返回的阈值，是的话重建Selector，
            // 将老的Channel转移到新的Selector中
            else if (unexpectedSelectorWakeup(selectCnt)) { // Unexpected wakeup (unusual case)
                selectCnt = 0;
            }
        } catch (CancelledKeyException e) {
            // Harmless exception - log anyway
            if (logger.isDebugEnabled()) {
                logger.debug(CancelledKeyException.class.getSimpleName() + " raised by a Selector {} - JDK bug?",
                        selector, e);
            }
        } catch (Error e) {
            throw e;
        } catch (Throwable t) {
            handleLoopException(t);
        } finally {
            // Always handle shutdown even if the loop processing threw an exception.
            try {
                // 检查当前NioEventloop是否被NioEventLoopGroup关闭
                if (isShuttingDown()) {
                    closeAll();
                    if (confirmShutdown()) {
                        return;
                    }
                }
            } catch (Error e) {
                throw e;
            } catch (Throwable t) {
                handleLoopException(t);
            }
        }
    }
}
```



#### processSelectedKey

```java
private void processSelectedKeys() {
    if (selectedKeys != null) {	// 默认采用优化后的
        processSelectedKeysOptimized();
    } else {
        processSelectedKeysPlain(selector.selectedKeys());
    }
}
```

根据相应的事件类型调用对应的处理方法

```java
private void processSelectedKey(SelectionKey k, AbstractNioChannel ch) {
     int readyOps = k.readyOps();
            // We first need to call finishConnect() before try to trigger a read(...) or write(...) as otherwise
            // the NIO JDK channel implementation may throw a NotYetConnectedException.
            if ((readyOps & SelectionKey.OP_CONNECT) != 0) {
                // remove OP_CONNECT as otherwise Selector.select(..) will always return without blocking
                // See https://github.com/netty/netty/issues/924
                int ops = k.interestOps();
                ops &= ~SelectionKey.OP_CONNECT;
                k.interestOps(ops);

                unsafe.finishConnect();
            }

            // Process OP_WRITE first as we may be able to write some queued buffers and so free memory.
            if ((readyOps & SelectionKey.OP_WRITE) != 0) {
                // Call forceFlush which will also take care of clear the OP_WRITE once there is nothing left to write
                ch.unsafe().forceFlush();
            }

            // Also check for readOps of 0 to workaround possible JDK bug which may otherwise lead
            // to a spin loop
            if ((readyOps & (SelectionKey.OP_READ | SelectionKey.OP_ACCEPT)) != 0 || readyOps == 0) {
                unsafe.read();
                if (!ch.isOpen()) {
                    // Connection already closed - no need to handle write.
                    return;
                }
            }
}
```





##### read/accept

NioMessageUnsafe

```java
 public void read() {
        assert eventLoop().inEventLoop();
        final ChannelConfig config = config();
        final ChannelPipeline pipeline = pipeline();
        final RecvByteBufAllocator.Handle allocHandle = unsafe().recvBufAllocHandle();
        allocHandle.reset(config);

        boolean closed = false;
        Throwable exception = null;
        try {
            try {
                do {
                    // 调用accept方法，得到SocketChannel，创建NioSocketChannel封装socketChannel，
                    // 保存到readBuf中
                    int localRead = doReadMessages(readBuf);
                    if (localRead == 0) {
                        break;
                    }
                    if (localRead < 0) {
                        closed = true;
                        break;
                    }

                    allocHandle.incMessagesRead(localRead);
                } while (allocHandle.continueReading()); // 是否还可以读取
            } catch (Throwable t) {
                exception = t;
            }

            int size = readBuf.size();
            for (int i = 0; i < size; i ++) {
                readPending = false;
                // 调用head#channelRead(NioSocketChannel), --> inbound#channelRead
                pipeline.fireChannelRead(readBuf.get(i));
            }
            readBuf.clear();
            allocHandle.readComplete();
            // 调用inbound#channelReadComplete
            pipeline.fireChannelReadComplete();

            if (exception != null) {
                closed = closeOnReadError(exception);

                pipeline.fireExceptionCaught(exception);
            }

            if (closed) {
                inputShutdown = true;
                if (isOpen()) {
                    close(voidPromise());
                }
            }
        } finally {
            // Check if there is a readPending which was not processed yet.
            // This could be for two reasons:
            // * The user called Channel.read() or ChannelHandlerContext.read() in channelRead(...) method
            // * The user called Channel.read() or ChannelHandlerContext.read() in channelReadComplete(...) method
            //
            // See https://github.com/netty/netty/issues/2254
            if (!readPending && !config.isAutoRead()) {
                removeReadOp();
            }
        }
    }
}
```



##### write

AbstractChannelHandlerContext

```java
private void write(Object msg, boolean flush, ChannelPromise promise) {
    // 从当前channelHandlerContext 向前找outbound handlerContext
    AbstractChannelHandlerContext next = findContextOutbound();
    final Object m = pipeline.touch(msg, next);
    EventExecutor executor = next.executor();
    if (executor.inEventLoop()) {
        if (flush) {
            next.invokeWriteAndFlush(m, promise);
        } else {
            next.invokeWrite(m, promise);
        }
    } else {
        AbstractWriteTask task;
        if (flush) {
            task = WriteAndFlushTask.newInstance(next, m, promise);
        }  else {
            task = WriteTask.newInstance(next, m, promise);
        }
        safeExecute(executor, task, promise, m);
    }
}
```



HeadContext

```java
private void invokeWriteAndFlush(Object msg, ChannelPromise promise) {
    if (invokeHandler()) {
        invokeWrite0(msg, promise); // 将msg 写入buffer
        invokeFlush0();    // 最终调用SocketChannel.write()
    } else {
        writeAndFlush(msg, promise);
    }
}
public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
            unsafe.write(msg, promise);
}
```



AbstractUnsafe:

```java
public final void write(Object msg, ChannelPromise promise) {
    assertEventLoop();

    ChannelOutboundBuffer outboundBuffer = this.outboundBuffer;
    if (outboundBuffer == null) {
        // If the outboundBuffer is null we know the channel was closed and so
        // need to fail the future right away. If it is not null the handling of the rest
        // will be done in flush0()
        // See https://github.com/netty/netty/issues/2362
        safeSetFailure(promise, WRITE_CLOSED_CHANNEL_EXCEPTION);
        // release message now to prevent resource-leak
        ReferenceCountUtil.release(msg);
        return;
    }

    int size;
    try {
        msg = filterOutboundMessage(msg);
        size = pipeline.estimatorHandle().size(msg);
        if (size < 0) {
            size = 0;
        }
    } catch (Throwable t) {
        safeSetFailure(promise, t);
        ReferenceCountUtil.release(msg);
        return;
    }

    outboundBuffer.addMessage(msg, size, promise);
}
```



## Pipeline

![image-20260301113322120](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260301113322120.png)

当检测到accept、read事件后，HeadContext开始读取数据包，依次筛选Inboundhandler向右传播。

业务handler中需要写回数据时，调用writeAndFlush操作，会依次向左筛选OutBoundHandler向左传播，最终走到HeadContext，执行底层Channel.write 操作。



Netty在Handler中定义了各种事件的监听方法，当Pipeline触发后，会依次调用各个Handler：

![image-20260301151231698](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260301151231698.png)

- handlerAdded：用于通知向pipeline中添加handler， 通常是ChannelInitializer使用

- channelRegistered: 表示channel注册到了Selector上
- channelActive：表示connect成功了
- channelRead：有read事件发生
- channelReadComplete： 读取操作完成
- channelWritabilityChanged： 写状态发生改变，用于背压



事件顺序如下：

connect() --> AbstractUnsafe#register0：    都是从HeadContext执行inbound事件
1. doRegister： 绑定当前NioSocketChannel到selector
2. invokeHandlerAddedIfNeeded： Handler#**handlerAdded**。 一般是PlainChannelInitializer， 添加Handler到pipeline
3. fireChannelRegistered：执行Handler#**channelRegistered**
4. 前面register0中会执行safeSetSuccess 回调，发起真实connect，异步操作。 
5. NioEventLoop收到connect事件，接着发起**fireChannelActive**
6. 收到read事件后，解析出一个ByteBuf发起**fireChannelRead**，当所有都读取完了发起**fireChannelReadComplete**。 参考 NioByteUnsafe#read



## AbstractNioByteChannel 

### read

io.netty.channel.nio.AbstractNioByteChannel.NioByteUnsafe#read

```java
 public final void read() {
        final ChannelConfig config = config();
        if (shouldBreakReadReady(config)) {
            clearReadPending();
            return;
        }
        final ChannelPipeline pipeline = pipeline();
        final ByteBufAllocator allocator = config.getAllocator();
        final RecvByteBufAllocator.Handle allocHandle = recvBufAllocHandle();
        allocHandle.reset(config);

        ByteBuf byteBuf = null;
        boolean close = false;
        try {
            do {
                
                byteBuf = allocHandle.allocate(allocator);
                // 将数据读入byteBuf中
                allocHandle.lastBytesRead(doReadBytes(byteBuf));
                if (allocHandle.lastBytesRead() <= 0) {
                    // nothing was read. release the buffer.
                    byteBuf.release();
                    byteBuf = null;
                    close = allocHandle.lastBytesRead() < 0;
                    if (close) {
                        // There is nothing left to read as we received an EOF.
                        readPending = false;
                    }
                    break;
                }

                allocHandle.incMessagesRead(1);
                readPending = false;
                pipeline.fireChannelRead(byteBuf);
                byteBuf = null;
            } while (allocHandle.continueReading());

            allocHandle.readComplete();
            pipeline.fireChannelReadComplete();

            if (close) {
                closeOnRead(pipeline);
            }
        } catch (Throwable t) {
            handleReadException(pipeline, byteBuf, t, close, allocHandle);
        } finally {
            // Check if there is a readPending which was not processed yet.
            // This could be for two reasons:
            // * The user called Channel.read() or ChannelHandlerContext.read() in channelRead(...) method
            // * The user called Channel.read() or ChannelHandlerContext.read() in channelReadComplete(...) method
            //
            // See https://github.com/netty/netty/issues/2254
            if (!readPending && !config.isAutoRead()) {
                removeReadOp();
            }
        }
    }
}
```





### WriteAndFlush

> unflushedEntry: 创建的Entry对象首先放入该链表中
>
> flushedEntry: 调用addFlush方法时,会将flushedEntry指向unflushedEntry
>
> tailEntry: 始终指向最新添加到unflushedEntry链表中的对象

```java
//io.netty.channel.AbstractChannel.AbstractUnsafe#flush
public final void flush() {
    assertEventLoop();

    ChannelOutboundBuffer outboundBuffer = this.outboundBuffer;
    if (outboundBuffer == null) {
        return;
    }

    outboundBuffer.addFlush();
    flush0();
}

// 将unflushedEntry 添加到flushedEntry链表
// io.netty.channel.ChannelOutboundBuffer#addFlush
public void addFlush() {
    Entry entry = unflushedEntry;
    if (entry != null) {
        if (flushedEntry == null) {
            // there is no flushedEntry yet, so start with the entry
            flushedEntry = entry;
        }
        do {
            flushed ++;
            // 设置entry 不能取消
            if (!entry.promise.setUncancellable()) {
                // Was cancelled so make sure we free up memory and notify about the freed bytes
                int pending = entry.cancel();
                decrementPendingOutboundBytes(pending, false, true);
            }
            entry = entry.next;
        } while (entry != null);

        // All flushed so reset unflushedEntry
        unflushedEntry = null;
    }
}

 protected final void flush0() {
    if (!isFlushPending()) {
        super.flush0();
    }
}
io.netty.channel.AbstractChannel.AbstractUnsafe#flush
protected void flush0() {
        if (inFlush0) {
            // Avoid re-entrance
        	return;
        }
        final ChannelOutboundBuffer outboundBuffer = this.outboundBuffer;
        if (outboundBuffer == null || outboundBuffer.isEmpty()) {
            return;
        }
        inFlush0 = true;	// 标记当前正在写入,其他线程不能写入
        // Mark all pending write requests as failure if the channel is inactive.
        if (!isActive()) {
          ... 处理链接被关闭的情况
        }

        try {
            doWrite(outboundBuffer);
        } catch (Throwable t) {
            handleWriteError(t);
        } finally {
            inFlush0 = false;
        }
    }
```



**doWrite**

> 将flushedEntry链表中的数据写入网络

```java
@Override
protected void doWrite(ChannelOutboundBuffer in) throws Exception {
    SocketChannel ch = javaChannel();
    int writeSpinCount = config().getWriteSpinCount(); // 默认16
    do {
        if (in.isEmpty()) {
            // All written so clear OP_WRITE
            clearOpWrite();
            // Directly return here so incompleteWrite(...) is not called.
            return;
        }

        // Ensure the pending writes are made of ByteBufs only.
        int maxBytesPerGatheringWrite = ((NioSocketChannelConfig) config).getMaxBytesPerGatheringWrite(); // OS 一次性最多可以写入的数据大小，该参数会动态变动
        ByteBuffer[] nioBuffers = in.nioBuffers(1024, maxBytesPerGatheringWrite);    // 将in.flushedEntry 转 ByteBuffer数组返回
        int nioBufferCnt = in.nioBufferCount();

        // Always use nioBuffers() to workaround data-corruption.
        // See https://github.com/netty/netty/issues/2761
        switch (nioBufferCnt) {
            case 0:
                // We have something else beside ByteBuffers to write so fallback to normal writes.
                writeSpinCount -= doWrite0(in);
                break;
            case 1: {   // 只有一个ByteBuffer
                // Only one ByteBuf so use non-gathering write
                // Zero length buffers are not added to nioBuffers by ChannelOutboundBuffer, so there is no need
                // to check if the total size of all the buffers is non-zero.
                ByteBuffer buffer = nioBuffers[0];
                int attemptedBytes = buffer.remaining();
                final int localWrittenBytes = ch.write(buffer); // 写入socket，返回写入的数据大小
                if (localWrittenBytes <= 0) {  // 没有数据写入，重新设置写状态
                    incompleteWrite(true);
                    return;
                }
                // 如果当前buffer一次性写入, 尝试修改该参数
                adjustMaxBytesPerGatheringWrite(attemptedBytes, localWrittenBytes, maxBytesPerGatheringWrite);
                in.removeBytes(localWrittenBytes);
                --writeSpinCount;
                break;
            }
            default: {
                // Zero length buffers are not added to nioBuffers by ChannelOutboundBuffer, so there is no need
                // to check if the total size of all the buffers is non-zero.
                // We limit the max amount to int above so cast is safe
                long attemptedBytes = in.nioBufferSize();
                final long localWrittenBytes = ch.write(nioBuffers, 0, nioBufferCnt);
                if (localWrittenBytes <= 0) {
                    incompleteWrite(true);
                    return;
                }
                // Casting to int is safe because we limit the total amount of data in the nioBuffers to int above.  写入部分数据
                adjustMaxBytesPerGatheringWrite((int) attemptedBytes, (int) localWrittenBytes,
                        maxBytesPerGatheringWrite);
                in.removeBytes(localWrittenBytes);
                --writeSpinCount;
                break;
            }
        }
    } while (writeSpinCount > 0);

    incompleteWrite(writeSpinCount < 0);  // < 0: maybe case 0
}
```







## ChannelHandler

>  整体继承关系

![image-20230423172447626](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20230423172447626.png)

![image-20230507174230413](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20230507174230413.png)



下面常用的几个抽象类：

![image-20240113130923896](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20240113130923896.png)

ByteToMessageDecoder：处理byteBuf对象类型 为其他自定义的对象。

SimpleChannelInboundHandler<T>： 定义了一个泛型，用于指定哪种类型的对象可以被该handler处理。 默认处理后会计数会减一，注意内存安全访问。

### ByteToMessageDecoder

> 处理ByteBuf对象的抽象类。通过实现该类的decode方法可以实现自定义协议。



当前类核心的方法如下：

**channelRead**

> 处理传入的ByteBuf对象，同时定义了一个Cumulator对象，用于处理一些包不完整的情况。

```java
ByteBuf cumulation = MERGE_CUMULATOR;	 // 记录ByteBuf 数据，如果当前拆包未完成，会记录当前的数据

// 默认情况
 public static final Cumulator MERGE_CUMULATOR = new Cumulator() {
     // cumulation: 当前新创建的空ByteBuf或者上一次创建的，  in： 当前请求的数据内容
    @Override
    public ByteBuf cumulate(ByteBufAllocator alloc, ByteBuf cumulation, ByteBuf in) {
        if (cumulation == in) {  // 相同的请求调用多次
            // when the in buffer is the same as the cumulation it is doubly retained, release it once
            in.release();
            return cumulation;
        }
        if (!cumulation.isReadable() && in.isContiguous()) {    // cumulation 不可读，可能是才创建的空ByteBuf
            // If cumulation is empty and input buffer is contiguous, use it directly
            cumulation.release();
            return in;
        }
        try {
            final int required = in.readableBytes();
            // 这里说明上一次 请求读取的部分片段，不完整，将当前ByteBuf组合在一起
            // 这里判断空间是否够
            if (required > cumulation.maxWritableBytes() ||
                required > cumulation.maxFastWritableBytes() && cumulation.refCnt() > 1 ||
                cumulation.isReadOnly()) {
                // Expand cumulation (by replacing it) under the following conditions:
                // - cumulation cannot be resized to accommodate the additional data
                // - cumulation can be expanded with a reallocation operation to accommodate but the buffer is
                //   assumed to be shared (e.g. refCnt() > 1) and the reallocation may not be safe.
                return expandCumulation(alloc, cumulation, in);
            }
            // 组合ByteBuf
            cumulation.writeBytes(in, in.readerIndex(), required);
            in.readerIndex(in.writerIndex());
            return cumulation;
        } finally {
            // We must release in all cases as otherwise it may produce a leak if writeBytes(...) throw
            // for whatever release (for example because of OutOfMemoryError)
            in.release();
        }
    }
};


private Cumulator cumulator = MERGE_CUMULATOR;
private boolean singleDecode;
private boolean first;

public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
    if (msg instanceof ByteBuf) {  // 从NioSocketChannel中默认读取的数据都是用ByteBuf封装
        selfFiredChannelRead = true;
        CodecOutputList out = CodecOutputList.newInstance();
        try {
            first = cumulation == null;
            // 将msg 中的数据存储到cumulation中
            cumulation = cumulator.cumulate(ctx.alloc(),
                    first ? Unpooled.EMPTY_BUFFER : cumulation, (ByteBuf) msg);
            callDecode(ctx, cumulation, out);
        } catch (DecoderException e) {
            throw e;
        } catch (Exception e) {
            throw new DecoderException(e);
        } finally {
            try {
                // True：cumulation 中的数据以及全部被完毕，清空cumulation， 否则保留(用于下一次拆包使用)
                if (cumulation != null && !cumulation.isReadable()) {
                    numReads = 0;
                    try {
                        cumulation.release();
                    } catch (IllegalReferenceCountException e) {
                        //noinspection ThrowFromFinallyBlock
                        throw new IllegalReferenceCountException(
                                getClass().getSimpleName() + "#decode() might have released its input buffer, " +
                                        "or passed it down the pipeline without a retain() call, " +
                                        "which is not allowed.", e);
                    }
                    cumulation = null;
                } else if (++numReads >= discardAfterReads) {   // 默认读取16次后， 丢弃一些字节内容
                    // We did enough reads already try to discard some bytes, so we not risk to see a OOME.
                    // See https://github.com/netty/netty/issues/4275
                    numReads = 0;
                    discardSomeReadBytes();
                }

                int size = out.size();
                firedChannelRead |= out.insertSinceRecycled();	// 用于channelComplete时是否还需要继续读取
                fireChannelRead(ctx, out, size);     // 传递到下一个handler
            } finally {	// 回收内容
                out.recycle();
            }
        }
    } else {
        // 非ByteBuf 直接向下传递
        ctx.fireChannelRead(msg);
    }
}
```

**callDecode**

> 依次解码得到完整的对象，将该完整的对象向下进行传递

```java
protected void callDecode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) {
    try {
        while (in.isReadable()) {
            final int outSize = out.size();

            if (outSize > 0) {	// 传递上一次解码的数据
                fireChannelRead(ctx, out, outSize);
                out.clear();     // 清空
                if (ctx.isRemoved()) {
                    break;
                }
            }
            // 第一次解码或者 继续解码
            int oldInputLength = in.readableBytes();
            // 解码ByteBuf
            decodeRemovalReentryProtection(ctx, in, out);
            if (ctx.isRemoved()) {
                break;
            }

            if (out.isEmpty()) {
                if (oldInputLength == in.readableBytes()) { // 剩下的数据无法解码， 保留该ByteBuf，与下一次请求的数据合并解码
                    break;
                } else {
                    continue;
                }
            }

            if (oldInputLength == in.readableBytes()) { // 解码出了空对象
                throw new DecoderException(
                        StringUtil.simpleClassName(getClass()) +
                                ".decode() did not read anything but decoded a message.");
            }

            if (isSingleDecode()) {
                break;
            }
        }
    } catch (DecoderException e) {
        throw e;
    } catch (Exception cause) {
        throw new DecoderException(cause);
    }
}
 final void decodeRemovalReentryProtection(ChannelHandlerContext ctx, ByteBuf in, List<Object> out)
            throws Exception {
     decodeState = STATE_CALLING_CHILD_DECODE;
     try {
         // 调用具体的实现类，解码byteBuf： 如：LineBasedFrameDecoder
         decode(ctx, in, out);
     } finally {
         boolean removePending = decodeState == STATE_HANDLER_REMOVED_PENDING;
         decodeState = STATE_INIT;
         if (removePending) {	// 当其他地方调用了handlerRemoved方法时，才会成立。 处理完当前的数据后，然后从pipeline中移除当前handler
             fireChannelRead(ctx, out, out.size());
             out.clear();
             handlerRemoved(ctx);
         }
     }
 }
```





### HttpServerCodec

extends HttpObjectDecoder



HttpServerCodec包含了如下：

```
HttpServerRequestDecoder
HttpServerResponseEncoder
```



来源：ByteToMessageDecoder#decodeRemovalReentryProtection —> 

```java
// HttpServerCodec
protected void decode(ChannelHandlerContext ctx, ByteBuf buffer, List<Object> out) throws Exception {
    int oldSize = out.size();
    super.decode(ctx, buffer, out); // HttpObjectDecoder#decode
    int size = out.size();
    for (int i = oldSize; i < size; i++) {
        Object obj = out.get(i);
        if (obj instanceof HttpRequest) {
            queue.add(((HttpRequest) obj).method());
        }
    }
}
```



解析HTTP请求，得到HttpRequest、HttpContent 等对象

```java
 protected void decode(ChannelHandlerContext ctx, ByteBuf buffer, List<Object> out) throws Exception {
        if (resetRequested.get()) {
            resetNow();
        }

        switch (currentState) {
        case SKIP_CONTROL_CHARS:
            // Fall-through
        case READ_INITIAL: 
                ...
        case READ_HEADER:
                ...
        case READ_VARIABLE_LENGTH_CONTENT:
```







### HttpObjectAggregator

```
HttpObjectAggregator
        extends MessageAggregator
        extends MessageToMessageDecoder
```

> HttpServerCodec 在解析请求时会首先解析请求头信息，得到一个HttpMessage对象， 如果还有body 内容，会进行第二次请求得到HttpContent。如此便会传递两个对象。
>
> 使用HttpObjectAggregator 则可以将HttpMessage、HttpContent 聚合为AggregatedFullHttpRequest对象。



HTTP相关对象：

HttpRequest：只有请求头相关信息
HttpContent： 包含Body内容



![image-20230528161308172](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20230528161308172.png)



### MessageAggregator

```java
protected void decode(final ChannelHandlerContext ctx, I msg, List<Object> out) throws Exception {
    // 第一个消息为HttpMessage (返回true)， 最后一个为LastHttpContent
    if (isStartMessage(msg)) {
        aggregating = true;
        S m = (S) msg;

        // Send the continue response if necessary (e.g. 'Expect: 100-continue' header)
  		// 如果有'Expect: 100-continue， 那么直接回复
        Object continueResponse = newContinueResponse(m, maxContentLength, ctx.pipeline());
        if (continueResponse != null) {
            // Cache the write listener for reuse.
            ChannelFutureListener listener = continueResponseWriteListener;
           	...

            // Make sure to call this before writing, otherwise reference counts may be invalid.
            boolean closeAfterWrite = closeAfterContinueResponse(continueResponse);
            handlingOversizedMessage = ignoreContentAfterContinueResponse(continueResponse);

            // 对包含头部信息为：Expect: 100-continue 的请求进行回复
            final ChannelFuture future = ctx.writeAndFlush(continueResponse).addListener(listener);
			....
            
          // 判断是否超过了最大长度
        } else if (isContentLengthInvalid(m, maxContentLength)) {
            // if content length is set, preemptively close if it's too large
            invokeHandleOversizedMessage(ctx, m);
            return;
        }
		// 
        if (m instanceof DecoderResultProvider && !((DecoderResultProvider) m).decoderResult().isSuccess()) {
            O aggregated;
            if (m instanceof ByteBufHolder) {
                aggregated = beginAggregation(m, ((ByteBufHolder) m).content().retain());
            } else {
                aggregated = beginAggregation(m, EMPTY_BUFFER);
            }
            finishAggregation0(aggregated);
            out.add(aggregated);
            return;
        }

        // A streamed message - initialize the cumulative buffer, and wait for incoming chunks.
        CompositeByteBuf content = ctx.alloc().compositeBuffer(maxCumulationBufferComponents);
        if (m instanceof ByteBufHolder) {
            appendPartialContent(content, ((ByteBufHolder) m).content());
        }
        // 这里解析Transfer-Encoding: chunked， 会得到AggregatedFullHttpRequest对象
        currentMessage = beginAggregation(m, content);
    } else if (isContentMessage(msg)) {  // 是ContentMessage， 一般为最后一个
        // 为空说明HttpRequest 在判断长度时超过了指定最大长度
        if (currentMessage == null) {
            return;
        }

        // Merge the received chunk into the content of the current message.
        CompositeByteBuf content = (CompositeByteBuf) currentMessage.content();

        @SuppressWarnings("unchecked")
        final C m = (C) msg;
        // Handle oversized message.  判断是否超过最大值
        if (content.readableBytes() > maxContentLength - m.content().readableBytes()) {
            // By convention, full message type extends first message type.
            @SuppressWarnings("unchecked")
            S s = (S) currentMessage;
            invokeHandleOversizedMessage(ctx, s);
            return;
        }
		// 聚合HttpRequest/HttpContent
        appendPartialContent(content, m.content());
        aggregate(currentMessage, m);

        final boolean last;
        if (m instanceof DecoderResultProvider) {
          ...
        } else {
            last = isLastContentMessage(m);
        }
		// 是LastContentMessage
        if (last) {
            // 计算Content-length，设置到header中
            finishAggregation0(currentMessage);

            // All done
            out.add(currentMessage);
            currentMessage = null;
        }
    } else {
        throw new MessageAggregationException();
    }
}
```







### SSL





## WebSocket 实现

> WebSocket 通常用于一些聊天程序中，支持服务器主动推送数据到客户端。下面介绍下Netty中如何实现该协议的。



直接打开官方源码包Example案例：

io.netty.example.http.websocketx.server.WebSocketServer

主要看下WebSocketServerInitializer类：

```java
public void initChannel(SocketChannel ch) throws Exception {
        ChannelPipeline pipeline = ch.pipeline();
        if (sslCtx != null) {
            pipeline.addLast(sslCtx.newHandler(ch.alloc()));
        }
    	// 解析HTTP 请求 对象 为HttpMessage、HttpContent（分别表示：header、body）
        pipeline.addLast(new HttpServerCodec());
    	// 将HttpMessage、HttpContent 聚合为一个完整的AggregatedFullHttpRequest对象
        pipeline.addLast(new HttpObjectAggregator(65536));
	    // 如果是http 请求，这里会返回websocket 通讯的 html内容信息
        pipeline.addLast(new WebSocketIndexPageHandler(WEBSOCKET_PATH));
    	// 用于处理websocket压缩扩展字段内容
        pipeline.addLast(new WebSocketServerCompressionHandler());
    	// 处理websocket 协议的核心部分
        pipeline.addLast(new WebSocketServerProtocolHandler(WEBSOCKET_PATH, null, true));
    	// 如果请求数据是websocket的Frame，将会在这里解析处理
        pipeline.addLast(new WebSocketFrameHandler());
    }
```







### WebSocketServerCompressionHandler

> 处理Websocket 支持的一些扩展信息



### WebSocketServerProtocolHandshakeHandler

#### channelRead方法如下：

```java
.... 省略
    
// 创建一个握手对象工厂
final WebSocketServerHandshakerFactory wsFactory = new WebSocketServerHandshakerFactory(
            getWebSocketLocation(ctx.pipeline(), req, serverConfig.websocketPath()),
            serverConfig.subprotocols(), serverConfig.decoderConfig());
	// 创建一个握手对象的实例对象，会根据header中的Sec-Websocket-Version字段，创建相应的hander， 如13：WebSocketServerHandshaker13
    final WebSocketServerHandshaker handshaker = wsFactory.newHandshaker(req);
    final ChannelPromise localHandshakePromise = handshakePromise;
    if (handshaker == null) { // 不支持
        WebSocketServerHandshakerFactory.sendUnsupportedVersionResponse(ctx.channel());
    } else {
        // 将握手对象绑定到channel中的属性中
        WebSocketServerProtocolHandler.setHandshaker(ctx.channel(), handshaker);
        // 在握手前移除当前handler
        ctx.pipeline().remove(this);
		// 进入握手处理过程
        final ChannelFuture handshakeFuture = handshaker.handshake(ctx.channel(), req);
        handshakeFuture.addListener(new ChannelFutureListener() {
          .... 握手完成/失败后的一些处理过程
            }
        });
        applyHandshakeTimeout();
    }
} finally {
    ReferenceCountUtil.release(req);
}
```





#### handshake

WebSocketServerHandshaker.java#handshake

```java
// 处理握手过程,生成response对象,这里会处理 header 中的sec-websocket-key字段, 得到响应后的sec-websocket-accept 
FullHttpResponse response = newHandshakeResponse(req, responseHeaders);

// 下面都是移除http中的一些handler对象
ChannelPipeline p = channel.pipeline();
if (p.get(HttpObjectAggregator.class) != null) {
    p.remove(HttpObjectAggregator.class);
}
if (p.get(HttpContentCompressor.class) != null) {
    p.remove(HttpContentCompressor.class);
}
ChannelHandlerContext ctx = p.context(HttpRequestDecoder.class);
final String encoderName;
if (ctx == null) {
    // this means the user use an HttpServerCodec
    ctx = p.context(HttpServerCodec.class);
	...
    p.addBefore(ctx.name(), "wsencoder", newWebSocketEncoder());
    p.addBefore(ctx.name(), "wsdecoder", newWebsocketDecoder());
    encoderName = ctx.name();
} else {
    p.replace(ctx.name(), "wsdecoder", newWebsocketDecoder());

    encoderName = p.context(HttpResponseEncoder.class).name();
    p.addBefore(encoderName, "wsencoder", newWebSocketEncoder());
}

```





最终的handler如下: 

![image-20240113162652463](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20240113162652463.png)









WebSocket协议具体解析过程见:

io.netty.handler.codec.http.websocketx.WebSocket08FrameDecoder#decode

网上找了一个截图如下:

![](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/f636afc379310a55cd169a01bc4543a982261010.png)

### HTTP处理过程

浏览器发起websocket连接:

```http
GET ws://127.0.0.1:8080/websocket HTTP/1.1
Host: 127.0.0.1:8080
Connection: Upgrade  # 连接类型
Upgrade: websocket  # 表示当前客户端需要将当前http连接进行升级为websocket
Origin: http://127.0.0.1:8080
Sec-WebSocket-Version: 13   # websocket版本
Sec-WebSocket-Key: xRs5MkGTBlDYDzJQBQPSdw==    # 秘钥
Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits   # 客户端支持压缩类型; 窗口大小
```



服务端响应:

```http
HTTP/1.1 101 Switching Protocols     # 浏览器收到后将切换协议
upgrade: websocket
connection: upgrade
sec-websocket-accept: Ml86JBzRotL1NR1XlrgBMaX4fcY= # base64(sha1(requestKey+258EAFA5-E914-47DA-95CA-C5AB0DC85B11))
sec-websocket-extensions: permessage-deflate  # 所选择的压缩格式
```



## Netty中的引用计数

> 当实现了ReferenceCounted 接口则表明将使用引用计数的方式来管理对象.
>
> 
>
> ReferenceCounted对象实例化时,refCnt 为1; (实际ReferenceCountUpdater 为2) 
>
> 减为0时表示对象将会被回收,访问是将会异常
>
> 
>
> 一般使用ReferenceCountUtil 工具类来操作对象的计数信息

ReferenceCounted 方法如下:

```java
// 返回refCnt: 0表示对象将被回收,无法访问
int refCnt();

// refCnt + 1
ReferenceCounted retain();
// refCnt + increment
ReferenceCounted retain(int increment);
// 记录当前访问的位置,当对象泄露时将会输出调用栈
ReferenceCounted touch();
// 附加对象信息
ReferenceCounted touch(Object hint);

// refCnt - 1
boolean release();
// refCnt - decrement
boolean release(int decrement);
```



### AbstractReferenceCountedByteBuf 

> AbstractReferenceCountedByteBuf extends AbstractByteBuf
>
> 引用计数的抽象基类



```java
// 用于修改refCnt的原子类, 底层调用Unsafe
private static final ReferenceCountUpdater<AbstractReferenceCountedByteBuf> updater =
        new ReferenceCountUpdater<AbstractReferenceCountedByteBuf>() {...}

private volatile int refCnt;

protected AbstractReferenceCountedByteBuf(int maxCapacity) {
    super(maxCapacity);
    updater.setInitialValue(this); // 初始化设置2
}

@Override
public boolean release() { // 减少1 (实际为2)
    return handleRelease(updater.release(this));
}

@Override
public boolean release(int decrement) { // 减少指定数量
    return handleRelease(updater.release(this, decrement));
}

private boolean handleRelease(boolean result) {
    if (result) {
        deallocate();  // 调用子类回收对象
    }
    return result;
}
```



### ReferenceCountUpdater

上面的updater操作实际上都对应在这个类中

> 该类对refCnt操作中,如果是执行 计数加n,实际上是加2n.  
>
> 减少n ,也对应这减少2n, 当n为0或1时表示对象将会被回收.
>
> 
>
> 该类中:如果refCnt 为偶数, 不为0 说明还未回收.  为1 或0 说明应该被回收



执行retain方法如下:

```java
// retain默认方法
public final T retain(T instance) {
    return retain0(instance, 1, 2);  // 注意这里传入的参数
}

public final T retain(T instance, int increment) {
    // 实际上更新为increment的2倍
    int rawIncrement = checkPositive(increment, "increment") << 1;
    return retain0(instance, increment, rawIncrement);
}

// rawIncrement == increment << 1
private T retain0(T instance, final int increment, final int rawIncrement) {
    int oldRef = updater().getAndAdd(instance, rawIncrement); // 更新为2倍
    // 判断是否为偶数, 该类中注释 解释用 == 比 用 & 效率高
    if (oldRef != 2 && oldRef != 4 && (oldRef & 1) != 0) { 
        throw new IllegalReferenceCountException(0, increment);
    }
    // don't pass 0!  ,  非法修改
    if ((oldRef <= 0 && oldRef + rawIncrement >= 0)
            || (oldRef >= 0 && oldRef + rawIncrement < oldRef)) {
        // overflow case
        updater().getAndAdd(instance, -rawIncrement);
        throw new IllegalReferenceCountException(realRefCnt(oldRef), increment);
    }
    return instance;
}
```



release 方法如下:

减少指定数量

```java
public final boolean release(T instance, int decrement) {
    int rawCnt = nonVolatileRawCnt(instance); // 读取refCnt的值
    int realCnt = toLiveRealRefCnt(rawCnt, checkPositive(decrement, "decrement")); // rawCnt >>> 1
    // 当decrement 为1、realCnt为0 时，表示最后一次释放，即调用tryFinalRelease0，否则调用nonFinalRelease0
    return decrement == realCnt ? tryFinalRelease0(instance, rawCnt) || retryRelease0(instance, decrement)
            : nonFinalRelease0(instance, decrement, rawCnt, realCnt);
}
// 最后一次释放值,将2 改为1
private boolean tryFinalRelease0(T instance, int expectRawCnt) {
    return updater().compareAndSet(instance, expectRawCnt, 1); // any odd number will work
}

// 将rawCnt 除2
private static int toLiveRealRefCnt(int rawCnt, int decrement) {
    if (rawCnt == 2 || rawCnt == 4 || (rawCnt & 1) == 0) {
        return rawCnt >>> 1;
    }
    // odd rawCnt => already deallocated       已经为0 了
    throw new IllegalReferenceCountException(0, -decrement);
}
```







## 高低水位线  

通过记录待写入网络数据的大小来控制程序写入网络的速度,防止程序跟不上写入速度,拖慢客户端其他进程; 或者写入太快而让服务器无法处理.

Netty中可以通过调用`ctx.channel().isWritable();` 方法来判断程序写入状态, 进而控制写入速度.

- 当待写入网络的对象大小超过最高水位线,将会设置状态为不可写,同时触发写状态改变的事件.

- 当待写入网络的对象大小小于最低水位线时,将会设置状态为可写, 触发事件.



Netty中默认定义的水位线大小:

```java
public final class WriteBufferWaterMark {

    private static final int DEFAULT_LOW_WATER_MARK = 32 * 1024;
    private static final int DEFAULT_HIGH_WATER_MARK = 64 * 1024;
```



io.netty.channel.ChannelOutboundBuffer:

```java
private volatile int unwritable;       // 用来判断是否可写， 位运算处理 
public void addMessage(Object msg, int size, ChannelPromise promise) {
   	...
    // 修改缓冲区大小
    incrementPendingOutboundBytes(entry.pendingSize, false);
}

private void incrementPendingOutboundBytes(long size, boolean invokeLater) {
    if (size == 0) {
        return;
    }
    long newWriteBufferSize = TOTAL_PENDING_SIZE_UPDATER.addAndGet(this, size);
    // 是否超过最高水位线
    if (newWriteBufferSize > channel.config().getWriteBufferHighWaterMark()) {
        setUnwritable(invokeLater);  // 设置不可写
    }
}

// 0 --> 1: fireChannelWritability..
private void setUnwritable(boolean invokeLater) {
    for (;;) {
        final int oldValue = unwritable;
        final int newValue = oldValue | 1;
        if (UNWRITABLE_UPDATER.compareAndSet(this, oldValue, newValue)) {
            if (oldValue == 0) {
                fireChannelWritabilityChanged(invokeLater); // 触发通知: 读写事件改变
            }
            break;
        }
    }
}
```



当Entry对象被写入网络后,会调用remove方法 再次修改缓冲区大小

```java
public boolean remove() {
    Entry e = flushedEntry;
  	...

    if (!e.cancelled) {
        // only release message, notify and decrement if it was not canceled before.
        ReferenceCountUtil.safeRelease(msg);
        safeSuccess(promise);
        // 修改缓冲区大小
        decrementPendingOutboundBytes(size, false, true);
    }

    // recycle the entry
    e.unguardedRecycle();
    return true;
}

private void decrementPendingOutboundBytes(long size, boolean invokeLater, boolean notifyWritability) {
    if (size == 0) {
        return;
    }

    long newWriteBufferSize = TOTAL_PENDING_SIZE_UPDATER.addAndGet(this, -size);
    if (notifyWritability && newWriteBufferSize < channel.config().getWriteBufferLowWaterMark()) {     			// 小于低水位线
        setWritable(invokeLater);
    }
}
```



Netty 默认提供了一些自动控制高低水位线的处理器:

- ChannelTrafficShapingHandler
- GlobalTrafficShapingHandler
- 



Netty中的一些介绍:

https://yhsblog.cn/archives/netty-7#%E8%AE%BE%E7%BD%AE%E9%AB%98%E4%BD%8E%E6%B0%B4%E4%BD%8D%E7%BA%BF





## Netty内存泄露：

> 核心代码见[Netty.txt](netty.txt), sublime 打开







## NIO内存分配



### DirectByteBuffer

直接内存分配， 由DirectByteBuffer 类进行创建

```java
DirectByteBuffer(int cap) {                   // package-private
    super(-1, 0, cap, cap);
    boolean pa = VM.isDirectMemoryPageAligned();
    int ps = Bits.pageSize();
    long size = Math.max(1L, (long)cap + (pa ? ps : 0));
    Bits.reserveMemory(size, cap);

    long base = 0;
    try {
        // 分配size字节本地内存
        base = unsafe.allocateMemory(size);
    } catch (OutOfMemoryError x) {
        Bits.unreserveMemory(size, cap);
        throw x;
    }
    // 内存填充0
    unsafe.setMemory(base, size, (byte) 0);
    if (pa && (base % ps != 0)) {
        // Round up to page boundary
        address = base + ps - (base & (ps - 1));
    } else {
        address = base;
    }
    // CLeaner对象继承了PhantomReference
    cleaner = Cleaner.create(this, new Deallocator(base, size, cap));
    att = null;
}
```



### Cleaner

```java
public class Cleaner extends PhantomReference<Object> {
    // 引用队列
    private static final ReferenceQueue<Object> dummyQueue = new ReferenceQueue();
    
    private static Cleaner first = null;
    private Cleaner next = null;
    private Cleaner prev = null;
    // 清除堆外内存的任务
    private final Runnable thunk;
    
    private Cleaner(Object var1, Runnable var2) {
        super(var1, dummyQueue);
        this.thunk = var2;
    }

    public static Cleaner create(Object var0, Runnable var1) {
        return var1 == null ? null : add(new Cleaner(var0, var1));
    }
}
```

### Deallocator

```java
private static class Deallocator
    implements Runnable
{

	// 最终任务执行时， 通过run方法中的unsafe释放内存
    public void run() {
        if (address == 0) {
            // Paranoia
            return;
        }
        unsafe.freeMemory(address);
        address = 0;
        Bits.unreserveMemory(size, capacity);
    }
```





## Netty内存分配

> 由于JDK提供的ByteBuffer API灵活性不够，因此Netty对JDK提供的ByteBuffer进一步封装，提供了更易使用的ByteBuf



![image-20230507203604551](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20230507203604551.png)





https://juejin.cn/post/6922783552580878349

Jemolloc

https://juejin.cn/post/7051200855415980069#heading-10



**Bin文章：**https://mp.weixin.qq.com/s?__biz=Mzg2MzU3Mjc3Ng==&mid=2247490143&idx=1&sn=b85a1fe4be6578af8e968ef99fd6dd33&chksm=ce77dc18f900550ee7aa39c8e30c46eaabe984adf82c88a85abec5fd62d3cdf03af6928d9459&scene=178&cur_album_id=2217816582418956300#rd



默认使用**PooledByteBufAllocator**

PoolArena： per reactor thread/ fastThread,   2 * cpu

pageSize: 8K
PoolChunk：4M， 512 page

分配出去的内存也使用PoolChunk对象表示。 从PoolChunkList中的PoolChunk中切分的一个Run，一个Run对应多个连续Page。
handle：表示该内存在PoolChunk中的offset，size信息

small: 16B - 28K
normal: 32K - 4M
huge: non poll

伙伴算法：  
Linux：arr[11]:  每一级保留不同大小的内存连续空间
0: 1page, 1: 2page, 2: 4page, 3: 8page,  n: 2^n page

Netty 中对应runsAvail（IntPriorityQueue：低地址向高地址），不同的是Netty最大有32个Page级别的内存块尺寸：8K ---4M


poolSubpage：512


size2idxTab 是建立 request size(lookup size) 与内存规格 index 之间的映射关系

Netty 默认使用的JDK提供的DirectByteBuffer。   PlatformDependent#USE_DIRECT_BUFFER_NO_CLEANER指定

PoolChunk: 4M -- 512 Page
runsAvail[32]: IntPriorityQueue, 存入的handle的高32位（handle >> 32）。  每个IntPriorityQueue记录的是相同大小的Run，即page组成的Run
runsAvailMap<long,long>: one pair --> <offset, handle>
handle： size指 pageSize， runOffset跟size的高2位 合起来是requestSize？ io.netty.buffer.PoolChunk#runSize

4.1.123:
runSize: 表示当前的handle的内存，int(runOffset-size) << 13
runPage: runOffset|size, 高30bit ，  handle << 34
pageShifts:13



Netty **伙伴算法**： 32种规格大小的， 8K ~ 4M， 没一个规格都是 8K 的倍数， 而Linux中的伙伴算法每种规格是 4K * 2^n。
    每一个位置表示的不同数量page的连续空间，如0：1page(8K)，1: 2 page (16K), 2: 3 page (25 K), 31: 32 page(4M) 



```shell

网络协议采用**大端**字节序传输，所以 Netty 的 ByteBuf 默认也是大端字节序。

cleaner:  DirectByteBuffer(int)，  内存限制：MaxDirectMemorySize
noCleaner: 使用unsafe#allocateMemory分配内存， 调用JDK 的DirectByteBuffer(long,long)的构造对象,无cleaner。 内存限制：io.netty.maxDirectMemory，没有配置则使用JDK 的MaxDirectMemorySize
要使用noCleaner必须显示开启Netty使用反射：-Dio.netty.tryReflectionSetAccessible=true， 开启后默认Netty 即使用noCleaner


无论 Netty 中的 DirectByteBuf 有没有 Cleaner， Netty 都会选择手动的进行释放，目的就是为了避免 GC 的延迟 ， 从而及时的释放 Direct Memory。
io.netty.buffer.PoolArena.DirectArena#destroyChunk: 有Cleaner用Cleaner释放，没有直接Unsafe#freeMemory释放
```



### 分配内存：

PooledByteBufAllocator#heapBuffer/directBuffer： 分配指定初始大小的内存

1. 创建PoolThreadCache分配内存： 包含了heapArena/directArena; small/normal cache.   注解：实现的jemalloc
   - threadCache#initialValue: 从CPU 个 Arena中获取使用最少的一个Arena（direct/heap），numThreadCaches记录了Arena被多少个线程cache过. 
2. 从cache中拿出arena， 执行directArena#allocate分配内存
   Recycle得到对象PooledUnsafeDirectByteBuf(no unsafe:PooledDirectByteBuf), 内部有一个recycleHandle#LocalPool
     1. 初始化ByteBuf信息：引用计数2，read、write pos 为0
     2. 根据内存大小，走small、normal、huge逻辑（直接OS分配）。
     3. small、normal：首先从TheadLocal缓存中分配。
     4. 缓存分配失败：依次从PoolChunkList：q050、q025、q000、qInit、q075分配（主要是为了保证性能，减少PoolChunk创建、回收）。 遍历每个List中的 PoolChunk
     5. PoolChunkList分配失败，创建一个PoolChunk放入qInit
        new PoolChunk： 默认使用JDK的DirectByteBuffer分配内存（默认一个PoolChunk 4M）
     6. 从PoolChunk中分配一个Run， 封装内存信息到ByteBuf对象中
3. toLeakAwareBuffer： 包装ByteBuf对象，通过引用计数检查内存泄漏信息



当调用allocator.directBuffer(int initialCapacity),分配ByteBuf后，如果写入的数据超过了initialCapacity，底层会调用capacity(newCapacity) 向分配器重新申请一块新的内存，将原来的内存的数据复制到新申请的内存上，最后释放原来的内存。



### 内存回收

1. PoolArena#free： 将内存信息回收到Arena中
2. 如果是Huge，即Unpool，直接释放OS
3. 如果内存信息可以保存到PoolThreadCache中，那么就存放到cache中。（所有small，normal 32K 支持缓存）
   - PoolThreadCache中的内存释放：
     - cacheTrimInterval 8192： 从当前缓存分配次数到达8192 时，强制对缓存回收到PoolChunk
     - cacheTrimIntervalMillis： 启动定时任务，定时回收cache中的内存。默认关闭
4. 如果缓存无法存放，那么将内存信息放回PoolChunk中。
   1. PoolChunk的内存回收到PoolChunkList时，会判断PoolChunk的使用率是否满足当前PoolChunkList范围值，如果不满足则需要将该PoolChunk移动到其他PoolChunkList. 
   2. 如果PoolChunk属于 q000 [1% , 50%)，但是当前使用率达到了0， 需要将该PoolChunk释放回OS

Netty的qInit保证了内存池至少有一个 PoolChunk（qInit中的PoolChunk不会被释放， 如果都没有在qInit 应该也可能释放完），避免不必要的重复创建 PoolChunk







### 内存监控

```java
PooledByteBufAllocator allocator = (PooledByteBufAllocator) ByteBufAllocator.DEFAULT;
allocator.metric().usedDirectMemory();
allocator.metric().usedHeapMemory();
allocator.metric().chunkSize(); // 默认每个Chunk 4M
```







## Netty工具类

### FastThreadLocal

- 性能、内存： FastThreadLocal 对象初始化确定一个index作为map的记录位置，插入，查找都使用这个位置。 全局使用的一个object数组（indexedVariables）， 只存val。
  - 而ThreadLocal 每次访问都需要计算（hash值实际上初始化就确定了，访问只需要 异或确定位置）, 全局使用一个 Entry（key,val)数组。  采用线性探测（类似IdentityHashMap）

- Netty默认创建的线程都是使用的DefaultThreadFactory，都是FastThreadLocalThread.  执行任务都会包装 FastThreadLocalRunnable， 结束自动removeAll，防止内存泄漏



全局index，如果比较大， 在新线程生成的 indexedVariables 可能很长，前面可能都是空

- 如果有100个FastThreadLocal，索引应该到100.  当这些remove后， 新的FastThreadLocal索引依然是101， 这导致object数组前面的一直空着了。  **空间换时间** 由于空位置存的是空对象引用，一个占8bit，即使100个位置也用不了多少内存

```java
    
InternalThreadLocalMap：  indexedVariables[], store value to index 
0：Set ：FastThreadLocal, used remove 
1：Obj

FastThreadLocal：--> index  (indexedVariables index， atomic++)

```

![image-20260421215947211](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260421215947211.png)

### Recycler

轻量级的一个内存池，在Netty分配内存对象的时候会使用到，避免了频繁的new对象



**创建线程** 直接在stack 中element数组中取对象，回收。



如果对象交给了其他线程回收将会创建一个WeakOrderQueue链表接口进行处理。

![image-20260421181256854](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260421181256854.png)





变量：

interval：8， 控制回收线程的回收频率。每 8 个对象回收 1 个，设置为0则每次都会回收。

![image-20260421164617003](https://cdn.jsdelivr.net/gh/xiaoye-2018/code-note@master/netty/netty.assets/image-20260421164617003.png)







#### 新版：

重构Recycle ，更加简洁高效。 原来的WeakOrderQueue那套逻辑已经移除

- LocalPool  类似原来的Stack
- LocalPool #pooledHandles 类似原来的 Stack#element       

不管是创建线程，还是回收线程 回收对象直接在**pooledHandles** 中处理。不在需要单独为回收线程创建额外的队列。

```java
threadLocalPool = new FastThreadLocal<LocalPool<?, T>>() {
    @Override
    protected LocalPool<?, T> initialValue() {
        // unguarded: 默认false
        return unguarded? new UnguardedLocalPool<>(finalMaxCapacityPerThread, interval, finalChunkSize) :
                new GuardedLocalPool<>(finalMaxCapacityPerThread, interval, finalChunkSize);
    }

    @Override
    protected void onRemoval(LocalPool<?, T> value) throws Exception {
        super.onRemoval(value);
        MessagePassingQueue<?> handles = value.pooledHandles;
        value.pooledHandles = null;
        value.owner = null;
        if (handles != null) {
            handles.clear();
        }
    }
};

private abstract static class LocalPool<H, T> {
        private final int ratioInterval;
        private final H[] batch;
        private int batchSize;
        private Thread owner;
    // jctools 中： MpmcAtomicArrayQueue
        private MessagePassingQueue<H> pooledHandles;
        private int ratioCounter;
}
```



对于虚拟线程直接创建新对象，不在使用对象池管理。因为虚拟线程比较轻量，存活时间短，为其缓存对象没有太大意义。

```java
   public final T get() {
        if (localPool != null) {
            return localPool.getWith(this);
        } else {
            if (PlatformDependent.isVirtualThread(Thread.currentThread()) &&
                !FastThreadLocalThread.currentThreadHasFastThreadLocal()) {
                return newObject((Handle<T>) NOOP_HANDLE);
            }
            return threadLocalPool.get().getWith(this);
        }
    }
```



### HashedWheelTimer

使用单层时间轮，使用**相对时间**计算。  任务首先添加到一个MPSC队列中，内部线程在轮转ticket时，会将MPSC队列的任务加入到 时间轮的位置上。  

由于只有一个时间轮，因此 wheel中的每个位置会放不同到期时间的任务：1 + n * （ ticketDuration * ticksPerWheel），

ticketDuration * ticksPerWheel： 表示一圈的ticket时间。  ticketDuration  一个刻度 表示多久(100ms)，ticksPerWheel 一圈多少个位置 (512)



底层单线程实现时间轮的轮转， 任务的执行可以交个线程池（默认使用轮转线程）



优势：插入、取消 O(1). 

缺点：任务较少时，时间轮的空推进现象 。    以及无法应对海量延时跨度比较大的定时任务场景。 某个位置上处理任务 遍历 O(n)， 任务太多可能有损性能



Netty 内部并没有使用这个工具类。 相关定时任务直接交给了reactor 线程执行（每次检查DelayQueue 顶端的任务是否到期），如心跳相关ReaderIdleTimeoutTask。  

在Redisson中，watchdog使用了这个工具类。 以及dubbo中也有使用





**Kafka时间轮**

采用多层实现，类似钟表，秒、分、时。 内部采用**绝对时间**计算



Kafka 通过引入 DelayQueue 以及多层时间轮，巧妙地解决了时间轮的空推进现象和海量延时任务时间跨度大的管理问题



如果时间轮很长一段时间空闲（**currentTimeMs** 一直没变，已经属于很久以前），突然提交一个任务，可能导致新建多层时间轮（其实也加不了几个）。

为了避免这种情况，可以定时像时间轮提交一个任务，使 时间轮定时推动 **currentTimeMs** 





## Netty 4.2 架构

参考：https://dreamlike-ocean.github.io/blog/netty-4-2.html

SingleThreadEventLoop#run 替换为：io.netty.channel.nio.NioIoHandler#run

官方提供的example bossGroup已经不在作为单独的`NioEventLoop`，而是与Worker使用同一个NioEventLoop
