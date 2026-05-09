# 基本使用
引入pom：

如果是 **springboot3** 中必须手动指定mybatis-spring的版本 3.X, 否则无法启动。(默认引入的mybatis-spring为2.X版本)，

```xml
<dependency>
  <groupId>com.baomidou</groupId>
  <artifactId>mybatis-plus-boot-starter</artifactId>
  <version>3.5.14</version>
  <exclusions>
    <exclusion>
      <groupId>org.mybatis</groupId>
      <artifactId>mybatis-spring</artifactId>
    </exclusion>
  </exclusions>
</dependency>
<dependency>
  <groupId>org.mybatis</groupId>
  <artifactId>mybatis-spring</artifactId>
  <version>3.0.5</version>
</dependency>
```



创建实体类：

```java
@Data
@TableName
public class Student {
    @TableId(type = IdType.AUTO)
    private Integer id;

    private String stu_code;
    private Integer age;
}
```

创建Mapper接口：

```java
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface StudentMapper extends BaseMapper<Student> {
}
```

Springboot启动类添加：  
<font style="color:#080808;background-color:#ffffff;">@MapperScan(basePackageClasses = StudentMapper.class)</font>



配置文件添加SQL日志打印：输出到控制台

```plain
mybatis-plus:
  configuration:
    log-impl: org.apache.ibatis.logging.stdout.StdOutImpl
```



controller 注入Mapper接口即可：

```java
@Autowired
private StudentMapper studentMapper;
@GetMapping("/test")
public List<Student> test() {
    List<com.demo.boot2.mapper.Student> students =
    studentMapper.selectList(null);
    System.out.println(students);
    return null;
}
```





# MybatisPlusAutoConfiguration：
> mybatisplus 核心自动装配类。 主要构造SqlSessionFactory、SqlSessionTemplate
>

## <font style="color:#080808;background-color:#ffffff;">SqlSessionFactory</font>
> **MybatisSqlSessionFactory** 替换mybatis中的<font style="color:#080808;background-color:#ffffff;">SqlSessionFactoryBean。 </font>
>
> <font style="color:#080808;background-color:#ffffff;">主要进行解析一些核心配置：类型转换器、拦截器、SQL注入器、ID生成器等。</font>
>



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758290766223-5d2117c1-e666-467b-9d2b-ce129b5d8663.png" width="927.7778023554962" title="" crop="0,0,1,1" id="u4795dde5" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758290818707-13e541b2-f83d-4b0f-803b-df9cffe62059.png" width="866.6666896254934" title="" crop="0,0,1,1" id="uc4dcbf71" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">factory.getObject方法会调用 MybatisSqlSessionFactoryBean#afterPropertiesSet。 解析XML、Mapper接口，最终构建SqlSessionFactoryBean。</font>

### 解析XML
XMLMapperBuilder#parse:  解析mybatis的Mapper 配置文件。如果没有配置则不会走这里的逻辑

一般配置路径为：**<font style="color:#080808;background-color:#ffffff;">classpath*:/mapper/**/*.xml</font>**

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758509863055-9fb0000f-e4fc-4699-bf3d-fad0bcc1c2c0.png" width="1186.6666981025987" title="" crop="0,0,1,1" id="uecfe883a" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758984009668-48938b97-62c5-4a34-97cd-ecf38b1b2686.png" width="807" title="" crop="0,0,1,1" id="u75dc58b9" class="ne-image">



1. configurationElement:   
   这里会解析XML 文件 生成MappedStatement， 记录到MybatisConfiguration#**mappedStatements**， 同一个id 记录两条entry。

XML 文件跟对应的Mapper接口不能同时定义二级缓存（没人这样干吧），因为最终保存到Configuration中，会发生覆盖冲突报错。  
<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758767325392-95e3216a-25d3-4178-a7cb-0cf43e108704.png" width="992.2222485071354" title="" crop="0,0,1,1" id="xi4fi" class="ne-image">

解析XML 创建SqlSource：

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1760318844915-520b1ca2-ca15-4170-8acc-d87014a1c6d2.png" width="1041.1111386911375" title="org.apache.ibatis.builder.xml.XMLStatementBuilder#parseStatementNode" crop="0,0,1,1" id="b3xf2" class="ne-image">  

最终生成MappedStatement：<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758249076160-22afe638-4a22-4d00-9827-111e02f6cbc8.png" width="804.4444657549452" title="" crop="0,0,1,1" id="mSAEC" class="ne-image">
2.

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1760318844915-520b1ca2-ca15-4170-8acc-d87014a1c6d2.png" width="1041.1111386911375" title="org.apache.ibatis.builder.xml.XMLStatementBuilder#parseStatementNode" crop="0,0,1,1" id="aM9NO" class="ne-image">  

