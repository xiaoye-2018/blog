

使用：

下面两种方式都是一样的结果

```java
public static void main(String[] args) {
    ServiceLoader<Search> s = ServiceLoader.load(Search.class);
    Iterator<Search> iterator = s.iterator();
    while (iterator.hasNext()) {
        Search search = iterator.next();
        search.searchDoc("hello world");
    }

    System.out.println("方法2.############");

    Iterator<Search> providers = Service.providers(Search.class);
    while (providers.hasNext()) {
        Search next = providers.next();
        next.searchDoc("hello world... provides");
    }
}
```



## 源码分析

因为Service类是由`sun.misc`包提供,  无法查看源代码， 因此这里对第一种进行分析



### 构建ServiceLoader对象

当调用 `ServiceLoader<Search> s = ServiceLoader.load(Search.class); `后， 会创建ServiceLoader对象，同时对ServiceLoader做一些初始化操作

```java
public final class ServiceLoader<S>
    implements Iterable<S>
{
	// 基础路径
    private static final String PREFIX = "META-INF/services/";
    // 加载的服务接口，等价于传入的参数， Service.class
    private final Class<S> service;
    // 当前类加载器
    private final ClassLoader loader;
    // 保存已经完成初始化的对象，
    // 如<spi.DBSearch, Obj>、<spi.FileSearch, Obj>
    private LinkedHashMap<String,S> providers = new LinkedHashMap<>();
    // 加载服务类迭代器
    private LazyIterator lookupIterator;
    
    
    // 构造方法
    private ServiceLoader(Class<S> svc, ClassLoader cl) {
        //要加载的接口
        service = Objects.requireNonNull(svc, "Service interface cannot be null");
        //类加载器
        loader = (cl == null) ? ClassLoader.getSystemClassLoader() : cl;
        //先清空
        providers.clear();
        //实例化内部类 
       	lookupIterator = new LazyIterator(service, loader);
    }
}
```



### 构建迭代器对象

对应案例中的`Iterator<Search> iterator = s.iterator();`， 得到一个迭代器对象， 外部都是通过这个迭代器进行循环得到真实的对象



这里的`lookupIterator`变量指LazyIterator对象

```java
// ServiceLoader的内部类
public Iterator<S> iterator() {
    	// 匿名内部类，实现迭代器中的方法
        return new Iterator<S>() {
            // 起初privoders是空的，因此knownProviders最初也是空
            Iterator<Map.Entry<String,S>> knownProviders
                = providers.entrySet().iterator();
            
            // 判断迭代器是否还有元素
            public boolean hasNext() {
                // 最初无元素，这里false
                if (knownProviders.hasNext())
                    return true;
                // lookupIterator为ServiceLoader中的LazyIterator对象
                return lookupIterator.hasNext();
            }
            public S next() {
                if (knownProviders.hasNext())
                    return knownProviders.next().getValue();
                return lookupIterator.next();
            }
            public void remove() {
                throw new UnsupportedOperationException();
            }
        };
}
```



### 核心：LazyIterator迭代器

```java
// ServiceLoader的内部类， 在创建ServiceLoader对象时，会将LazyIterator对象创建出来， 对应lookupIterator变量

private class LazyIterator
    implements Iterator<S>
    {
    // 要加载的接口的class
    Class<S> service;
    // 当前类加载器
     ClassLoader loader;
     Enumeration<URL> configs = null;
    // 保存了配置文件中的信息，由ArrayList转为Iterator，[spi.DBSearch, spi.DBSearch]
    // 后续将使用迭代器得到的值，通过反射创建具体的实现类
     Iterator<String> pending = null;
     // 最初null，当得到第一个实现类后，会被赋值为实现类名，当实现类实例化后，又会将其赋值null
     String nextName = null;	

 private LazyIterator(Class<S> service, ClassLoader loader) {
     this.service = service;
     this.loader = loader;
 }

 private boolean hasNextService() {
     // 最初为null，不为null，说明已经赋值过了，后续将通过反射生成对象
     if (nextName != null) {
         return true;
     }
     if (configs == null) {
         try {
             // META-INF/services/spi.Search
             String fullName = PREFIX + service.getName();
             // 得到URL路径信息
              configs = loader.getResources(fullName);
         } 
     }
     while ((pending == null) || !pending.hasNext()) {
         if (!configs.hasMoreElements()) {
             return false;
         }
         // 通过configs迭代器，将配置文件中的信息转为pending迭代器
         pending = parse(service, configs.nextElement());
     }
     // 得到配置文件中的一行数据、如： sp.DBService, 下次得到sp.FileService
     nextName = pending.next();
     return true;
 }
// 得到具体的对象
 private S nextService() {
     if (!hasNextService())
         throw new NoSuchElementException();
     String cn = nextName;
     nextName = null;
     Class<?> c = null;
     // 通过loader加载器， 得到Class对象
     c = Class.forName(cn, false, loader);
    
     // 将对象转为S类型
     S p = service.cast(c.newInstance());
     // 创建好的对象放入map中
     providers.put(cn, p);
     return p;
 }

 public S next() {
    return nextService();
}
```





总结：核心通过`loader.getResources(fullName);`  加载指定的资源文件，然后读取文件中的数据，通过反射创建对象





详细阅读：https://www.jianshu.com/p/3a3edbcd8f24