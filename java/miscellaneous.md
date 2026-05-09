## Security相关实现

### 基本使用

```java
// 使用默认的随机数生成策略
SecureRandom secureRandom = new SecureRandom();
int i = secureRandom.nextInt();

```



### Security 相关类加载过程：

java.security.Security#initialize： 加载lib\security\java.security文件, 会将相关的属性放入props 变量中。

java.security -->

```properties
security.provider.1=sun.security.provider.Sun
security.provider.2=sun.security.rsa.SunRsaSign
security.provider.3=sun.security.ec.SunEC
```



在Providers的静态代码块中会进行初始化：

```java
static {
        providerList = ProviderList.EMPTY;
    	// ProviderList： 保存所有的Provider，可以自定义向其添加
        //      configs：会依次读取security.provider.x 相关属性,生成一个一个的ProviderConfig
        //      userList: get() 会执行getProvider(), 获取configs 中的名称反射创建Provider实例（如：sun.security.provider.Sun）
        providerList = ProviderList.fromSecurityProperties();
        jarVerificationProviders = new String[]{"sun.security.provider.Sun", "sun.security.rsa.SunRsaSign", "sun.security.ec.SunEC", "sun.security.provider.VerificationProvider"};
    }
```

实例化相关的Provider

> 每一个具体Provider都继承了 Provider类 (Provider类继承 Properties)， 这里分析下sun.security.provider.Sun 初始化过程  

```java
 public Sun() {
        // 设置当前Provider 状态信息
        super("SUN", 1.8d, INFO);
        // 初始化 map
        SunEntries.putEntries(this);
    }
// map 即当前Provider 实例
static void putEntries(Map<Object, Object> map) {
    if (nativeAvailable && useNativePRNG) {
        map.put("SecureRandom.NativePRNG",
                "sun.security.provider.NativePRNG");
    }
    map.put("SecureRandom.SHA1PRNG",
            "sun.security.provider.SecureRandom");
    ....
```
put 的时候会执行Provider#put，添加到Provider#**legacyStrings**的map集合
    entry (key，val), key=type.algr, value = implClass

在获取对应算法Instance 实例的时候， 先获取Service 对象，然后再实例化对应的实例

会首先执行：sun.security.jca.ProviderList.getService， 从所有Provider 中查找相关算法实现
    执行： Provider#getServices ， 会加载**legacyStrings** 初始化生成 Service对象 （type, algorithm, className）， 放入Provider#legacyMap，下一次直接通过legacyMap获取对应的Service


```java
// 内部会查找type 为 SecureRandom、算法为SHA1PRNG（默认） 的service进行初始化
SecureRandom secureRandom = new SecureRandom();

// 注册BouncyCastle Provider： 一个三方提供的加密库
Security.addProvider(new BouncyCastleProvider());
// 在所有Provider 中查找 type 为 MessageDigest、 算法为RipeMD160的Service 进行实例化
MessageDigest md = MessageDigest.getInstance("RipeMD160");

// 获取SunMSCAPI 中的SecureRandom 实现，算法为Windows-PRNG 的Service。 （windows 平台特有的实现: CryptGenRandom）
Provider.Service service = Security.getProvider("SunMSCAPI").getService("SecureRandom", "Windows-PRNG");
// 通过Service构造SecureRandom 内部对象。
SecureRandomSpi secureRandomSpi = (SecureRandomSpi) service.newInstance(null);

// 内部调用跟上面相同，先获取到Service，然后创建对象
SecureRandom instance = SecureRandom.getInstance("Windows-PRNG", "SunMSCAPI");
SecureRandom instance1 = SecureRandom.getInstance("SHA1PRNG", "SUN");

```

在JDK 中提供的算法实现中，大多数内部都有一个XXXSpi类来实现核心逻辑，如：KeyPairGenerator--> KeyPairGeneratorSpi, MessageDigest--> MessageDigestSpi, KeyFactory--> KeyFactorySpi


### 随机数：
Random： 默认线性生成，容易被预测。 内部采用CAS更新种子，多线程会带来性能问题
ThreadLocalRandom： 继承Random，存储种子变为每个线程存储，性能高。 同样不符合标准安全协议。
SecureRandom： 继承Random， 采用强加密算法。 每次生成随机数都会加**同步锁**
            windows: sun.security.provider.SecureRandom，内部实际上使用SHA1算法处理（JDK17 采用DRBG）。 
            linux：  默认使用NativePRNG， 采用混杂模式。


### Linux下的SecureRandom
> 核心类：sun.security.provider.NativePRNG

linux 自定义种子生成器： 添加vm参数 java.security.egd=
- file:/dev/random  阻塞模式，  sun.security.provider.NativePRNG$Blocking
- file:/dev/urandom 非阻塞模式， sun.security.provider.NativePRNG$NonBlocking

如果没有指定java.security.egd， 则使用java.security文件中的默认设置： `securerandom.source=file:/dev/random  ` 作为seed 生成器

Linux平台使用SecureRandom时， 默认混杂模式： 种子由参数决定（默认/dev/random）， buffer由 /dev/urandom
，生成过程如下：
1. 使用SecureRandom的默认策略(SHA1)生成随机数
2. nextIn(/dev/urandom) 文件描述符生成buffer。（buffer有剩余，且距离上次不到100 ms 则不会生成）
3. 将1生成的与2生成的进行异或

因此Linux默认情况下使用SecureRandom，只要不调用生成种子方法，就不会使用/dev/random， 不会造成阻塞。

在linux 中也可以使用上面文件描述符直接生成随机数，如：
``` shell 
# 生成13为指定字符随机数
[root@k8s-node1 dev]# tr -dc A-Za-z0-9 </dev/random | head -c 13 ; echo ''
kkHMXCbpSGxoX
```

#### EGD机制
> 在使用过程中经常看到加参数：-Djava.security.egd=file:/dev/./urandom，  而不是直接加/dev/urandom。

这是为了解决在早期的JDK中 会尝试通过一个套接字（socket）连接到 /dev/urandom，而不是直接使用文件，这会导致性能下降。
在中间加入一个./ 即可绕过EGD机制，从而直接使用文件。

现代JDK 中这种EGD机制早已经被废弃，因此也不需要加入./了。 





## javabeans

常见的类：BeanInfoImpl、PropertyDescriptor、MethodDescriptor

```java
BeanInfo beanInfo = Introspector.getBeanInfo(SpringBeansDemo.class, Object.class);
MethodDescriptor[] methodDescriptors = beanInfo.getMethodDescriptors();
PropertyDescriptor[] propertyDescriptors = beanInfo.getPropertyDescriptors();
```