最终生成MappedStatement：<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758249076160-22afe638-4a22-4d00-9827-111e02f6cbc8.png" width="804.4444657549452" title="" crop="0,0,1,1" id="qoDnk" class="ne-image">
3. bindMapperForNamespace:   
   解析当前XML的**namespace 接口，**处理生成接口对应的Mapper对象  
   <img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759065419251-a0600798-2fd8-4ee7-9086-11a2d7cbcb58.png" width="790" title="" crop="0,0,1,1" id="uf9eb80f6" class="ne-image">


<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759065612982-92b8da21-ed63-4770-b05c-3bf84b87c3ae.png" width="636" title="" crop="0,0,1,1" id="u6d9dd299" class="ne-image">  

记录到MybatisMapperRegistry#**knownMappers**： <img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758251009983-66a602d4-f5d9-4e6f-a7e0-df280217c627.png" width="1077.7778063291391" title="" crop="0,0,1,1" id="AOetC" class="ne-image">
4. 继续执行内部parse：
    1. 首先检查Mapper接口缓存相关定义：@CacheNamespace，@CacheNamespaceRef。<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758766299322-a5129024-b81c-4ab8-882f-15ffdbf291c9.png" width="958.8889142907702" title="" crop="0,0,1,1" id="ubb9a32cc" class="ne-image">

如果定义了相关注解，创建缓存对象。默认**PerpetualCache， 添加到Configuration 	**<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758766270404-ba5191db-fe53-47da-aab6-e1e3604dc888.png" width="675" title="" crop="0,0,1,1" id="kmaR4" class="ne-image">




    2. 然后检查接口方法是否有mybtis注解：进行替换BaseMapper的CRUD方法。 		  MybatisMapperAnnotationBuilder#statementAnnotationTypes<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758511138353-9795f1aa-c0f9-4979-b465-89c79a1451b5.png" width="1235.5555882866008" title="" crop="0,0,1,1" id="u0b536b89" class="ne-image">  

    3. parseInjector：解析Entity为TableInfo对象， 同时注入Mybatis-plus 提供的默认CRUD 方法<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758251306340-48d91c69-dbd4-4fdc-bc57-4fe72468c6e4.png" width="1117.7778073887773" title="com.baomidou.mybatisplus.core.injector.AbstractSqlInjector#inspectInject" crop="0,0,1,1" id="u40a8c4db" class="ne-image">以Insert 为例： 会构建SQL 执行脚本，生成sqlSource对象， 创建**MappedStatement**对象<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758520765360-c225c083-8f6e-4f98-b513-3d0a02e24a8f.png" width="838.8889111118558" title="" crop="0,0,1,1" id="PBzqD" class="ne-image"><img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758520911380-05903c54-a33d-4d09-9bd9-304c867d01a2.png" width="920.0000243716776" title="org.apache.ibatis.builder.MapperBuilderAssistant#addMappedStatement" crop="0,0,1,1" id="u0d7b3b07" class="ne-image">最后生成MappedStatement：<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758520984378-e92f644e-8d8e-4d8b-a342-7bbeb84ca456.png" width="984.4444705233169" title="" crop="0,0,1,1" id="u76694572" class="ne-image">



### 创建DefaultSqlSessionFactory
通过configuration创建DefaultSqlSessionFactory

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758984648151-602da526-e80d-4f52-ad80-d4e68d45172d.png" width="1113" title="" crop="0,0,1,1" id="u533e9bb8" class="ne-image">







## 构建<font style="color:#080808;background-color:#ffffff;">SqlSessionTemplate</font>
这里构建的ibatis中的SqlSessionTemplate

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758291958820-59196187-8f65-4996-9627-b03942e5671b.png" width="1050.0000278155017" title="" crop="0,0,1,1" id="uc532ae93" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758292666242-7b32e933-c431-4745-97e9-f49143d73f4d.png" width="1048.8889166749561" title="org.mybatis.spring.SqlSessionTemplate#SqlSessionTemplate" crop="0,0,1,1" id="u88bd1613" class="ne-image">



提供了一些常用的查询方法，都是通过sqlSessionProxy实现，  最终交给**SqlSessionInterceptor**

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758292773445-917b350d-e023-4345-a1fc-1f230e1a82b5.png" width="716.6666856518503" title="" crop="0,0,1,1" id="u572c43f5" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758292747498-cc2544c3-9b8c-434f-b422-6f7e2cab4891.png" width="715.5555745113048" title="" crop="0,0,1,1" id="ue3956db4" class="ne-image">

#### <font style="color:#080808;background-color:#ffffff;"></font>




# @MapperScan处理
import --> MapperScannerRegistrar：

注册beanDefinition：  **MapperScannerConfigurer**



