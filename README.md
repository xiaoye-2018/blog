# 个人技术笔记 · Tech Notebook

> Java 后端工程师 | 持续记录、深度整理的技术知识库

---

## 关于本仓库

日常开发与学习中积累的技术笔记，覆盖 Java 生态、Spring 框架源码、并发编程、网络、爬虫及逆向等领域。笔记以 Markdown 格式组织，图文并茂，包含大量 draw.io 绘制的架构图和流程图。

---

## 技术栈全景

### ☕ Java 核心

深入 JDK 源码，聚焦并发与集合：

- **线程池** — 设计与调优
- **ThreadLocal & TTL** — FastThreadLocal、TransmittableThreadLocal
- **JUC 并发** — AQS、ReentrantReadWriteLock、ConcurrentHashMap、ConcurrentLinkedQueue、ConcurrentSkipListMap、LinkedTransferQueue、Fork-Join
- **集合框架** — HashMap 源码（含红黑树转换）、List / Map / Set、Stack & Queue
- **SPI 机制** — ServiceLoader 原理

📂 [java/](java/)

### 🆕 JDK 新特性

- **Virtual Thread** — 虚拟线程、Continuation 模型、Pinning 场景
- **JFR** — Java Flight Recorder 配置与实战

📂 [java/jdk21-virtual-thread.md](java/jdk21-virtual-thread.md) · [java/jfr.md](java/jfr.md)

### 🏗 Spring 生态

基于源码级别的深度分析：

- **Spring 源码** — IoC 容器、Bean 生命周期
- **Spring MVC** — DispatcherServlet 请求处理链
- **Spring Boot** — 自动装配原理、启动流程
- **Spring AOP** — 代理机制、切面编程
- **Spring Cloud** — 微服务全家桶
- **Spring Cache & Redis** — TTL / TTI 精细化配置
- **Spring WebFlux** — Reactor 模型、背压机制
- **Spring Data JPA / Hibernate** — 源码解析
- **MyBatis-Plus** — 插件机制、缓存

📂 [后端框架/](%E5%90%8E%E7%AB%AF%E6%A1%86%E6%9E%B6/)

### 📨 网络 & 中间件

- **Netty** — Reactor 模型、Pipeline、ByteBuf 源码分析
- **HTTP 协议** — curl 诊断、HTTP/2

📂 [netty/](netty/) · [2025/HTTP.md](2025/HTTP.md)

### 🐍 爬虫 & 脚本

- Python 爬虫、Scrapy、验证码识别

📂 [爬虫/](%E7%88%AC%E8%99%AB/)

### 🔬 逆向工程

- Android 逆向（ADB 抓包）、Windows 逆向

📂 [逆向/](%E9%80%86%E5%90%91/)

### 📦 其他

- **Go** — 基础语法、Beego 框架
- **Rust** — 学习笔记
- **编译 V8** — Chromium V8 编译实践

📂 [2025/go.md](2025/go.md) · [杂项/rust.md](%E6%9D%82%E9%A1%B9/rust.md) · [杂项/编译v8.md](%E6%9D%82%E9%A1%B9/%E7%BC%96%E8%AF%91v8.md)

---

## 使用方式

```bash
git clone https://github.com/xiaoye-2018/tech-blog
```

推荐使用 [Obsidian](https://obsidian.md/) 打开，图片与内部链接可正常跳转；也可使用任意 Markdown 编辑器或 VS Code 浏览。

笔记中包含大量 `.drawio` 源文件，可使用 [draw.io](https://draw.io) 桌面版或 VS Code 插件打开编辑。

---

*持续更新中 · Last updated: 2026*
