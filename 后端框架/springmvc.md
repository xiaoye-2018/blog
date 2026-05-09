

# Tomcat 请求流程

## Servlet转发来源

StandardWrapper: servletClass

核心入口：

StandardWrapperValve#invoke:

   1. 获取Servlet对象（初始化时会调用init)
      ![image-20231028152729281](springmvc.assets/image-20231028152729281.png)
   2. 创建FilterChain对象。 ApplicationFilterChain 对象本身不需要每次创建 (跟随Http11Processor#request 缓存)，但是每次需要重context中重新构造该url所属filter。
      ![image-20231028152754927](springmvc.assets/image-20231028152754927.png)
   3. 调用filter链，doFilter方法（filter对象初始化会调用filter#init()）
   4. doFilter方法调用完毕后，调用servlet#service()

      ```java
      doFilter(RequestFacade, ResponseFacade)
      RequestFacade: 作为一个门面，实际执行都是由内部的connector.Request(内部还有coyoteRequest)对象执行
      ```

      



![image-20231028152958058](springmvc.assets/image-20231028152958058-1778295183212-2.png)



## ServletContainerInitializer

```java
SPI:
javax.servlet.ServletContainerInitializer  #onStartup(ServletContext container)
该接口在web应用程序启动阶段接收通知，注册servlet、filter、listener等



META-INF/services/javax.servlet.ServletContainerInitializer， spring-web： SpringServletContainerInitializer


@HandlesTypes(WebApplicationInitializer.class)
SpringServletContainerInitializer


ContextConfig#processServletContainerInitializers: 
    SPI 加载ServletContainerInitializer.class
    initializerClassMap: <SCI, Set>：  SpringServletContainerInitializer == set
    typeInitializerMap: <@HandleTypes, SCI set>,  
                         [WebApplicationInitializer, SpringServletContainerInitializer]

ContextConfig#processClasses:  处理@HandlesTypes
    会将自定义的WebApplicationInitializer(上面@HandleTypes)的子类 加入到initializerClassMap#set
      SpringServletContainerInitializer -->  AbstractContextLoaderInitializer、AbstractDispatcherServletInitializer、AbstractAnnotationConfigDispatcherServletInitializer、CustomerServletInitializer
      后续会排除掉抽象类

    
Call ServletContainerInitializers：
StandardContext#addServletContainerInitializer: 将上面SCI 实现类添加到initializers（等价于initializerClassMap）


onStartup():
StandardWrapper#startInternal:
--->StandardContext#startInternal：
      --> 遍历initializers entrykey，调用onStartup(sci set, servletContext)

          SpringServletContainerInitializer#onStartup():
            --> 遍历sci set, 过滤出非抽象类，剩下CustomerServletInitializer
            --> 调用onStartup
```



# Spring MVC

Tomcat调用SCI的时机：  https://blog.csdn.net/f641385712/article/details/89231174

SpringMVC、Servlet容器创建：https://blog.csdn.net/f641385712/article/details/87474907

启动过程：https://blog.csdn.net/f641385712/article/details/87883205

DispatcherServlet处理过程：https://fangshixiang.blog.csdn.net/article/details/87982095





ServletContext(ApplicationContextFacade)： 持有MVC Container， Root Container （AnnotationConfigWebApplicationContext）

dispatcherServlet： 持有MVC container （AnnotationConfigWebApplicationContext）

MVC container： 持有 ServletContext



转发请求过程：

![image-20210327165457678](springmvc.assets/image-20210327165457678-1778295183213-3.png)



## SCI启动过程

> SpringBoot 内嵌tomcat不会执行该扫描过程

spring mvc 包中有：META-INF\services\javax.servlet.ServletContainerInitializer

```
org.springframework.web.SpringServletContainerInitializer
```

tomcat初始化时会扫描该路径，将文件解析出来，后续依次调用onStartup()

![image-20230103211726022](springmvc.assets/image-20230103211726022-1778295183213-4.png)



![image-20230103211019242](springmvc.assets/image-20230103211019242-1778295183213-5.png)

![image-20230103211033652](springmvc.assets/image-20230103211033652-1778295183213-6.png)



![image-20230103211251750](springmvc.assets/image-20230103211251750-1778295183213-7.png)





ContextLoaderListener#contextInitialized：

![image-20230103221054985](springmvc.assets/image-20230103221054985-1778295183213-8.png)

![image-20230103221132656](springmvc.assets/image-20230103221132656-1778295183213-9.png)





## DispatcherServlet

![image-20230102205730174](springmvc.assets/image-20230102205730174-1778295183213-10.png)



### init()

核心： 会设置WebApplicationContext的父容器RootApplicationContext

FrameworkServlet#initWebApplicationContext

```java
protected WebApplicationContext initWebApplicationContext() {
	// 从ServletContext中把上面已经创建好的根容器拿到手
	WebApplicationContext rootContext = WebApplicationContextUtils.getWebApplicationContext(getServletContext());
	WebApplicationContext wac = null;
	
	//但是，但是，但是此处需要注意了，因为本处我们是注解驱动的，在上面已经看到了，我们new DispatcherServlet出来的时候，已经传入了根据配置文件创建好的子容器web容器，因此此处肯定是不为null的，因此此处会进来，和上面一样，完成容器的初始化、刷新工作，因此就不再解释了~
	if (this.webApplicationContext != null) {
		// A context instance was injected at construction time -> use it
		wac = this.webApplicationContext;
		if (wac instanceof ConfigurableWebApplicationContext) {
			ConfigurableWebApplicationContext cwac = (ConfigurableWebApplicationContext) wac;
			if (!cwac.isActive()) {
				if (cwac.getParent() == null) {
					//此处吧根容器，设置为自己的父容器
					cwac.setParent(rootContext);
				}
				//根据绑定的配置，初始化、刷新容器
				configureAndRefreshWebApplicationContext(cwac);
			}
		}
	}

	//若是web.xml方式，会走这里，进而走findWebApplicationContext(),因此此方法，我会在下面详细去说明，这里占时略过
	if (wac == null) {
		wac = findWebApplicationContext();
	}
	if (wac == null) {
		wac = createWebApplicationContext(rootContext);
	}

	// 此处需要注意了：下面有解释，refreshEventReceived和onRefresh方法，不会重复执行~
	if (!this.refreshEventReceived) {
		onRefresh(wac);
	}

	//我们是否需要吧我们的容器发布出去，作为ServletContext的一个属性值呢？默认值为true哦，一般情况下我们就让我true就好
	if (this.publishContext) {
		// Publish the context as a servlet context attribute.
		// 这个attr的key的默认值，就是FrameworkServlet.SERVLET_CONTEXT_PREFIX，保证了全局唯一性
		// 这么一来，我们的根容器、web子容器其实就都放进ServletContext上下文里了，拿取都非常的方便了。   只是我们一般拿这个容器的情况较少，一般都是拿跟容器，比如那个工具类就是获取根容器的~~~~~~
		String attrName = getServletContextAttributeName();
		getServletContext().setAttribute(attrName, wac);
	}
	return wac;
}
```





DispatcherServlet.properties： 默认配置





### 初始化Handler：

RequestMappingHandlerMapping#afterPropertiesSet

AbstractHandlerMethodMapping#initHandlerMethods：

![image-20230106113527262](springmvc.assets/image-20230106113527262-1778295183213-11.png)

AbstractHandlerMethodMapping#detectHandlerMethods

![image-20230106114004047](springmvc.assets/image-20230106114004047-1778295183213-12.png)

![image-20230106114023946](springmvc.assets/image-20230106114023946-1778295183213-13.png)

![image-20230106115342152](springmvc.assets/image-20230106115342152-1778295183213-14.png)



registry：

MappingRegistry 中保存Handler信息：

```java
private final Map<T, MappingRegistration<T>> registry = new HashMap<>();

private final Map<T, HandlerMethod> mappingLookup = new LinkedHashMap<>();

private final MultiValueMap<String, T> urlLookup = new LinkedMultiValueMap<>();

private final Map<String, List<HandlerMethod>> nameLookup = new ConcurrentHashMap<>();

private final Map<HandlerMethod, CorsConfiguration> corsLookup = new ConcurrentHashMap<>();

private final ReentrantReadWriteLock readWriteLock = new ReentrantReadWriteLock();
```



### 请求寻找handler过程

![image-20230106120530414](springmvc.assets/image-20230106120530414-1778295183213-15.png)

![image-20230106120556464](springmvc.assets/image-20230106120556464-1778295183213-16.png)

![image-20230106122706044](springmvc.assets/image-20230106122706044-1778295183213-17.png)



![image-20230106122413693](springmvc.assets/image-20230106122413693-1778295183213-18.png)



![image-20230106121507487](springmvc.assets/image-20230106121507487-1778295183213-19.png)

### 九大组件

https://blog.csdn.net/f641385712/article/details/87934909



在WebApplicationContext#refresh 中，调用finishRefresh()，会发布事件：

![image-20230106120102679](springmvc.assets/image-20230106120102679-1778295183213-22.png)

最终执行到，DispatcherServlet，初始化9大组件：

![image-20230104140442380](springmvc.assets/image-20230104140442380-1778295183213-21.png)





## @RestControllerAdvice

![image-20230109170723856](springmvc.assets/image-20230109170723856-1778295183213-20.png)



ExceptionHandlerExceptionResolver： 会解析@ExceptionHandler 方法



## SpringBoot 整合MVC

Tomcat 容器会持有该Servlet 容器

```java
@Bean(name = DEFAULT_DISPATCHER_SERVLET_BEAN_NAME)
public DispatcherServlet dispatcherServlet(WebMvcProperties webMvcProperties) {
    DispatcherServlet dispatcherServlet = new DispatcherServlet();
    dispatcherServlet.setDispatchOptionsRequest(webMvcProperties.isDispatchOptionsRequest());
    dispatcherServlet.setDispatchTraceRequest(webMvcProperties.isDispatchTraceRequest());
    dispatcherServlet.setThrowExceptionIfNoHandlerFound(webMvcProperties.isThrowExceptionIfNoHandlerFound());
    dispatcherServlet.setPublishEvents(webMvcProperties.isPublishRequestHandledEvents());
    dispatcherServlet.setEnableLoggingRequestDetails(webMvcProperties.isLogRequestDetails());
    return dispatcherServlet;
}
```




### Spring MVC


在启动过程中，<font style="color:#080808;background-color:#ffffff;">HandlerMethodMapping </font>会解析controller中的每个方法为**<font style="color:#080808;background-color:#ffffff;">MappingRegistration</font>**<font style="color:#080808;background-color:#ffffff;">对象</font>。 将其注册到 **MappingRegistry#registry**

**核心类： AbstractHandlerMethodMapping.MappingRegistry#register**

****

**当发起**请求后，会通过path路径解析寻找到对应的MappingRegistration，进而执行到目标方法。

****

#### 获取Handler：
首先通过request获取对应的handlerMethod，然后获取其执行链：  
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729127717339-d31fb6e2-f00a-4bf6-8588-c2fa70c019ce.png" width="722" title="" crop="0,0,1,1" id="ud3af73e4" class="ne-image">



分别遍历各种handler，看是否能够获取到改request对应的handlerExecutionChain：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729128015160-a488f614-d6bb-4b8b-a172-138c50f8ecea.png" width="766" title="" crop="0,0,1,1" id="ud9fc2c70" class="ne-image">



<font style="color:#080808;background-color:#ffffff;">RequestMappingHandlerMapping中处理：</font>

<font style="color:#080808;background-color:#ffffff;">会调用lookupHandlerMethod方法来查找 URL对应的handlerMethod</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729128550625-60c9eea3-c2ec-4a25-9530-e2ddca3470d0.png" width="918" title="" crop="0,0,1,1" id="u1f53d97f" class="ne-image">





#### 执行目标方法：
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729128748623-e5b979d0-f2c0-4a15-9529-86ba3d6184fc.png" width="692" title="" crop="0,0,1,1" id="u565bdf32" class="ne-image">



会将前面找到的MethodHandler对象包装成ServletInvocableHandlerMethod对象，调用其invokeAndHandler：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729128856929-c1937b1a-bba8-45bc-a621-b5348d9483a4.png" width="692" title="" crop="0,0,1,1" id="u907da49c" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729128980116-68ccfe13-4cec-477b-8f2c-e6f88e36408e.png" width="735" title="" crop="0,0,1,1" id="uca0f7393" class="ne-image">





#### dispatcher 请求
当发起的是dispatcher类型的请求时：

下面会替换invocableMethod，并不是原来的HandlerMethod了。

<font style="color:#080808;background-color:#ffffff;">即创建了一个包含返回值的ConcurrentResultHandlerMethod对象作为invocableMethod。在后面执行invokeAndHandle方法就不会调用原controlller 方法了。</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729129619119-320d86b3-9edb-4f30-81fd-b05bdc6fb1b7.png" width="895" title="" crop="0,0,1,1" id="uf4304335" class="ne-image">





#### controller 层添加了AOP：



<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673423257887-11113031-1174-4f49-bdc1-b35b40854ef5.png" width="990" title="" crop="0,0,1,1" id="uad36abe5" class="ne-image">

默认情况this.bean instanceof String 都会成立<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673423307249-7fdca2ae-31e8-42f3-93f1-2c9a0e8808b7.png" width="684" title="" crop="0,0,1,1" id="u6596fcf7" class="ne-image">

#### 


#### 跨域分析
> 即协议、域名、端口 任意不同的时候都会作为跨域处理。 **CorsUtils#isCorsRequest**
>



解决跨域的方式很多， 这里分析最简单的使用方式。即在controller中添加注解@<font style="color:#080808;background-color:#ffffff;">CrossOrigin</font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">当预检通过会设置下面响应字段，用来提醒浏览器通过检查，从而可以进一步发起请求（在浏览器网络中会看到两个请求同时出现）</font>

<font style="color:#1DC0C9;">Access-Control-Allow-Origin: * </font>

<font style="color:#1DC0C9;">Access-Control-Allow-Methods: POST </font>

<font style="color:#1DC0C9;">Access-Control-Allow-Headers: content-type</font>

<font style="color:#1DC0C9;"> Access-Control-Max-Age: 1800</font>

<font style="color:rgb(31, 31, 31);"></font>

在配置跨域参数的时候：如果 allowCredentials 为true， <font style="color:#080808;background-color:#ffffff;">allowedOrigins 不能为*</font>



在引用启动过程中，下面方法中会解析method，跨域 配置，记录到registry, crosLookup 中。

**AbstractHandlerMethodMapping.MappingRegistry#register**

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1752831688427-c3f20338-ba09-4475-827d-ad1395b82339.png" width="1050" title="" crop="0,0,1,1" id="uc4a67eed" class="ne-image">





依次解析类上、方法上的注解信息。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1752831770607-5d742c1c-cf73-4519-bd62-07cc4cc86e10.png" width="974" title="" crop="0,0,1,1" id="u26a6a441" class="ne-image">





##### 请求发起
如果方法有跨域信息或者请求是预检请求，会替换当前执行链的handler为 跨域**PreFlightHandler**。



在构建**PreFlightHandler过程中会尝试** 从corsLookup 查找跨域配置信息，记录到**PreFlightHandler中（没有就是空），用于后续检查请求是否允许**。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1752832755675-4a94a8f3-2e5e-4ea9-ab22-54d03424b480.png" width="1042" title="" crop="0,0,1,1" id="ueab20126" class="ne-image">



<font style="color:#080808;background-color:#ffffff;">getCorsHandlerExecutionChain：</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1752912737617-6eae61e1-c46f-4dcd-89de-57d62fa9cb77.png" width="960" title="AbstractHandlerMapping#getCorsHandlerExecutionChain" crop="0,0,1,1" id="u5af8694f" class="ne-image">



##### 预检处理
上面分析得出预检将会替换原handler为PreFlightHandler：当调用AbstractHandlerMethodAdapter#**handle** <font style="color:#080808;background-color:#ffffff;">方法时，会执行到下面方法。</font>



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1752912932801-daafdfff-cebf-4697-b001-3103eb55e62f.png" width="836" title="" crop="0,0,1,1" id="u32c0d026" class="ne-image">

这里的corsProcessor 为**DefaultCorsProcessor**。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1752913194106-f2a22bfc-b5d9-4f39-814e-b557a7993396.png" width="1152" title="" crop="0,0,1,1" id="uba9e7809" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1752914060602-eed9a5d6-749f-4702-b901-302aff7abf45.png" width="929" title="" crop="0,0,1,1" id="uab2e3669" class="ne-image">



##### 预检后
如果是预检后的请求是添加的一个拦截器到最前面位置。**CorsInterceptor**

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1752913547786-3fae7e29-a49e-4cf3-bbf7-173916b08626.png" width="1152" title="" crop="0,0,1,1" id="u4016e5bf" class="ne-image">



同样会执行**corsProcessor**，跟预检请求一摸一样，只是preFlightRequest参数不同。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1752913695658-8ccaec15-da82-45e6-9b3a-58b1159a426b.png" width="934" title="" crop="0,0,1,1" id="ueaee1094" class="ne-image">







### SpringBoot整合WEB容器启动过程
> SpringBoot中不会存在父子容器的概念，只有一个容器：默认情况下创建Servlet类型的容器：**AnnotationConfigServletWebServerApplicationContext**
>

SpringApplication#createApplicationContext：  
SpringBoot SPI，加载spring.factories ， 得到org.springframework.boot.ApplicationContextFactory 对应的value，



SpringApplication启动：

根据class判断当前使用环境，这里是**Servlet**环境

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698480173935-786cc1fd-86ad-43fa-b42b-4ff3fb5c318f.png" width="862" title="" crop="0,0,1,1" id="u23a7df0a" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698480418047-525f884a-03bc-4a01-9400-1cd1da62d0cf.png" width="660" title="" crop="0,0,1,1" id="u8dbd4cb4" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698479958874-f869862a-7e2d-44b3-be81-2ba2ccefe2b8.png" width="983" title="" crop="0,0,1,1" id="u39acf451" class="ne-image">


servlet类型(默认) 创建**AnnotationConfigServletWebServerApplicationContext**

#### ServletWebServerFactoryConfiguration
启动过程中会处理ServletWebServerFactoryConfiguration：

创建TomcatServletWebServerFactory，设置一些自定义的属性

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698480761911-ee919eff-0395-427b-8e9b-a8fc69c8670e.png" width="879" title="" crop="0,0,1,1" id="u64dd4477" class="ne-image">



bean处理完成后调用refresh():

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673425329074-95b78a6b-570e-4746-b849-fa13a31dd655.png" width="408" title="" crop="0,0,1,1" id="uc4a40845" class="ne-image">

回调子类的onRefresh()方法

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673425345726-3097d09b-2a29-4928-97c3-18fdb19db609.png" width="405" title="" crop="0,0,1,1" id="u42691a7d" class="ne-image">

创建server：

getWebServerFactory() 方法会获取注册的ServletWebServerFactory对象，该对象被SPI机制加载，主要体现在这个类：**ServletWebServerFactoryAutoConfiguration**， @Import注解会导入EmbeddedTomcat 的class， 最终根据条件得到TomcatServletWebServerFactory（见上面）

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673425366043-4797c2f1-ae24-4d57-8086-23080f751f85.png" width="876" title="" crop="0,0,1,1" id="u0e6749cc" class="ne-image">



#### getWebServer:
创建Tomcat、Connector，  mergeInitializers()

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673670059676-09585e8a-de78-4fe5-886c-d277b562143d.png" width="895" title="" crop="0,0,1,1" id="u720ac48c" class="ne-image">

**prepareContext**最终会调用下面方法，

#### mergeInitializers：
最初initializers只有一个：

org.springframework.boot.web.servlet.context.ServletWebServerApplicationContext#selfInitialize

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698484538436-d0ffc793-d121-4ce6-b0f5-04556cfac01e.png" width="1091" title="" crop="0,0,1,1" id="u7cc92c22" class="ne-image">

#### configureContext
> 将initializer传入TomcatStarter
>

创建TomcatStarter，将其添加到initializers，TomcatStarter实现了SCI， 后续会调用onStartup()

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698485133116-b19b4905-5a00-4c18-b844-79801963989a.png" width="1129" title="" crop="0,0,1,1" id="u8b4e9e01" class="ne-image">



#### getTomcatWebServer
会创建TomcatWebServer (SpringBoot中的类)

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698485309093-963549db-70c3-4a6a-a152-714762c7e67d.png" width="696" title="" crop="0,0,1,1" id="u498ff5f0" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673671434181-d4892afe-3789-46f0-a8f7-ca99b0fa85e7.png" width="857" title="" crop="0,0,1,1" id="u95c62c64" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673671571984-500ea850-c9f3-44ca-a64d-77e2370cec69.png" width="792" title="" crop="0,0,1,1" id="u5bb8b06b" class="ne-image">

最后会调用StandardContext#startInternal:

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698485699499-6cea8de6-9ae5-4b03-8905-b946ee09b1f7.png" width="1024" title="" crop="0,0,1,1" id="u3f0fdfd8" class="ne-image">

#### TomcatStarter#onStartup
<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673671770820-ee6c1df9-541b-48b7-b8b0-1dba645059c0.png" width="1104" title="" crop="0,0,1,1" id="ua4b26a9f" class="ne-image">



1、AbstractServletWebServerFactory#lamda： 设置一些参数，默认空

2、AbstractServletWebServerFactory.SessionConfiguringInitializer: 配置session、cookie

3、核心：

```java
private void selfInitialize(ServletContext servletContext) throws ServletException {
    // 将当前ApplicationContext（AnnotationConfigServletWebServerApplicationContext）作为RootWebApplication存入ServletContext，
    // 同时将ServletContext 记录到ApplicationContext#servletContext中， 貌似只用于创建容器时判断是否存在ServletContext
    prepareWebApplicationContext(servletContext);
    // 将servletContext包装为ServletContextScope 注入BeanFactory中，scope为application
    // 同时也将ServletContextScope 作为ServletContext的属性
    registerApplicationScope(servletContext);
    // 注册servletContext 到BeanFactory中， 同时注册ServletContext中的
    // 一些配置参数（context-param、attribute）到BeanFactory
    WebApplicationContextUtils.registerEnvironmentBeans(getBeanFactory(), servletContext);
    // 向ServletContext注册Filter，Servlet等...
    // getServletContextInitializerBeans： 获取BeanFactory中的一些Servlet相关的bean对象
    for (ServletContextInitializer beans : getServletContextInitializerBeans()) {
        beans.onStartup(servletContext);
    }
}
```

registerApplicationScope：

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698483504049-f555e9ed-3111-4b9a-be55-e459e7879df7.png" width="1100" title="" crop="0,0,1,1" id="u893f3ce7" class="ne-image">



相关Servlet、Filter Bean：

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673674276420-fc2c6261-663d-488a-b0b2-dfb604b8f2a4.png" width="1026" title="" crop="0,0,1,1" id="u87290f62" class="ne-image">

#### DispatcherServletRegistrationBean#onStartup
> 由**DispatcherServletAutoConfiguration**自动注册到BeanFactory
>

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673674060177-9e96ffb3-469a-4365-b349-2fb6313286c8.png" width="723" title="" crop="0,0,1,1" id="u13e43893" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673674035402-a76406c9-df93-4b1a-8d55-53ab74b53c42.png" width="1271" title="" crop="0,0,1,1" id="uc68c8c7d" class="ne-image">

#### DispatcherServlet#init()
首次执行请求时，会执行DispatcherServlet#init():

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673425890729-dd6574fd-8efb-4a42-a190-06a91fbceb14.png" width="511" title="" crop="0,0,1,1" id="ucc4d88eb" class="ne-image">,

初始化解析器：

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1673425928243-7f7a2215-43b1-4147-9a78-834dffaafd8c.png" width="523" title="" crop="0,0,1,1" id="u01240b7a" class="ne-image">



### SpringBoot 内嵌Tomcat容器
这里需要注意SpringBoot默认采用的内嵌tomcat作为web容器时，并不会采用SPI去扫描ServletContainerInitializer的接口，因此无法使用继承ServletContainerInitializer的方式来处理一些初始化的操作（包括实现SpringServletContainerInitializer、WebApplicationInitializer）



SpringBoot中提供了类似的接口ServletContextInitializer， 将其作为bean注入到容器中即可自动调用onStartup方法，**ServletContextInitializer**相关实现类如下

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698502303993-a2d69ed1-6fd9-4943-86ea-0daec4f5abec.png" width="528" title="" crop="0,0,1,1" id="u0baa2720" class="ne-image">

在ServletWebServerApplicationContext#selfInitialize有如下方法：

这里会获取容器中的一些Servlet相关的bean对象，调用onStartup

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698496760997-bfd76e62-79a0-421a-83d5-6d53d6267f00.png" width="809" title="" crop="0,0,1,1" id="ud7c31248" class="ne-image">

#### 查找ServletContextInitializer类型的bean
> 即Servlet，Filter 相关实现了**ServletContextInitializer**
>

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698497689495-2271b6ae-7455-4d2c-8d3d-0dce10c7b8e6.png" width="744" title="" crop="0,0,1,1" id="u2d6dc34a" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698497677467-f5356e09-14cf-4d26-8dff-7031ea6d8af0.png" width="911" title="" crop="0,0,1,1" id="u8c7e1966" class="ne-image">

addServletContextInitializerBeans：

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698497215211-70d33743-d73a-4c09-bdd8-2cd30a28b22c.png" width="1018" title="" crop="0,0,1,1" id="u97b49be2" class="ne-image">



#### 调用OnStartup
回到selfInitialize，循环调用

ServletContextInitializerBeans 实现了AbstractCollection#iterator方法

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698497913493-89e131aa-09ed-48d8-af65-efa8e4ae3041.png" width="928" title="" crop="0,0,1,1" id="uc9cff3ba" class="ne-image">



RegistrationBean#onStartup：

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698498174444-a6b634ea-d47e-49e6-918c-77ff0ec5dd6a.png" width="800" title="" crop="0,0,1,1" id="u82110c8e" class="ne-image">

调用具体实现：

HttpEncodingAutoConfiguration、WebMvcAutoConfiguration 会注册一些默认Filter



例如：ServletRegistrationBean 注册一个Servlet到ServletContext

<img src="https://cdn.nlark.com/yuque/0/2023/png/12552539/1698498981444-57eef5a9-7bbb-49f0-aad2-887c3aab9189.png" width="836" title="" crop="0,0,1,1" id="u4447ae8c" class="ne-image">



#### Filter、Servlet 解析
> 在上文中可知<font style="color:#080808;background-color:#ffffff;">getServletContextInitializerBeans方法会获取IOC 容器中的</font>**<font style="color:#080808;background-color:#ffffff;">ServletContextInitializer</font>**<font style="color:#080808;background-color:#ffffff;">类</font>
>

**<font style="color:#080808;background-color:#ffffff;">ServletContextInitializer 相关子类：</font>**

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729085709659-9739f85c-b3dc-48c9-af68-5aac4b5113f5.png" width="445" title="" crop="0,0,1,1" id="u7bb5764b" class="ne-image">

在SpringBoot 中添加一个Filter 可以创建一个FilterRegistrationBean 注入到容器，或者通过@<font style="color:#080808;background-color:#ffffff;">ServletComponentScan 自动扫描，代码如下：</font>

```java
// 在启动类中添加@ServletComponentScan 扫描该类即可。
@WebFilter(filterName = "myFilter",urlPatterns = "/*", dispatcherTypes={DispatcherType.REQUEST, DispatcherType.ASYNC})
public class MyFilter extends OncePerRequestFilter implements Filter {

    public MyFilter() {
        System.out.println("constructor...");
    }
     @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        System.out.println("doFilter .....");
        filterChain.doFilter(request, response);
    }
}

//  也可以不用@ServletComponentScan 自动扫描， 使用下面代码手动注入，
// 注意使用下面方法注入时，@WebFitler 类上的注解 `完全无用`。 
@Bean
public FilterRegistrationBean filterRegistrationBean(){
    FilterRegistrationBean bean = new FilterRegistrationBean();
    bean.setFilter(new MyFilter());
    bean.addUrlPatterns("/*");
    bean.setName("myFilter");
    // 这里必须手动设置才能生效，不依赖于@WebFilter 注解
    // bean.setDispatcherTypes();
    bean.setOrder(1);
    return bean;
}
```



不管使用哪种方式最终都会解析为一个FilterRegistrationBean 的对象存入IOC容器中，最终在<font style="color:#080808;background-color:#ffffff;">ServletWebServerApplicationContext#selfInitialize中调用onStartup方法：  
</font>

<font style="color:#080808;background-color:#ffffff;">内部调用其addRegistration 将filter 或Servlet 添加到ServletContext中。 </font>

<font style="color:#080808;background-color:#ffffff;">其实就是servletContext.addFilter/addServlet()</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729086124603-e56dae0b-852d-4fbf-b342-320b757e5d2b.png" width="743" title="" crop="0,0,1,1" id="ubd7e750c" class="ne-image">



当添加Filter时：

这里会处理dispacherTypes，当Filter类没有指定dispatcherTypes时（@WebFilter默认值为REQUEST），这里会自动添加：

当继承了OncePerRequestFilter，该filter会自动将所有类型包含在内。 否则只添加REQUEST

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729086580429-5f3e3e33-5b76-4e4e-ad05-ff064bc30810.png" width="1044" title="" crop="0,0,1,1" id="ua1928149" class="ne-image">





#### OncePerRequestFilter解释
OncePerRequestFilter： 即每一次调用Servlet都会执行， 在Servlet 3.0 支持异步的情况下，除了正常情况下的request类型外，开启异步后还会出现dispacher的类型的请求。因此在这种常见下一次请求就会调用多次Filter。



示例：

```java
 @GetMapping("/call_able")
    public Callable call_able(HttpServletResponse response) throws Exception {
        System.out.println("call_able");
        return (Callable<String>) () -> {
            Thread.sleep(5000); //this will cause a timeout
            return "foobar";
        };
    }


// Filter:
public class MyFilter extends OncePerRequestFilter{
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain) throws ServletException, IOException {
        logger.info("doFilter.....");
        filterChain.doFilter(request, response);
    }

    // dispatch 请求依然执行filter
    @Override
    protected boolean shouldNotFilterAsyncDispatch() {
        return false;
    }
}
```



运行结果：  可以看到5s后又执行了一次filter。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1729087798166-47dc3002-717f-4cc4-896c-a4ce922c4739.png" width="1189" title="" crop="0,0,1,1" id="u77aede51" class="ne-image">



这里需要注意当在controller 中使用request.startAsyn() 手动开启异步时，tomcat 并不会触发dispatcher类型的请求，因此不会执行多次filter。 使用<font style="color:#080808;background-color:#ffffff;">DeferredResult 作为结果同样会触发两次调用</font>



虽然上面执行了两次filter，controller中方法并不会执行多次，这主要是靠Spring MVC 保证的。





### Spring MVC 中的异步
#### AsyncContext
> Servlet 原生异步对象： 用于业务线程耗时的场景，即使释放tomcat线程，同时当业务线程处理完成后，可以继续将结果写入response中
>

controller不能返回值，返回后response将会关闭，无法写入返回的信息

#### DeferredResult
> SpringMVC 提供的异步支持对象，底层依然基于AsyncContext。可以设置超时参数，用于延时获取返回的结果： 请求后tomcat释放线程，DeferredResult set相应的值后，可以通知到response对象。
>
>
>
> AI相关的**SSE** 协议，在Spring中也是基于DeferredResult来实现的。
>

[https://mp.weixin.qq.com/s/JrphMlEf4Q7s597O8yZfuw](https://mp.weixin.qq.com/s/JrphMlEf4Q7s597O8yZfuw)

<font style="color:#080808;background-color:#ffffff;">除此之外，spring mvc 还提供了其他异步对象：CompletableFuture、WebAsyncTask、CompletableFuture、Callable。</font>

```java
@RequestMapping("/test1")
public void test1(HttpServletRequest request, HttpServletResponse response) {
    String a = request.getParameter("a");
    System.out.println(Thread.currentThread().getName() + "===  Request: " +request + " " + "a: " + a );
    AsyncContext asyncContext = request.startAsync(request, response);

    new Thread(() -> {
        //            String b = request.getParameter("a");
        //            System.out.println("a: " + b );
        try {
            TimeUnit.SECONDS.sleep(2);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        String c = request.getParameter("a");
        System.out.println(Thread.currentThread().getName() + " a: " + c );

        int i = 0;
        while (i < 10) {
            i++;
            try {
                PrintWriter writer = response.getWriter();
                writer.println("hello server");
                writer.flush();
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
        asyncContext.complete();
    }).start();

    // return "test1";
}

@GetMapping("/testDeferredResult")
public DeferredResult<String> getDeferredResult(Long sleepTime) {
DeferredResult<String> result = new DeferredResult<>(5000L, "time out........");

new Thread(() -> {
    try {
        TimeUnit.SECONDS.sleep(sleepTime);
        result.setResult(" hello deferred");
    } catch (InterruptedException e) {
        e.printStackTrace();
    }
}).start();
System.out.println("deferred exit...");
return result;

}
```





相关源码：ServletInvocableHandlerMethod#invokeAndHandle

通过返回值类型 找到对应的处理器。

<img src="https://cdn.nlark.com/yuque/0/2026/png/12552539/1770101982873-ece6edcd-bfb0-4b33-bc53-a26e59de3417.png" width="943.3333583231332" title="" crop="0,0,1,1" id="u9ed2364f" class="ne-image">