**MapperScannerConfigurer**<font style="color:#080808;background-color:#ffffff;"> 实现了BeanDefinitionRegistryPostProcessor， postProcessBeanDefinitionRegistry方法中会生成ClassPathMapperScanner对象进行扫描basePackage目录的接口类。</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758288984337-cbfa3956-30a3-463b-beb2-97bd52be7d12.png" width="801.1111323333087" title="org.mybatis.spring.mapper.MapperScannerConfigurer#postProcessBeanDefinitionRegistry" crop="0,0,1,1" id="Vmiqp" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>



把接口类扫描出来， 生成 **MapperFactoryBean **beanDefinition

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758289357014-376e650c-a1f8-4eb1-8cd8-57725274edb0.png" width="1035.5555829884102" title="org.mybatis.spring.mapper.ClassPathMapperScanner#processBeanDefinitions" crop="0,0,1,1" id="VVYe7" class="ne-image">



这里的beanDefinition只设置了两个PropertyValue

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758290916170-88cbaad9-a592-4c86-a728-8740ca8577b0.png" width="597.7777936134813" title="" crop="0,0,1,1" id="kLpmf" class="ne-image">



## Mapper代理对象属性注入
**MapperFactoryBean继承了 **<font style="color:#080808;background-color:#ffffff;">SqlSessionDaoSupport， 里面包含几个set方法</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758292159625-eefe3784-2048-47b4-abc6-587329c65b82.png" width="594.4444601918449" title="" crop="0,0,1,1" id="u48022d56" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

Spring在填充属性的时候会尝试将带set方法、非简单参数类型的方法  尝试执行其setXXX。 会从IOC中获取参数类型的对象。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758291239427-692bd63a-6db5-42bb-9628-6af010c03de3.png" width="1042.222249831683" title="" crop="0,0,1,1" id="W7B4g" class="ne-image">



<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">SqlSessionDaoSupport：</font>

<font style="color:#080808;background-color:#ffffff;">由于SqlSessionFactory、SqlSessionTemplate 在MybatisPlusAutoConfiguration中都已经定义了Bean，因此下面的setSqlSessionFactory、setSqlSessionTemplate都会执行一遍。</font>

<font style="color:#080808;background-color:#ffffff;"> </font>

<font style="color:#080808;background-color:#ffffff;">注意到setSqlSessionFactory中会重新创建sqlSessionTemplate。 这里是否多于了，为什么没有定义属性</font>**<font style="color:#080808;background-color:#ffffff;">SqlSessionFactory</font>**

```java
public void setSqlSessionFactory(SqlSessionFactory sqlSessionFactory) {
if (this.sqlSessionTemplate == null || sqlSessionFactory != this.sqlSessionTemplate.getSqlSessionFactory()) {
    this.sqlSessionTemplate = createSqlSessionTemplate(sqlSessionFactory);
}
}
public final SqlSessionFactory getSqlSessionFactory() {
    return (this.sqlSessionTemplate != null ? this.sqlSessionTemplate.getSqlSessionFactory() : null);
}

public void setSqlSessionTemplate(SqlSessionTemplate sqlSessionTemplate) {
this.sqlSessionTemplate = sqlSessionTemplate;
}
 public SqlSession getSqlSession() {
    return this.sqlSessionTemplate;
}
```





## afterPropertiesSet
当Bean对象初始化完成后，最后会调用afterPropertiesSet方法，完成最后的一些参数初始化。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759064938881-a73d1fc1-f80f-4a0d-aed3-91b841362237.png" width="715" title="" crop="0,0,1,1" id="u0a0a4582" class="ne-image">





这里会判断Configuration中是否已经有该接口对应的Mapper对象（当定义过相关XML配置的时候，这里不会继续处理）， 生成Mapper接口对应的MappedStatement对象

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759065057581-8abf1a3a-8e01-4e81-9804-0a04cdd7bb32.png" width="896" title="org.mybatis.spring.mapper.MapperFactoryBean#checkDaoConfig" crop="0,0,1,1" id="u0a05571f" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759065595216-450069e0-331a-48c5-8f97-a2e957bce7bb.png" width="636" title="" crop="0,0,1,1" id="u246f1ec9" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759065317630-a104f9a2-859a-4d8c-b226-5f8192d702f8.png" width="1062" title="" crop="0,0,1,1" id="ue296b10a" class="ne-image">

这里的逻辑实际上跟前面解析XML部分后期解析Mapper接口对应的逻辑是一样的。最终生成MappedStatement到MybatisConfiguration中






## getObject
当bean实例化完成后，执行**#getObject方法， 构建Mapper代理对象****<font style="color:#DF2A3F;">MybatisMapperProxy</font>****作为最终的Bean**

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758251676069-28a66972-739b-4313-bec9-5edf393fe048.png" width="857.7778005011294" title="" crop="0,0,1,1" id="eqf5V" class="ne-image">

从SqlSessionTemplate中获取Mapper代理对象

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758251746055-1da57ca1-7d59-4abe-a1ce-b4786ffb03eb.png" width="771.11113153858" title="" crop="0,0,1,1" id="wzgZj" class="ne-image">





