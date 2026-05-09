
## JFR
JDK 提供的轻量级监控工具，随时可以开启、暂停。 

不建议打开 -XX:+HeapDumpOnOutOfMemoryError
directBytebuf、mmap、fd exceed 分配出现的OOM 无法dump 文件， 同时dump 需要STW，写入dump文件到磁盘需要花费大量的事件。 


JFR 以滚动的方式持续写入文件到Repository，一个chunk写满后（默认12M）开启一个新文件。 当执行 JFR.check JFR.dump 也会切换chunk
当JVM 停止、或使用jcmd停止、dump命令时，才会将chunk文件合并到最终的一个文件下

最佳实战： 
```shell
# disk=true： 记录到磁盘，默认true
# maxsize=5000m，Repository所有文件最大大小
# maxage： Repository文件最大保留时间
# maxchunksize: chunck达到 128M写入一次磁盘，默认12M
# dumpOnExit: jvm 退出时dump 
# preserve-repository=true,保留 repository 目录中的 chunk 文件（默认情况下，JFR 会在 JVM 退出时删除 repository 目录中的 chunk 文件）
-XX:StartFlightRecording=disk=true,maxsize=5000m,maxage=2d,dumpOnExit=true,filename=JFRdump文件名-%t.jfr
-XX:+FlightRecorder
-XX:FlightRecorderOptions=maxchunksize=128m,repository=/jfr临时文件目录,preserve-repository=true
-XX:OnOutOfMemoryError="curl -X POST http://registry/unregister?service=my-service; cp /jfr临时文件目录 /容器挂载目录;"
-XX:+ExitOnOutOfMemoryError
```

JCMD命令：

```shell
# 开启录制，名字叫 MyRecording，默认1.   settings默认用default。 
jcmd <pid> JFR.start name=MyRecording settings=profile filename=./out.jfr

# 中途导出快照
jcmd <pid> JFR.dump name=MyRecording filename=/tmp/snapshot1.jfr
# 动态配置
jcmd <pid> JFR.configure name=MyRecording dumppath=<path>

# 停止录制
jcmd <pid> JFR.stop name=MyRecording

# 查看进程录制状态, 输出配置的事件
jcmd <pid> JFR.check verbose=true

# 查看视图：gc、hot-methods,jdk.GarbageCollection
jcmd <pid> JFR.view gc

```

当使用StartFlightRecording 参数启动后，控制台会输出相关信息. 可以复制命令进行操作。
```text
// jdk 25 才有详细输出
[0.577s][info][jfr,startup] Started recording 1. No limit specified, using maxsize=250MB as default.
[0.577s][info][jfr,startup] 
[0.577s][info][jfr,startup] Use jcmd 148608 JFR.dump name=1 to copy recording data to file.
```



default settings:
D:\environment\jdk-21_windows-x64_bin\jdk-21.0.2\lib\jfr

## TLAB
> Thread Local Allocation Buffer， https://zhuanlan.zhihu.com/p/346588079

java 中new 的对象大部分时在TLAB分配， 还有一部分在栈上分配 或者是 堆上直接分配，可能 Eden 区也可能年老代。

同时，对于一些的 GC 算法，还可能直接在老年代上面分配，例如 G1 GC 中的 humongous allocations（大对象分配），就是对象在超过 Region 一半大小的时候，直接在老年代的连续空间分配。

TLAB默认开启：如需关闭-XX:-UseTLAB

线程初始化的时候，如果 JVM 启用了 TLAB，则会创建并初始化 TLAB.

在 TLAB 已经满了或者接近于满了的时候，TLAB 可能会被释放回 Eden。GC 扫描对象发生时，TLAB 会被释放回 Eden。TLAB 的生命周期期望只存在于一个 GC 扫描周期内。在 JVM 中，一个 GC 扫描周期，就是一个epoch

TLAB 的最小大小：通过MinTLABSize指定

在 TLAB 内存充足的时候分配对象就是快分配，否则在 TLAB 内存不足的时候分配对象就是慢分配，慢分配可能会发生两种处理：

1. 线程获取新的 TLAB。老的 TLAB 回归 Eden，之后线程获取新的 TLAB 分配对象。
    TLAB 剩余大小 **小于** 最大浪费空间
2. 对象在 TLAB 外分配，也就 Eden 区。
      TLAB 剩余大小 **大于** 最大浪费空间






## 知乎文章总结
1. 随机数尽量配置urandom、 默认random 在熵不够的时候容易发生阻塞。

   linux生成随机数命令：cat /dev/random | head -c 13 ; echo ''
    ``` shell 
   # 生成13为指定字符随机数
    [root@k8s-node1 dev]# tr -dc A-Za-z0-9 </dev/random | head -c 13 ; echo ''
    kkHMXCbpSGxoX
    ```
2. Chunk采集不要以everyChunk作为单位 ， 尽量配置固定时间采集， 防止出现某个采集雪崩导致不断切换chunk导致无限采集这个问题。
3. ObjectAllocationInNewTLAB
    > jdk 11 引入， 配置项少，只有enabled、stackTrace。

    一旦TLAB 发生重分配就会生成该事件，对性能损坏较大。可以开发额外的代码实现动态采集，或者使用 `ObjectAllocationSample`