<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758288551580-56643794-44ac-480c-942f-7816ab844fbd.png" width="1064.4444726425932" title="com.baomidou.mybatisplus.core.MybatisMapperRegistry#getMapper" crop="0,0,1,1" id="Avijs" class="ne-image">

创建JDK代理对象：

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758288584896-d2bc9ba3-5a48-4a03-94a6-90c567e6a24e.png" width="1152.2222527456881" title="" crop="0,0,1,1" id="Pd1fp" class="ne-image">





# Mapper方法执行流程
前面提到注入的DAO方法实际上是**MybatisMapperProxy对象，在**执行目标的时候会转到<font style="color:#080808;background-color:#ffffff;">MybatisMapperMethod#execute，通过接口方法，配置判断属于哪类操作，进而分配到合适的执行方法</font>

****

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758525552300-b866d382-9a8e-48ca-bab4-4127d178c0ae.png" width="972.2222479773163" title="com.baomidou.mybatisplus.core.override.MybatisMapperMethod#execute" crop="0,0,1,1" id="u3b13e729" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">sqlSession 即SqlSessionTemplate， 最终委派给</font>**<font style="color:#080808;background-color:#ffffff;">SqlSessionInterceptor</font>**

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759066279181-df17f2db-f62a-44ec-aa4b-353a669f67ed.png" width="1027" title="" crop="0,0,1,1" id="u7afefb34" class="ne-image">



<font style="color:#080808;background-color:#ffffff;">不管是mybatis-plus 内置的方法，还是mybatis xml定义的方法，最终都会在这里进行开启SqlSession</font>

### 开启SqlSession
<font style="color:#080808;background-color:#ffffff;">org.mybatis.spring.SqlSessionTemplate.SqlSessionInterceptor: </font>  
<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758293323674-14183ece-8f87-4c57-88a2-69945724ad6e.png" width="1137.7778079185964" title="org.mybatis.spring.SqlSessionTemplate.SqlSessionInterceptor" crop="0,0,1,1" id="u5a053eb1" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758523988539-212d70ed-0947-47ec-a459-16b545b7e550.png" width="938.8889137609511" title="" crop="0,0,1,1" id="u66908366" class="ne-image">



根据执行类型选择合适的执行器（默认为SimpleExecutor）

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758524094857-991b9b43-2dbc-4d32-a38f-a583cd3875c4.png" width="892.22224585804" title="org.apache.ibatis.session.Configuration#newExecutor" crop="0,0,1,1" id="u2bdaddbb" class="ne-image">



### **<font style="color:#080808;background-color:#ffffff;">Executor</font>**<font style="color:#080808;background-color:#ffffff;"> </font>执行目标
<font style="color:#080808;background-color:#ffffff;">DefaultSqlSession：</font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">查询方法都会进入select： </font>

<font style="color:#080808;background-color:#ffffff;">通过statement 从Configuration中得到</font>**<font style="color:#080808;background-color:#ffffff;">MappedStatement（包含了缓存对象信息）</font>**<font style="color:#080808;background-color:#ffffff;">， 交给</font>**<font style="color:#080808;background-color:#ffffff;">Executor</font>**<font style="color:#080808;background-color:#ffffff;"> 查询</font>



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758522794478-f1c6d1b9-bb5e-4bd5-9f4b-69cf7e31079d.png" width="1248.8889219731468" title="" crop="0,0,1,1" id="u8ea73ca1" class="ne-image">



BoundSQL： 包含最终的SQL，以及参数信息

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758293708630-7b94fd2c-bdf4-41d7-baa0-c26b89ede803.png" width="915.5555798094956" title="" crop="0,0,1,1" id="u7a877739" class="ne-image">





先查询二级缓存：

MappedStatement中记录了缓存对象，默认namespace 独有。（@CacheNamespaceRef 可以改变为非namespace）

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758769436797-760524d5-b5c7-481f-ad91-87aed4f52aca.png" width="1075.5555840480483" title="org.apache.ibatis.executor.CachingExecutor#query" crop="0,0,1,1" id="u1c1953da" class="ne-image">



二级缓存中没有数据，查询一级缓存：



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758769537742-959ec737-d3ca-4b59-98bd-91d079cf43e8.png" width="1086.6666954535033" title="" crop="0,0,1,1" id="u8efc3d87" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758769692538-9082a323-2a03-4e7a-9a74-4efb1bbae3f7.png" width="908.8889129662226" title="" crop="0,0,1,1" id="uab1be62a" class="ne-image">



执行底层查询逻辑：

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758524840878-be7a5fa8-4827-4976-96cb-847220accff9.png" width="858.8889116416749" title="org.apache.ibatis.executor.SimpleExecutor#doQuery" crop="0,0,1,1" id="u60a6db65" class="ne-image">



<font style="color:#080808;background-color:#ffffff;">prepareStatement： 获取Connection，生成PrepareStatement，填充参数</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758524823906-05a1bad2-185f-48b5-9336-24fbc010a5cb.png" width="808.8889103171272" title="" crop="0,0,1,1" id="u89eb21f7" class="ne-image">



从SpringManagedTransaction对象 获取JDBC连接对象， 如果没有初始化链接，进行初始化。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758854818682-c0f6b705-724e-44e4-a36d-dd0c45771f49.png" width="777.777798381853" title="" crop="0,0,1,1" id="u686d001d" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759134960559-61df7964-d635-4c7e-a78f-e8723af9adb1.png" width="591.1111267702083" title="" crop="0,0,1,1" id="u18c85055" class="ne-image">





**<font style="color:#080808;background-color:#ffffff;">DataSourceUtils.getConnection</font>**<font style="color:#080808;background-color:#ffffff;">： 会先尝试从TransactionSynchronizationManager中获取链接，如果获取不到则从Datasource中新建链接对象。</font>

<font style="color:#080808;background-color:#ffffff;">autoCommit：会检查该链接是否是autoCommit。如果是则执行完成后不需要提交事务。</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758855161570-1426f271-ecd7-4e97-b589-9657e0320d5f.png" width="1122.2222519509594" title="" crop="0,0,1,1" id="u407f1460" class="ne-image">





**handler#query： **

这里的ps 实际上是mybatis的代理对象，最终会调用底层JDBC API 进行查询

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758524940130-95913626-3004-422c-9654-40b67d567bb0.png" width="648.8889060785746" title="org.apache.ibatis.executor.statement.PreparedStatementHandler#query" crop="0,0,1,1" id="u8ad51ff7" class="ne-image">





### 提交事务
<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758770180225-bb356c5d-4b1b-4865-940d-b093a77144e6.png" width="568.8889039592982" title="" crop="0,0,1,1" id="ubd9eee83" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758770277062-c2d83904-a133-40c3-995d-aefc9441d380.png" width="818.8889105820367" title="org.apache.ibatis.executor.CachingExecutor#commit" crop="0,0,1,1" id="u85c0a431" class="ne-image">



将记录存入二级缓存。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758770349168-2cb23fda-2fb0-4261-ace3-deca2791c713.png" width="984.4444705233169" title="" crop="0,0,1,1" id="u46a004c9" class="ne-image">







# <font style="color:#080808;background-color:#ffffff;">Interceptor</font>
>  类似AOP机制来拦截执行过程，可以进行执行耗时统计，日志记录，SQL修改等。
>

如下面对SQL添加注释前缀，用于记录一些SQL执行信息：

```java
@Intercepts({
    @Signature(type = Executor.class, method = "query", args = {MappedStatement.class, Object.class, RowBounds.class, ResultHandler.class}),
    @Signature(type = Executor.class, method = "update", args = {MappedStatement.class, Object.class})
})
public class LogQueryAndUpdateSqlHandler implements Interceptor {
    // 拦截时调用方法
    @Override
    public Object intercept(Invocation invocation) throws Throwable {
        return LogSqlHelper.intercept(invocation, this.slowSqlThreshold, this.isOptimizeSql);
    }

    // 指定Executor 目标才开始拦截
    @Override
    public Object plugin(Object target) {
        return target instanceof Executor ? Plugin.wrap(target, this) : target;
    }

    @Override
    public void setProperties(Properties properties) {
    }
}


// 拦截prepare
@Intercepts({
    @Signature(
        type = StatementHandler.class,
        method = "prepare",
        args = {Connection.class, Integer.class}
    )
})
public class SqlCommentInterceptor implements Interceptor {

    @Override
    public Object intercept(Invocation invocation) throws Throwable {
        // 1. 获取原始 SQL
        StatementHandler handler = (StatementHandler) invocation.getTarget();
        String originalSql = handler.getBoundSql().getSql();

        // 2. 添加自定义注释前缀
        String commentedSql = "/* 业务标记 */ " + originalSql;

        // 3. 通过反射修改 SQL
        Field boundSqlField = handler.getBoundSql().getClass().getDeclaredField("sql");
        boundSqlField.setAccessible(true);
        boundSqlField.set(handler.getBoundSql(), commentedSql);

        // 4. 继续执行原逻辑
        return invocation.proceed();
    }
}
```



在创建Executor的时候会织入拦截器

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758867550756-9e52a957-ec72-41da-bf97-445de3c7abce.png" width="864.4444673444024" title="" crop="0,0,1,1" id="u4c77cb7c" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758868910292-88bd3bcd-5ad4-48ad-8aa2-2e82a4ac1cf7.png" width="840.0000222524013" title="" crop="0,0,1,1" id="uc4e73c75" class="ne-image">