4. ObjectAllocationOutsideTLAB
   > jdk 11 引入，类似 ObjectAllocationInNewTLAB，开销大，不建议开启。
3. ObjectAllocationSample 
   > jdk 16 引入
   >
   weight：线程距离上次记录 jdk.ObjectAllocationSample 事件到当前这个事件时间内，线程分配的对象大小。
   
5. ThreadAllocationStatistics
   
   在统计线程分配大小时，不需要进入安全点。因此不太消耗性能。
   默认采集周期everyChunk，默认的 chunk 大小（maxchunksize）是 12M，也就是每采集 12M 的 JFR 事件之后，采集一次 jdk.ThreadAllocationStatistics。
   这是不太可控的，我一般配置为每过 5s 采集一次。这样对于我们上面提到的那两个需要这个事件的场景也是很适合的。



6. ExecutionSample /NativeMethodSample 
   > 默认都是20ms 采集一次，ExecutionSample 采集Java 线程(每次5个线程)， NativeMethodSample 采集native 线程（每次1个）
   > 
   > 消耗并不是太大，一般用于构建火焰图分析CPU瓶颈
   > 全局基本不加锁，也没有加安全点
   >
   
   **async profile** 对于原生方法更详细，对于 Java 方法一般需要 JVM 启动的时候打开 -XX:+UnlockDiagnosticVMOptions -XX:+DebugNonSafepoints，否则只能采集到 Java 安全点时候的方法。
  
   因为默认 JVM 为了提高性能，只在安全点的时候添加 Debug 信息用于定位问题带上方法调用信息，加上前面的 -XX:+DebugNonSafepoints 会去掉限制，在所有位置加上 Debug 信息以及日志记录，这样 async profiler 才能采集到详细的 Java 方法调用信息。所以整体上 async profiler 的采样方式更详细，但是消耗也更大。

   建议是，长期开着 JFR，遇到问题优先回溯 JFR，如果 JFR 无法定位问题，再使用 async profiler。


jdk.ObjectAllocationOutsideTLAB：当一个对象分配请求无法在 TLAB（Thread-Local Allocation Buffer）中满足时触发，只有分配成功的才会被记录到这个事件中。通过这个事件，可以明显看出 JDK 内部容器的扩容趋势，从而定位到内存泄漏的代码位置。
jdk.AllocationRequiringGC： 当一个对象分配请求无法在堆中满足时触发，这通常是因为堆内存不足以容纳该对象。JVM 会尝试触发垃圾回收（GC）以释放内存，然后重新尝试分配。如果 GC 后仍然无法满足分配请求，JVM 会抛出 OutOfMemoryError 异常。这个事件无论是否分配成功都会记录。通过这个事件，可以大概率在非 ZGC、ShenandoahGC 的 GC 情况下看到一次性的大内存请求异常导致的 Java 堆 OOM。
jdk.ZAllocationStall ： 当使用 ZGC 时，如果一个对象分配请求无法在堆中满足，通常发生在 GC 回收速度不满足分配速度的时候。这个事件无论是否分配成功都会记录。通过这个事件，可以大概率在 ZGC 的 GC 情况下看到一次性的大内存请求异常导致的 Java 堆 OOM。




## 实现
jdk.jfr.internal.PlatformRecorder.startDiskMonitor
threadName: JFR Periodic Tasks， 默认1s (flush-interval)检查下是否需要创建新的chunk (12MB)。是否有event需要flush 到global buffer

JFR Recorder Thread： JVM 创建的线程, 负责把内存缓冲区数据真正写到磁盘 chunk 文件。 JVM 底层工作

JFR Event Stream: 提供了流式处理 JFR 事件的能力

```java
public final class FlightRecorder {
    // 全局唯一
    private static volatile FlightRecorder platformRecorder;
    private static volatile boolean initialized;
    private final PlatformRecorder internal;
}

public final class PlatformRecorder {

    private static volatile boolean inShutdown;
    private final ArrayList<PlatformRecording> recordings = new ArrayList<>();
    private static final List<FlightRecorderListener> changeListeners = new ArrayList<>();
    // 管理 chunk 
    private final Repository repository;
    private final Thread shutdownHook;
    private Timer timer;
    private long recordingCounter = 0;
    private RepositoryChunk currentChunk;
    private boolean runPeriodicTask;
}

public final class PlatformRecording implements AutoCloseable {
   private final PlatformRecorder recorder;
   private final long id;
   // Recording settings: jdk.ThreadSleep#enabled -> true
   private Map<String, String> settings = new LinkedHashMap<>();
   private Duration duration;
   private Duration maxAge;
   private long maxSize;

   private WriteablePath destination;

   private boolean toDisk = true;
   private String name;
   private boolean dumpOnExit;
   private Path dumpDirectory;
   // Timestamp information
   private Instant stopTime;
   private Instant startTime;

   // Misc, information
   private RecordingState state = RecordingState.NEW;
   private long size;
   private final LinkedList<RepositoryChunk> chunks = new LinkedList<>();
   private final List<Report> reports = new ArrayList<>();
   private volatile Recording recording;
}

```