除了Executor外，下面方法也都可以进行拦截处理

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1758869336719-69444ba4-5117-4df1-a7e0-7f6c50767063.png" width="1100.0000291400493" title="" crop="0,0,1,1" id="ub7100222" class="ne-image">





## 分页
1. 使用MybatisPlus 自带的分页拦截器

```java
@Bean
public MybatisPlusInterceptor mybatisPlusInterceptor() {
    MybatisPlusInterceptor interceptor = new MybatisPlusInterceptor();
    PaginationInnerInterceptor paginationInnerInterceptor = new PaginationInnerInterceptor();
    paginationInnerInterceptor.setDbType(DbType.MYSQL);
    paginationInnerInterceptor.setOverflow(true);
    interceptor.addInnerInterceptor(paginationInnerInterceptor);
    return interceptor;
}
```



2. pagehelper  
   引入依赖

```xml
<dependency>
  <groupId>com.github.pagehelper</groupId>
  <artifactId>pagehelper-spring-boot-starter</artifactId>
  <version>1.4.6</version>
</dependency>
```


PageHelperAutoConfiguration会自动注入PageInterceptor：  
<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759132929762-df2eba4b-7eb2-4c45-aca8-ca3fa8b2b61e.png" width="1166.6666975727796" title="com.github.pagehelper.autoconfigure.PageHelperAutoConfiguration#afterPropertiesSet" crop="0,0,1,1" id="u1ba2173b" class="ne-image">


查询前使用：PageHelper.startPage(1, 2);

会将Page参数信息存入ThreadLocal中，在执行查询过程中，pageHelper的拦截器会自动处理相关分页信息。

执行结束后pageHelper会自动remove ThreadLocal的信息。



## SQL 记录
mybatis 默认打印的SQL日志都是带参数的预编译SQL，不便于日志分析， 也没有记录执行时间。 <font style="color:rgb(77, 77, 77);"></font>

```java
// 只拦截Executor的这两个方法， save 也是执行的update
@Intercepts({
    @Signature(type = Executor.class, method = "query", args = {MappedStatement.class, Object.class, RowBounds.class, ResultHandler.class}),
    @Signature(type = Executor.class, method = "update", args = {MappedStatement.class, Object.class})
})
public class LogQueryAndUpdateSqlHandler implements Interceptor {
 @Override
 public Object intercept(Invocation invocation) throws Throwable {
     return LogSqlHelper.intercept(invocation, this.slowSqlThreshold, this.isOptimizeSql);
 }

 @Override
 public Object plugin(Object target) {
     // 这里不判断也可以， 内部会判断 是否符合@Signature的type
     return  target instanceof Executor ? Plugin.wrap(target, this) : target;
 }
}
```

```java
package com.example.springbootadmin.mybatis;

public class LogSqlHelper {

    private static final Logger log = LoggerFactory.getLogger(LogSqlHelper.class);

    private static final String SELECT = "select";

    private static final String FROM = "from";

    private static final String SIMPLE_SELECT = "select * ";

    private static final int MAX_SQL_LENGTH = 120;

    private static final String PATTERN = "yyyy-MM-dd HH:mm:ss";

    public LogSqlHelper() {
    }

    public static Object intercept(Invocation invocation, int slowSqlThreshold, boolean optimizeSql) throws Throwable {
        long startTime = System.currentTimeMillis();
        Object returnValue = invocation.proceed();
        long cost = System.currentTimeMillis() - startTime;
        if (cost >= (long) slowSqlThreshold) {
            log.info("cost = {} ms, affected rows = {}, SQL: {}",
                     cost, formatResult(returnValue), formatSql(invocation, optimizeSql));
        }
        return returnValue;
    }

    private static Object formatResult(Object obj) {
        if (obj == null) {
            return "NULL";
        } else if (obj instanceof List) {
            return ((List) obj).size();
        } else if (!(obj instanceof Number) && !(obj instanceof Boolean) && !(obj instanceof Date)
                   && !(obj instanceof String)) {
            return obj instanceof Map ? ((Map) obj).size() : 1;
        } else {
            return obj;
        }
    }

    private static String formatSql(Invocation invocation, boolean isOptimizeSql) {
        MappedStatement mappedStatement = (MappedStatement) invocation.getArgs()[0];
        Object parameter = null;
        if (invocation.getArgs().length > 1) { // 拦截的方法query、update 都是有多个参数的。
            parameter = invocation.getArgs()[1]; // SQL的参数对象
        }
        BoundSql boundSql = mappedStatement.getBoundSql(parameter);    // 通过参数对象重新构建BoundSql，这里会包含数据库生成的主键信息
        Configuration configuration = mappedStatement.getConfiguration();
        Object parameterObject = boundSql.getParameterObject();
        List<ParameterMapping> parameterMappings = boundSql.getParameterMappings();
        String sql = boundSql.getSql().replaceAll("[\\s]+", " ");
        String formatSql = sql.toLowerCase();
        if (isOptimizeSql && formatSql.startsWith(SELECT) && formatSql.length() > MAX_SQL_LENGTH) {
            sql = SIMPLE_SELECT + sql.substring(formatSql.indexOf(FROM));
        }
        // 通过参数对象填充SQL占位符
        if (parameterMappings.size() > 0 && parameterObject != null) {
            TypeHandlerRegistry typeHandlerRegistry = configuration.getTypeHandlerRegistry();
            if (typeHandlerRegistry.hasTypeHandler(parameterObject.getClass())) {
                sql = sql.replaceFirst("\\?", formatParameterValue(parameterObject));
            } else {
                MetaObject metaObject = configuration.newMetaObject(parameterObject);
                for (ParameterMapping parameterMapping : parameterMappings) {
                    String propertyName = parameterMapping.getProperty();
                    Object obj;
                    if (metaObject.hasGetter(propertyName)) {
                        obj = metaObject.getValue(propertyName);
                     sql = sql.replaceFirst("\\?", formatParameterValue(obj));
                 } else if (boundSql.hasAdditionalParameter(propertyName)) {
                     obj = boundSql.getAdditionalParameter(propertyName);
                     sql = sql.replaceFirst("\\?", formatParameterValue(obj));
                 }
             }
         }
     }
     return sql;
 }

 private static String formatParameterValue(Object obj) {
     if (obj == null) {
         return "NULL";
     } else {
         String value = obj.toString();
         if (obj instanceof Date) {
             DateFormat dateFormat = new SimpleDateFormat(PATTERN);
             value = dateFormat.format((Date) obj);
         }
         if (!(obj instanceof Number) && !(obj instanceof Boolean)) {
             value = "'" + value + "'";
         }
         return value;
     }
 }
}
```



打印的结果如下：

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1760494219557-6429c05f-e69f-4ca9-bc25-ba4620f5a0f6.png" width="1947.7778293762692" title="" crop="0,0,1,1" id="u4895a8c2" class="ne-image">



当执行批量save 逻辑的时候，这里会分开打印多条insert SQL。









**如果有多个拦截器的时候，需要注意定义顺序。可以像pageHelper中的那样在afterPropertiesSet中手动添加Interceptor**



# 其他内容
## Executor:
可以通过配置指定executor-type: simple（默认）， 都只在sqlSession会话有效。

**BaseExecutor**： 抽象类，实现了**一级缓存（无法关闭）**。 执行update会清理所有缓存对象。



具体实现：

CachingExecutor： 会处理**二级缓存**，默认**关闭**(query方法),当update后执行查询会清理缓存。 namespace独享。默认都会使用CachingExecutor进行包装下面的执行器。

+ SimpleExecutor：默认执行器，同一个事务中，重复执行会有缓存
+ ReuseExecutor：会缓存SQL 对应的PreparedStatement。 由于默认有一级缓存的存在，这里貌似一直用不上。
+ BatchExecutor： 用于批量操作优化性能。mybatis-plus 中的saveBatch相关方法会使用该执行器。具体可以查看SqlHelper



## 缓存：
+ 先查二级缓存（默认关闭，@CacheNamespace： 默认namespace 独有。 @CacheNamespaceRef），PerpetualCache。 MappedStatement#cache
+ 再查一级缓存： sqlSession级别，在创建Executor时生成 PerpetualCache， BaseExecutor#localCache。



## <font style="color:#080808;background-color:#ffffff;">ISqlInjector </font>
> <font style="color:#080808;background-color:#ffffff;">定义了各种默认CRUD通用的方法，可以继承默认的进行扩展方法</font>
>

<font style="color:#080808;background-color:#ffffff;">mybatis-plus中内置的</font>**<font style="color:#080808;background-color:#ffffff;">DefaultSqlInjector</font>**<font style="color:#080808;background-color:#ffffff;">：实现ISqlInjector。</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1759131300321-0a30a480-dab8-4148-aee3-974c94a43f83.png" width="812.2222437387637" title="" crop="0,0,1,1" id="sKSlZ" class="ne-image">



###  自定义实现 insert duplicate Update
当key不存在时 执行insert、 存在时执行update。

<font style="color:#080808;background-color:#ffffff;">insert into test (id,b, c) value (1,2,2) on duplicate key update b = 2;</font>

<font style="color:#080808;background-color:#ffffff;">  
</font><font style="color:#080808;background-color:#ffffff;">参考Insert来实现：  
</font>

```java
public class InsertDuplicateUpdate extends AbstractMethod {
    private static final String name = "insertDuplicateUpdate";
    private static final String sqlScript = "<script>\nINSERT INTO %s %s VALUES %s on duplicate key update %s\n</script>";

    public InsertDuplicateUpdate() {
        super(name);
    }

    @Override
    public MappedStatement injectMappedStatement(Class<?> mapperClass, Class<?> modelClass, TableInfo tableInfo) {
        KeyGenerator keyGenerator = NoKeyGenerator.INSTANCE;
        SqlMethod sqlMethod = SqlMethod.INSERT_ONE;
        String columnScript = SqlScriptUtils.convertTrim(tableInfo.getAllInsertSqlColumnMaybeIf(null),
                                                         LEFT_BRACKET, RIGHT_BRACKET, null, COMMA);
        String valuesScript = SqlScriptUtils.convertTrim(tableInfo.getAllInsertSqlPropertyMaybeIf(null),
                                                         LEFT_BRACKET, RIGHT_BRACKET, null, COMMA);
        String keyProperty = null;
        String keyColumn = null;
        // 表包含主键处理逻辑,如果不包含主键当普通字段处理
        if (StringUtils.isNotBlank(tableInfo.getKeyProperty())) {
            if (tableInfo.getIdType() == IdType.AUTO) {
                /* 自增主键 */
                keyGenerator = Jdbc3KeyGenerator.INSTANCE;
                keyProperty = tableInfo.getKeyProperty();
                keyColumn = tableInfo.getKeyColumn();
            } else if (null != tableInfo.getKeySequence()) {
                keyGenerator = TableInfoHelper.genKeyGenerator(this.methodName, tableInfo, builderAssistant);
                keyProperty = tableInfo.getKeyProperty();
                keyColumn = tableInfo.getKeyColumn();
            }
        }
        // 前面都是Insert copy来的逻辑
        String sqlSet = SqlScriptUtils.convertTrim(tableInfo.getAllSqlSet(tableInfo.isWithLogicDelete(), null), null, null, null, COMMA);
        String sql = String.format(sqlScript, tableInfo.getTableName(), columnScript, valuesScript, sqlSet);
        SqlSource sqlSource = languageDriver.createSqlSource(configuration, sql, modelClass);
        return this.addInsertMappedStatement(mapperClass, modelClass, getMethod(sqlMethod), sqlSource, keyGenerator, keyProperty, keyColumn);
    }
}
```

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">创建自定义SQLInjector：  
</font><font style="color:#080808;background-color:#ffffff;">继承DefaultSqlInjector，在原有基础上加入InsertDuplicateUpdate。 </font>

```java
@Component       // 会自动替换默认的DefaultSqlInjector
public class CustSqlInjector extends DefaultSqlInjector {
    @Override
    public List<AbstractMethod> getMethodList(Class<?> mapperClass, TableInfo tableInfo) {
        List<AbstractMethod> methodList = super.getMethodList(mapperClass, tableInfo);
        methodList.add(new InsertDuplicateUpdate());
        return methodList;
    }
}
```

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">Mapper接口：  
</font><font style="color:#080808;background-color:#ffffff;">参考insert 添加方法即可使用</font>

```java
int insertDuplicateUpdate(User entity);
```

<font style="color:#080808;background-color:#ffffff;"></font>









## mybatis 核心类：
MybatisMapperProxy：Mapper接口代理对象

SqlSessionTemplate:  Mapper接口执行目标方法后会委托到SqlSessionTemplate， 提供了selectXXX方法。selectXXX 最后委托给代理对象执行逻辑。

SqlSessionInterceptor：拦截上面selectXXX执行逻辑。 从<font style="color:#080808;background-color:#ffffff;">DefaultSqlSessionFactory或ThreadLocal</font>获取DefaultSqlSession类。

SpringManagedTransaction：在开启SqlSession 的时候，从<font style="color:#080808;background-color:#ffffff;">TransactionFactory中获取的Transaction（此时并</font>**<font style="color:#080808;background-color:#ffffff;">没有获取</font>**<font style="color:#080808;background-color:#ffffff;">真正的连接，在执行PrepareStatement的时候才会获取底层连接）。</font>



DefaultSqlSession：包含了Executor（包含Transaction），Configuration

MappedStatement: 对应一个mapper方法的相关定义信息



SystemMetaObject.forObject(): 方便set，get的工具类。 支持`属性.属性` 进行操作

Reflector： 会缓存类的所有get，set方法







解析生成SQL Script

RawSqlSource： 不需要动态判断的， 没有If 相关的标签，SQL 始终都是一个。

DynamicSqlSource： 每次执行都需要通过条件动态生成最终SQL。



参考文章：

核心流程

[https://blog.csdn.net/weixin_45505313/article/details/104855453](https://blog.csdn.net/weixin_45505313/article/details/104855453)

SQL解析生成MappedStatement

[https://blog.csdn.net/weixin_45505313/article/details/120551879](https://blog.csdn.net/weixin_45505313/article/details/120551879)


