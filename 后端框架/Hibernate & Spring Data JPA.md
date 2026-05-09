## 前言：
JPA （java persistence API）作为数据库ORM规范， 具体实现代表：Hibernate、<font style="color:rgba(0, 0, 0, 0.6);">EclipseLink。Hibernate比较常用。</font>



JDBC作为Java 与数据库连接的桥梁，JPA 也不例外，因此在一些特殊情况下想要查看最终生成的SQL语句执行过程

<font style="color:rgba(0, 0, 0, 0.6);">可加断点在下面方法，debug查看执行SQL 过程：</font>

<font style="color:rgba(0, 0, 0, 0.6);">com.mysql.cj.NativeSession#execSQL （在执行任意SQL 时都会进入该方法）</font>

<font style="color:rgba(0, 0, 0, 0.6);"></font>

参考学习：

springData JPA：[https://blog.csdn.net/qq_40161813/category_11746503.html](https://blog.csdn.net/qq_40161813/category_11746503.html)

Hibernate官网：[https://docs.jboss.org/hibernate/orm/5.2/userguide/html_single/Hibernate_User_Guide.html#criteria](https://docs.jboss.org/hibernate/orm/5.2/userguide/html_single/Hibernate_User_Guide.html#criteria)

# Hibernate
源码： 5.4.20

核心类：sessionImpl：

JPA 中 DML 操作首先都是系列的DefaultXXXEventListener 进行处理：

> DefaultDeleteEventListener, DefaultMergeEventListener,  DefaultPersistEventListener
>



## 实体状态关系
new的一个实体类 ：

+ 在调用merge的时候 会作为Datached 状态；
+ 在调用persist的时候 会作为Transient 状态；



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734860471231-e8abc432-a852-43f3-af59-05b8adefa55b.png" width="965" title="https://blog.csdn.net/qq_40161813/article/details/129236853" crop="0,0,1,1" id="u44ec6a81" class="ne-image">







## 基本使用
其中的em 为EntityManger对象， 在spring data jpa 中可以直接@PersistenceContext 注解进行引入。

Spring Data JPA 底层也是对下面方式进行的一些列封装。

```java
@PersistenceContext(unitName = "name")
private EntityManager entityManager;

// HQL， 
Query query = em.createQuery("from User where userIdx.id = :id"); // 任何DML SQL
query.setParameter("id", 1);
User user = (User) query.getSingleResult();

// native
Query nativeQuery = em.createNativeQuery("select * from users");  // 任何DML SQL


// em.find()
// em.persist();
// em.merge()
```



## 核心类
SessionImpl： 定义了常见的 DML 方法，

PersistenceContext： 记录的会话中的对象信息，缓存等。

SingleTableEntityPersister： 数据库实体 类信息， 包含相关DML SQL， save，update方法的处理等，他跟底层JDBC最近。<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735135684476-00d5796e-1ad0-432e-a5a2-4fc84406b4bf.png" width="706" title="" crop="0,0,1,1" id="u40fdef89" class="ne-image">



### 继承关系
<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1736081388837-afac02d9-f5c2-4dbe-a182-1693059b1b81.png" width="1601" title="" crop="0,0,1,1" id="u80ebec2f" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734965640966-898a5b00-bf4a-4d62-a072-8eb700fcea7c.png" width="831" title="" crop="0,0,1,1" id="u0d4e03f3" class="ne-image">







<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734965655156-e55bf374-01f5-4919-9c75-f7e68ac6b2b4.png" width="933" title="" crop="0,0,1,1" id="u70969e9e" class="ne-image">



下面介绍sessionImpl 中的一些API

## Query
> 直接构造SQL 进行查询，**<font style="color:#81DFE4;background-color:#2F4BDA;">不会查询缓存</font>**。在查询前会尝试flush 缓存中的内容, 防止前面修改了数据，没有刷新到数据库，导致没有查到最新值。
>
> 在查询结束时：
>
> 1. 如果是JPQL查询，会将结果 放入到缓存中，即：entitiesByKey，  EntityEntryContext。
>
> 查询结束会判断缓存中是否存在，如果不存在那么写入缓存。如果缓存存在，直接返回缓存的值，丢弃新的查询。即：<font style="color:#601BDE;">代码层面保证了可重复读</font>。
>
> 2. 如果是native 查询，查询结束不会放入缓存。
     >     1.  debug 发现： jpql CustomLoader#entityPersisters 不会空；而nativeSQL 是空导致不会写入缓存。
>



demo<font style="color:#080808;background-color:#ffffff;">：</font>

```java
// @Transactional 管理

// nativeSQL,   entityManager.createNativeQuery 等价于session.createSQLQuery()
Query nativeQuery = entityManager.createNativeQuery("select * from student where id = ?");
nativeQuery.setParameter(1, 1);
List resultList = nativeQuery.getResultList();
resultList.forEach(System.out::println);




//  jpql
Query nativeQuery = entityManager.createQuery("from Student where id = ?1");
nativeQuery.setParameter(1, 1);
List<Student> resultList = nativeQuery.getResultList();
resultList.forEach(System.out::println);
```

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">createQuery：</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734789526644-97b03da5-c465-4596-9937-7c4d3c8c5748.png" width="984" title="org.hibernate.internal.AbstractSharedSessionContract#createQuery(java.lang.String)" crop="0,0,1,1" id="u98e6d735" class="ne-image">



这里会构造一个HQLQueryPlan 对象出来，后续缓存起来。  该对象包含<font style="color:rgb(26, 32, 41);">SQL语句、参数绑定类型等。  </font>

<font style="color:rgb(26, 32, 41);">在使用Spring Data JPA 的@Query 注解编写的JPAL 或HQL，项目初始化时都会构造该对象。</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734789505633-134f2cc7-c458-4969-948e-6186a4462a40.png" width="1217" title="" crop="0,0,1,1" id="u26866b00" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">调用getSingleResult：</font>

<font style="color:#080808;background-color:#ffffff;">不管是单个还是多个 都会执行list():</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734785393818-8bff90ea-db31-41c2-a850-1eb9b970f7f9.png" width="667" title="org.hibernate.query.internal.AbstractProducedQuery#getSingleResult" crop="0,0,1,1" id="u45bff1f8" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">PS 对象获取结果集：</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734785728177-603827c1-9cb6-476c-bd1e-01ef8c072c34.png" width="726" title="org.hibernate.engine.jdbc.internal.ResultSetReturnImpl#extract(java.sql.PreparedStatement)" crop="0,0,1,1" id="u25d6097d" class="ne-image">





<font style="color:#080808;background-color:#ffffff;">最终执行到MySQL的执行代码：</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734785659983-9a3953c6-e9cf-463c-97a2-fb6e3ea10157.png" width="1067" title="com.mysql.cj.NativeSession#execSQL" crop="0,0,1,1" id="ue5efc181" class="ne-image">



处理结果集：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734786000712-7739aba8-c740-46cd-93aa-ef713647ca60.png" width="707" title="org.hibernate.loader.Loader#getRowsFromResultSet" crop="0,0,1,1" id="uc389e289" class="ne-image">



创建实例对象，如果entitiesByKey 中已经存在，直接返回老的对象。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734792209203-d53f1dab-10a5-42f4-b1c8-28a6f5e154c3.png" width="936" title="org.hibernate.loader.Loader#getRow" crop="0,0,1,1" id="u272bac65" class="ne-image">





添加EntityEntry 到缓存中

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734786214870-85ca0470-a2ad-488b-a081-419bf351f086.png" width="691" title="org.hibernate.engine.internal.TwoPhaseLoad#addUninitializedEntity" crop="0,0,1,1" id="u192a7a1d" class="ne-image">



**分别添加：****<font style="color:#080808;background-color:#ffffff;">entitiesByKey， EntityEntryContext</font>**

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734787755470-e97037ee-f68c-43f2-9d46-b2836589095c.png" width="795" title="" crop="0,0,1,1" id="u4726ff68" class="ne-image">





## <font style="color:#080808;background-color:#ffffff;">doQuery </font>
> <font style="color:#601BDE;">上面简单介绍了Query 查询过程，这里继续详细分析下：</font>
>

<font style="color:#117CEE;"></font>

在调用list 查询时、以及缓存中找不到查询DB， 最终都会走入下面堆栈：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734932091344-2a0e06b2-96d5-4461-a8fb-81591a7ffad8.png" width="597" title="" crop="0,0,1,1" id="JVfTQ" class="ne-image">







<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734932053454-f5682243-4516-4ed0-9546-d7e3b2822e54.png" width="966" title="" crop="0,0,1,1" id="s9SSq" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734931373836-4e91c3ab-c7dd-4c0c-822b-ba6391a38000.png" width="774" title="" crop="0,0,1,1" id="CKK7H" class="ne-image">

### <font style="color:#080808;background-color:#ffffff;">getRowFromResultSet</font>
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734933268634-8575f7ee-6f55-407d-8366-8929320b0256.png" width="631" title="" crop="0,0,1,1" id="WbFnd" class="ne-image">


#### <font style="color:#080808;background-color:#ffffff;">extractKeysFromResultSet</font>
> 提取key
>

有查询参数： findById 这种查询、以及使用查询参数构造。HQL 除外

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734934594584-2c860700-72b9-44f6-bdcc-acaf6b835953.png" width="1048" title="org.hibernate.loader.Loader#extractKeysFromResultSet" crop="0,0,1,1" id="qN63o" class="ne-image">



没有查询参数的时候：通过结果集构造

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734933623776-4ecd117b-8ba5-4a6d-977f-45d4db317948.png" width="928" title="" crop="0,0,1,1" id="gQPgX" class="ne-image">

#### <font style="color:#080808;background-color:#ffffff;">添加缓存--getRow</font>
> 参数key： 即主键
>

当缓存中有 执行instanceAlreadyLoaded，做一些额外操作，直接返回缓存中的对象。保证了可重复读

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734876488528-ba1dfc1e-490f-4946-9a4c-cc7e2957f64c.png" width="1034" title="org.hibernate.loader.Loader#getRow" crop="0,0,1,1" id="zBDpT" class="ne-image">





#### instanceNotYetLoaded
缓存中没有的时候， 会构造参数写入缓存中。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734919722558-8febde94-4a86-4c78-9501-f6241efe781f.png" width="947" title="" crop="0,0,1,1" id="kG9L6" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734919793068-c51d2d30-c577-46b1-ae9c-2efa22fb26dd.png" width="533" title="" crop="0,0,1,1" id="bfGvm" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734920113067-0aba5108-40c6-4680-95ff-abb7e1e656b5.png" width="856" title="" crop="0,0,1,1" id="tTXbh" class="ne-image">



#### <font style="color:#080808;background-color:#ffffff;">loadFromResultSet</font>
##### <font style="color:#080808;background-color:#ffffff;">addUninitializedEntity</font>
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734876545117-441f3295-fc4c-4bf2-9579-c1502c4dee3b.png" width="734" title="org.hibernate.engine.internal.TwoPhaseLoad#addUninitializedEntity" crop="0,0,1,1" id="wssfH" class="ne-image">



下面依次向 <font style="color:#080808;background-color:#ffffff;">entitiesByKey、entityEntryContext 中添加对象。此时entity 不值包含 key 对应的字段，其余字段为null。</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734962522400-6dd51bfb-969b-4175-8be8-d14ce6d71e45.png" width="691" title="" crop="0,0,1,1" id="wH6Ia" class="ne-image">



addEntity：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734876604035-164fad49-873d-4939-9105-5276dba3d665.png" width="747" title="" crop="0,0,1,1" id="BARpQ" class="ne-image">





addEntry：

EntityEntryContext 添加EntityEntry

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734876789457-15fe8e5f-764d-465c-9ed6-e03427471d13.png" width="876" title="" crop="0,0,1,1" id="tDal8" class="ne-image">





##### <font style="color:#080808;background-color:#ffffff;">hydrate</font>
> ResultSet 中提取的值仅仅保存在EntityEntry的loadedState中
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734920194794-82f06320-085e-4420-853c-24c2969c698b.png" width="974" title="" crop="0,0,1,1" id="oZIPi" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734928131537-a6b3eb8f-d8dc-4fd7-a182-c5cc6d3b1dd0.png" width="453" title="" crop="0,0,1,1" id="eRs4z" class="ne-image">



##### postHydrate
该方法会重新替换将EntityEntryContext 中的EntityEntry， values 作为 <font style="color:#080808;background-color:#ffffff;">loadedState</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734963014848-5810fff4-676f-45aa-9fe3-bc814bfe2da6.png" width="875" title="" crop="0,0,1,1" id="gIQCH" class="ne-image">



### <font style="color:#080808;background-color:#ffffff;">initializeEntitiesAndCollections</font>
> 前面得到的result 对象只包含了key对应的字段， 这里会实例化key 之外的字段
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734928615946-5ad56a03-b18d-4aac-8b5d-0c0aa7d0245c.png" width="643" title="" crop="0,0,1,1" id="BeISV" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734931751290-11dbdda9-bb42-41f1-82c9-e20cd9833eda.png" width="992" title="" crop="0,0,1,1" id="grkBv" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734931821645-1e328bd3-e765-47d1-ba4f-3a1476cd0efd.png" width="1087" title="" crop="0,0,1,1" id="IBOK8" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734928520907-edccd6a9-3936-4e96-a28f-74cae67f4f65.png" width="954" title="" crop="0,0,1,1" id="uSIdL" class="ne-image">





## find
> 会使用JPA 的缓存进行查找： <font style="color:#080808;background-color:#ffffff;">User user = session.find(User.class, new UserIdx(1,1));</font>
>



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734788240406-9d4784c8-ab59-4bfb-86f4-4705a4f3cdcc.png" width="887" title="" crop="0,0,1,1" id="u1fb8c541" class="ne-image">





依次向下跟踪到：fireLoad

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734788351617-1b094a4c-411d-439a-af3a-154a705280a7.png" width="696" title="" crop="0,0,1,1" id="u9707e783" class="ne-image">





### 缓存查询：
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734788538215-a3faaee6-3425-4053-a5cf-b104e62976e8.png" width="1141" title="org.hibernate.event.internal.DefaultLoadEventListener#doLoad" crop="0,0,1,1" id="u260a72bf" class="ne-image">



一级缓存：

这里的keyToLoad：  <font style="color:#080808;background-color:#ffffff;">new EntityKey( id, persister )</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734788754819-80237945-891f-459b-b7bf-7f2f5cdcca69.png" width="1149" title="" crop="0,0,1,1" id="ud432a5ce" class="ne-image">



<font style="color:#080808;background-color:#ffffff;">从EntityEntryContext 中获取EntityEntry， 实际上是从 nonEnhancedEntityXref中获取。</font>

```java

// 这里的Object 对应 entitiesByKey 中的Obj， 即实体对象。
// ManagedEntity 用来记录 实体对象的状态信息。  注意这里是IdentityHashMap
private transient IdentityHashMap<Object,ManagedEntity> nonEnhancedEntityXref;
```



## delete
### 缓存中不存在
当删除一个缓存中不存在（detached）的对象时，会抛出异常，JPA 为了事务一致性等，默认禁止这样操作。

可以直接调用merge 方法，会将对象作为maneged。然后在调用delete





<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734855244253-e23ab68d-4d82-47e1-b340-150618ddc390.png" width="729" title="" crop="0,0,1,1" id="u999c2a9b" class="ne-image">





调用isTransient 没有查到的话，会直接return。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734857416966-deaf68a7-2645-46c0-b806-4bc881815d70.png" width="956" title="" crop="0,0,1,1" id="uf58999be" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734857463543-81593ea9-d3f2-4a66-9ec9-57692866637a.png" width="856" title="" crop="0,0,1,1" id="u557c85aa" class="ne-image">





抛出异常：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734857219439-9262c96e-790b-4643-9257-17051cff7d5d.png" width="1037" title="DefaultDeleteEventListener#performDetachedEntityDeletionCheck" crop="0,0,1,1" id="uc99670ca" class="ne-image">







### 缓存中存在
当删除一个缓存中存在的对象时，会设置EntityEntry 为deleted。 同时添加deleteAction 到ActionQueue。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734790619726-e4155371-0ff4-4b53-8ba7-f53f25242b71.png" width="910" title="" crop="0,0,1,1" id="u33321d89" class="ne-image">





## save
调用save 后会执行DefaultSaveEventListener， 在springboot jpa的save方法会先调用查询接口将数据存入缓存中。



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734858380067-7f88b107-831a-4ab4-9338-a63a7e034ec5.png" width="934" title="" crop="0,0,1,1" id="udf8098e9" class="ne-image">

当缓存中已经存在的时候，内部仅仅作一些校验。





entityIsTransient：缓存中没有

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734858526450-b86980d0-2d31-4e0c-93f9-93e3b5f47096.png" width="1030" title="" crop="0,0,1,1" id="u1185cec3" class="ne-image">





## persist
> 持久化对象
>

+ 当缓存中没有对象，即new 一个对象时，返回TRANSIENT，会直接向缓存中加入EntityEntry，成为managed， 然后注册InsertActionEvent
+ 当缓存中有这个对象， 状态为<font style="color:#080808;background-color:#ffffff;">PERSISTENT，</font> 会调用 <font style="color:#080808;background-color:#ffffff;">entityIsPersistent，不会有什么处理。 事务提交的时候，会检查对象状态进行merge，处理更新</font>



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734859226912-3bc17466-4aa5-45be-bbdc-cad8cf0535fb.png" width="1172" title="org.hibernate.event.internal.DefaultPersistEventListener#onPersist(org.hibernate.event.spi.PersistEvent, java.util.Map)" crop="0,0,1,1" id="u606841d0" class="ne-image">





<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734859387707-dddb8458-109b-48bb-9800-0c395364b6e4.png" width="967" title="" crop="0,0,1,1" id="u1b916c4d" class="ne-image">





这里会向缓存中加入EntityEntry， 注册InsertActionEvent

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734859399954-8f11e17e-a33a-4b95-bdd5-9f8f369a795b.png" width="746" title="" crop="0,0,1,1" id="ud01ce2b5" class="ne-image">





<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1736996016872-a9d08e43-a9c8-4836-8b94-605f301af00d.png" width="785" title="" crop="0,0,1,1" id="ua957e191" class="ne-image">





判断是否需要生成<font style="background-color:#FBDE28;">Version</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1736996049390-26fc03d3-c9c6-4441-9a4f-dbff64525cd6.png" width="626" title="org.hibernate.event.internal.AbstractSaveEventListener#substituteValuesIfNecessary" crop="0,0,1,1" id="u346672c7" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1737009124577-1cc81358-2f2c-4a64-9dd5-b79a512b796d.png" width="915" title="" crop="0,0,1,1" id="uc6194352" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1737008865048-6e6cf60c-4b32-4df8-92f7-a7c581bb9ca2.png" width="784" title="" crop="0,0,1,1" id="u754423ca" class="ne-image">



Integer 类型，默认0

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1737008873824-4c516c05-bf83-4bf2-8f87-4501226b2bbb.png" width="672" title="" crop="0,0,1,1" id="u81541fe1" class="ne-image">

## onMerge：


> 如果从缓存、db 查不到这个对象（deleted 状态视为查不到），那么执行 save 逻辑。
>
> + 如果当前delete 的ActionEvent 进行执行，即发出delete 的SQL，然后在向ActionQueue 中添加InsertActionEvent
>
> 如果能查到当前对象，那么会处理merge 对象的操作
>





<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734772165060-15176bca-f6af-4e53-9019-d81579c868ac.png" width="937" title="" crop="0,0,1,1" id="u678ae542" class="ne-image">





核心逻辑：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735175020622-063858c9-415a-4585-82a2-c818e1e2703d.png" width="1036" title="" crop="0,0,1,1" id="u905ab201" class="ne-image">

根据不同的对象状态进入不同的逻辑

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734772209125-35c47c79-ab69-44e9-ac5c-ebf361533f14.png" width="882" title="" crop="0,0,1,1" id="u2ba8ad07" class="ne-image">





### entityIsDetached
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734772453645-77239750-3baf-4083-b7f2-9819b921d354.png" width="1044" title="图中有误：如果查到，会处理merge 逻辑" crop="0,0,1,1" id="ua44ab85a" class="ne-image">



上面如果查到了结果，则会处理merge 逻辑：新的对象属性覆盖缓存中的对象属性（仅仅处理非key）。 **<font style="color:#DF2A3F;">同时会将对象 作为managed 状态。 在事务提交的时候，会调用flush 处理该EntityEntry。</font>**

**<font style="color:#DF2A3F;"></font>**

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735047725548-d92412d1-bbcc-4fee-b057-e22a586c9844.png" width="922" title="" crop="0,0,1,1" id="ua93206f2" class="ne-image">

**<font style="color:#DF2A3F;"></font>**

**<font style="color:#DF2A3F;"></font>**

**<font style="color:#DF2A3F;"></font>**

### entityIsTransient
执行entityIsTransient： 下面会分两个逻辑进行处理



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734773449893-c5e7e3bf-e105-4c7f-a287-76db51ff6963.png" width="1014" title="org.hibernate.event.internal.AbstractSaveEventListener#performSave" crop="0,0,1,1" id="u35187e53" class="ne-image">





### flush 调delete 的事件
EntityDeleteAction#execute：



会执行delete 操作，然后在清理 <font style="color:#080808;background-color:#ffffff;">entityEntryContext、 以及entitiesByKey、nullifiableEntityKeys</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734773682265-154a2471-5522-4d35-8e3e-54cc075f610b.png" width="1106" title="" crop="0,0,1,1" id="u7dc5e20c" class="ne-image">



delete 入口：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734773496403-e583d6d4-0357-4439-83e6-d03afe5d81bf.png" width="822" title="" crop="0,0,1,1" id="ua90bdac6" class="ne-image">





### 执行save 的逻辑


<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734774683807-457a1356-db12-45a8-a9e1-efe9d0096761.png" width="1030" title="" crop="0,0,1,1" id="u01d179f1" class="ne-image">





<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734774437947-e370f21f-88a0-4b7a-aab4-67225cc70c1f.png" width="884" title="" crop="0,0,1,1" id="u470fa4a6" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734774826041-62d45a95-1598-400d-8c69-d775bb734519.png" width="896" title="" crop="0,0,1,1" id="u88a7e047" class="ne-image">





## <font style="color:#080808;background-color:#ffffff;">update</font>
> 先查询一个数据库的对象，然后修改字段。即使不调用update 方法， 最后在处理缓存中的EntityEntry时，事务提交的时候会处理对应的EntityEntry，检查到被修改就会发出update event。
>
> 一旦检查出某个字段被修改，发起的update 语句是**所有的字段**都会重新Set。
>



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734878769259-8ec0eec7-1796-46e3-bf8a-e2405924d99d.png" width="1096" title="" crop="0,0,1,1" id="u29c39d2e" class="ne-image">





<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734878873889-4203d1a3-7f1a-4b17-a4d0-8b2d6c5f5ddd.png" width="838" title="" crop="0,0,1,1" id="u1e7fdee9" class="ne-image">



缓存中没有：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734878891097-fbc4768f-07eb-49af-8eef-8de5c9cf7934.png" width="899" title="" crop="0,0,1,1" id="u7886853f" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734878913390-8c845b0d-8547-4eea-a185-ac2f8865c0a8.png" width="646" title="" crop="0,0,1,1" id="u79730216" class="ne-image">



添加EntityEntry

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734878951789-e29390d5-b31c-446d-95bf-2145414493b1.png" width="841" title="" crop="0,0,1,1" id="u2b01fffb" class="ne-image">







## 查询缓存
<font style="color:#080808;background-color:#ffffff;">QueryResultsCache： 默认关闭</font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">1、需要同时打开下面两个参数：</font>

<font style="color:#080808;background-color:#ffffff;">hibernate.cache.use_second_level_cache： 二级缓存， 跨session</font>

<font style="color:#080808;background-color:#ffffff;">hibernate.cache.use_query_cache： 查询缓存</font>

<font style="color:#080808;background-color:#ffffff;">2、 需要指定缓存的具体实现</font>

```properties
spring.jpa.properties.hibernate.cache.region.factory_class=org.hibernate.cache.ehcache.EhCacheRegionFactory

```

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">大概是下面实现：</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1736672244730-1004a97e-a293-4f45-b8be-5035b7569ed2.png" width="995" title="" crop="0,0,1,1" id="u4e8b75ea" class="ne-image">



## flush
下面场景会触发flush操作

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735269165656-8e47e34a-37c2-4606-acfb-9c708c0a9f34.png" width="941" title="" crop="0,0,1,1" id="ufebe3d2f" class="ne-image">

1. 提交事务前，flush
2. 执行JPQL/HQL query、any nativeSQL 前 都会尝试 flush。



当flush一旦完成，ActionQueue 中的ExecutableList 都会清空，缓存中依然会保存最新的值。



### 查询接口 flush 检查
不管是 JPQL，还是HQL 都会执行到下面方法

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735269529116-ba6a728e-0e4d-451c-9bcf-f34df2a0a171.png" width="750" title="" crop="0,0,1,1" id="u9087d70c" class="ne-image">



下面方法判断缓存中是否有实体。 缓存中有内容 则执行：performExecutions

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735269688666-ce1a9af4-2ed3-4bff-84c8-c524a24c3b23.png" width="902" title="" crop="0,0,1,1" id="u11c05738" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735269504091-46a18e09-ea8d-4f92-8712-ada784c13af4.png" width="708" title="" crop="0,0,1,1" id="u116c9144" class="ne-image">





通过上面看到核心是调用**autoFlushIfRequired**方法来处理flush操作。下面简单看下其他操作是如何flush 的

### HQL
update 操作：


<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735269971539-6ff26289-39f8-4d3a-954d-9c4f2d7b6401.png" width="817" title="" crop="0,0,1,1" id="u27d9a2bc" class="ne-image">



delete 操作：

入口没啥区别

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735270515081-38d8eeca-09bf-4bdf-bf6f-cffd01aa301a.png" width="590" title="" crop="0,0,1,1" id="u56d35ee2" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735270462339-41dcdadd-36e0-4235-a7e4-2834b9d3db28.png" width="914" title="" crop="0,0,1,1" id="u714b400e" class="ne-image">



### native  SQL
**update**

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735270188306-684d74f0-7c0b-463d-9fb5-0f427da36aa3.png" width="818" title="" crop="0,0,1,1" id="u85c55305" class="ne-image">





**delete：**

跟update 都是同一个入口

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735270289468-e18d9dbb-7ddb-463e-a56b-2afc9d747af2.png" width="774" title="" crop="0,0,1,1" id="ucfe9f4d3" class="ne-image">



## 提交事务


<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734774982719-be57f8ec-4c19-4267-9b54-4c8d8690e91d.png" width="1003" title="" crop="0,0,1,1" id="wPQjj" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734774997069-139a4eaf-4637-46ab-bfc2-310fb5dc9386.png" width="870" title="" crop="0,0,1,1" id="nZa95" class="ne-image">





<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735004295229-79342eae-9cb7-4a95-9bf4-fa1e2d314e56.png" width="937" title="下面的commit :  调用底层connection#commit" crop="0,0,1,1" id="uaef95eb2" class="ne-image">





### **<font style="color:#DF2A3F;background-color:#ffffff;">beforeCompletionCallback</font>**
在事务执行前，需要先将ActionQueue 中的操作进行处理。



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734775086893-504fadfc-50c7-43d2-a065-b09a26fa9ffe.png" width="1035" title="" crop="0,0,1,1" id="ud4597c17" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735004608263-43fe384c-63b7-4146-80a5-de3767377526.png" width="554" title="" crop="0,0,1,1" id="ue7b58747" class="ne-image">



flush执行

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734775261895-9947cb61-3add-46ef-8e2f-175b5893d714.png" width="767" title="" crop="0,0,1,1" id="u85459358" class="ne-image">



执行SessionImple# doFlush -- > DefaultFlushEventListener#onFlush

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734878137618-2ccc0a3b-aa7e-40aa-bc0e-9b5440b41f5a.png" width="1013" title="" crop="0,0,1,1" id="uf4f40567" class="ne-image">



### <font style="color:#080808;background-color:#ffffff;">flush ->flushEverythingToExecutions</font>
> 事务提交的时候会调用flush 后最终会执行到这里。
>

该方法还有其他几个调用入口：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735003805621-15fb5305-cf75-4200-bc83-5cb3b4b04fcb.png" width="832" title="" crop="0,0,1,1" id="ube9f2e76" class="ne-image">





<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734879230381-1c2ea503-a558-4ef6-99c8-9684801e167a.png" width="1004" title="org.hibernate.event.internal.AbstractFlushingEventListener#flushEverythingToExecutions" crop="0,0,1,1" id="ua41cb45a" class="ne-image">



#### <font style="color:#080808;background-color:#ffffff;">prepareEntityFlushes</font>
> 核心： 将ManagedEntity 保存到reentrantSafeEntries（为了线程安全）， 后续flushEntities方法获取该对象处理。
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734879286018-a091b206-2241-4e78-affd-58a0b5dd70f1.png" width="939" title="" crop="0,0,1,1" id="ub9dd95ca" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734879299763-d2d5e517-8a85-4f45-bc5f-635f8f3c1c6b.png" width="670" title="" crop="0,0,1,1" id="u2c015d1e" class="ne-image">



当addEntityEntry， removeEntityEntry， dirty 都会设置为true， 下面将ManagedEntity 保存到reentrantSafeEntries。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734879327956-cd38f6fb-7e52-4aa1-bce9-ceaff4f269d2.png" width="811" title="" crop="0,0,1,1" id="u613429f1" class="ne-image">





#### flushEntities：
> 这里会检查reentrantSafeEntries， 即当前缓存中的对象是否有变化（跟<font style="color:#DF2A3F;background-color:#E7E9E8;">loadedState</font><font style="color:#5C0036;background-color:#E7E9E8;"> </font>比较）。如果发送了变化 会创建 update event 到ActionQueue。
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734878354049-6c9c572d-51a2-4af0-be62-ac332ee6d610.png" width="1083" title="" crop="0,0,1,1" id="ubb4bca65" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734878642326-6fcd7d80-6f64-40f5-b790-19bb8ecec75f.png" width="1015" title="" crop="0,0,1,1" id="uf91b67e9" class="ne-image">



##### <font style="color:#080808;background-color:#ffffff;">dirty check</font>
检查实体是否跟缓存中的对象发生了变化（跟**loadedState** 对比）， loadedState 表示刷新到数据库后的最新值  
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734935223762-b43e515b-64a2-44b1-984d-2ec333802a83.png" width="1016" title="DefaultFlushEntityEventListener#isUpdateNecessary(org.hibernate.event.spi.FlushEntityEvent, boolean)" crop="0,0,1,1" id="ub6781d8a" class="ne-image">



对比不同的字段

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734935333497-c9b2020d-3c66-4469-8474-376382355f5c.png" width="1131" title="org.hibernate.event.internal.DefaultFlushEntityEventListener#dirtyCheck" crop="0,0,1,1" id="u0e22ab47" class="ne-image">



实际上就是调用equals 进行比较。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1736432748255-7a9d3967-6e77-4919-b2cf-159de408bdbb.png" width="451" title="" crop="0,0,1,1" id="uc99167f3" class="ne-image">



##### <font style="color:#080808;background-color:#ffffff;">scheduleUpdate</font>
当上面检查通过，那么执行下面逻辑：



根据需要递增Version（即使手动指定也无用），添加EntityUpdateAction

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1737008064495-6ece30f3-4561-4251-a03d-79749afe92c5.png" width="802" title="" crop="0,0,1,1" id="u2a74ea7b" class="ne-image">







### performExecutes
> 执行相关的Actions
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734775378451-8aaa58ed-dec2-430a-93b3-c458a0f884fd.png" width="809" title="" crop="0,0,1,1" id="ua1557ae9" class="ne-image">





executeActions 方法内部，在最后**会清理当前的ExecutableList**

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734775514926-0eae0d46-b876-4037-8b3c-5900c8d7ea0e.png" width="916" title="" crop="0,0,1,1" id="uc6666659" class="ne-image">





#### 执行executeActions
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735271375989-4c637810-5a04-4171-8613-4bf463a89a25.png" width="762" title="" crop="0,0,1,1" id="udabf4f3b" class="ne-image">



#### EntityInsertAction
> insert 操作，在执行该方法前，缓存中已经添加了相应的EntityEntry
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734775797615-f2317137-908b-45bd-8bd6-25674d9fc241.png" width="936" title="" crop="0,0,1,1" id="A2vMN" class="ne-image">





执行insert 方法

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735117501439-4318e44b-c151-4c97-a802-cae52f048242.png" width="926" title="" crop="0,0,1,1" id="u772e7e80" class="ne-image">



支持批处理，执行addToBatch。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735117916701-2c1630e0-ed58-4c4f-8b32-96ebe81bd1e8.png" width="1054" title="" crop="0,0,1,1" id="ue386ff6e" class="ne-image">





当数量达到batchSize，执行performExecution，发出SQL

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735117947383-1ef22419-31b9-4b16-82b8-1ee8aa2a1f61.png" width="676" title="" crop="0,0,1,1" id="u716eea55" class="ne-image">



批处理行数配置：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735118017548-8135ac2c-9d58-4a94-9a16-e0df80bd5462.png" width="1040" title="" crop="0,0,1,1" id="uaaa0fd53" class="ne-image">





在上面执行完ExecutionList后，继续执行下executeBatch，内部会检查是否有还没有执行performExecution的数据。如果有会继续调用**performExecution**。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735118185755-10b889fa-433c-4938-a69b-9ce6b98ddcd4.png" width="754" title="" crop="0,0,1,1" id="uba9704d9" class="ne-image">





#### EntityUpdateAction
在进入veto分支：

会执行AbstractEntityPersister#updateOrInsert， 跟insert 类似，同样会判断是否需要使用batch 操作。



执行结束**更新EntityEntry**，也就是执行一次Action 就得更新下缓存中的值。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1736993483747-4acb22d3-7e75-4f40-97af-f449d9171486.png" width="881" title="" crop="0,0,1,1" id="u285b4b75" class="ne-image">







## 没有开启事务
在一些update操作，JPA 会自动检查是否运行事务外执行。默认是不允许的，如果没有开启事务，会抛出异常。

_**<font style="color:rgb(12, 13, 14);">可以手动打开选项：hibernate.allow_update_outside_transaction = true</font>**_

_<font style="color:rgb(12, 13, 14);"></font>_

_<font style="color:rgb(12, 13, 14);">此时执行update 的SQL 会自动向datasource 获取一个连接，然后发起 update 的sql 语句</font>_

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735480549753-2ae5afb3-9f30-4332-a3c1-9f1c19f0840a.png" width="1038" title="org.hibernate.query.internal.AbstractProducedQuery#executeUpdate" crop="0,0,1,1" id="ufcac73c5" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735481125704-e94b26a1-3235-405f-9332-f3efc8352ae7.png" width="856" title="" crop="0,0,1,1" id="u3a0ff768" class="ne-image">





## 其他api
<font style="color:#080808;background-color:#ffffff;">EntityManager.flush:  刷新ActionQueue中的任务。</font>

<font style="color:#080808;background-color:#ffffff;">EntityManager.clear: 清空缓存中的所有内容，包括ActionQueue中的任务。</font>



## 批处理
mysql 开启批处理需要设置URL参数： <font style="color:#080808;background-color:#ffffff;">rewriteBatchedStatements=true，</font>

<font style="color:#080808;background-color:#ffffff;"></font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735138890139-f69f3c1a-0599-4051-a02e-90b6264ab9d0.png" width="1173" title="com.mysql.cj.jdbc.ClientPreparedStatement#executeBatchInternal" crop="0,0,1,1" id="u8bb3cb6f" class="ne-image">



<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"> 最终insert sql 如下数据包：</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735138118994-ba1bb0a7-622d-4a02-9787-3d61950e311f.png" width="461" title="" crop="0,0,1,1" id="u2112c33e" class="ne-image">



同样批处理update 也会合并一个数据包：  
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735138275254-e11f8f86-ea7e-45d8-8de6-20acb884f632.png" width="771" title="" crop="0,0,1,1" id="ue64dcf38" class="ne-image">







# Spring Data JPA
> 分析版本： <font style="color:#080808;background-color:#ffffff;">2.3.3.RELEASE</font>
>

Spring Data Jpa 依赖与Spring data common 包，SpringData Common 包下面还有一些其他项目：



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735286086081-cd65c94e-1bb0-4eaa-adac-c5fb9745f03d.png" width="711" title="" crop="0,0,1,1" id="u95acb46e" class="ne-image">







<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735274462734-4f558e65-0441-4211-8a82-1c6f652bd7de.png" width="880" title="" crop="0,0,1,1" id="u7c4e62a6" class="ne-image">



介绍SpringData Jpa 对外提供的方法，对应JPA底层怎么执行的



## 初始化
具体实现： [https://zhuanlan.zhihu.com/p/520510314](https://zhuanlan.zhihu.com/p/520510314)

### HibernateJpaConfiguration
由spring boot 的自动装配机制，首先执行@Import HibernateJpaConfiguration.class

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735372553158-6a970d35-338e-4095-818a-8b52d34b4cce.png" width="788" title="" crop="0,0,1,1" id="ub7324867" class="ne-image">



<font style="color:#080808;background-color:#ffffff;">HibernateJpaConfiguration 继承 JpaBaseConfiguration

</font><font style="color:#080808;background-color:#ffffff;">在JpaBaseConfiguration 中会初始化JPA 核心的一些对象</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735374170566-591a13e3-a04d-46f4-8fb7-54ce67a1a07b.png" width="1079" title="" crop="0,0,1,1" id="ud49c167b" class="ne-image">



### 
通过EntityManagerFactoryBuilder构造**<font style="color:#080808;background-color:#ffffff;">LocalContainerEntityManagerFactoryBean</font>**

， 下面的packagesToScan 可以通过**<font style="color:#080808;background-color:#ffffff;">@EntityScan</font>**<font style="color:#080808;background-color:#ffffff;"> 指定。默认是启动类的包</font>



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735380089619-7bbfdf9e-adc6-4f1d-8dfd-e958efd5144a.png" width="1164" title="" crop="0,0,1,1" id="ubfc76879" class="ne-image">



### <font style="color:#080808;background-color:#ffffff;"></font>**<font style="color:#080808;background-color:#ffffff;">afterPropertiesSet</font>**
<font style="color:#080808;background-color:#ffffff;">LocalContainerEntityManagerFactoryBean 对象初始化完成后</font>**<font style="color:#080808;background-color:#ffffff;">，执行其：#afterPropertiesSet</font>**

#### Entity 扫描
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735460015015-48450aa9-0ed2-46cb-b3d9-30daccf0fe8b.png" width="899" title="" crop="0,0,1,1" id="u2374336c" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735460749195-2bb9e0ab-262b-4c90-8dcf-0cd044d63f50.png" width="566" title="" crop="0,0,1,1" id="u57d46aca" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735460725898-41c743a0-e071-4448-bf2e-a22512887ab3.png" width="964" title="" crop="0,0,1,1" id="u9e2315e0" class="ne-image">



<font style="color:#080808;background-color:#ffffff;">由于之前在启动类 使用 @</font>**<font style="color:#080808;background-color:#ffffff;">EntityScan</font>**<font style="color:#080808;background-color:#ffffff;"> 指定了包路径，因此这里为com.demo.entity。 默认没有指定为启动类同路径：</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735460281166-cf751eb8-e2d5-49e4-953f-1883f6d41a0a.png" width="749" title="org.springframework.orm.jpa.persistenceunit.DefaultPersistenceUnitManager#buildDefaultPersistenceUnitInfo" crop="0,0,1,1" id="u416bf74c" class="ne-image">



仅支持如下四种类型：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735460389642-4fc0a7e9-cdde-46e4-ba34-5c7494a173a0.png" width="981" title="" crop="0,0,1,1" id="u494a4a98" class="ne-image">





#### <font style="color:#080808;background-color:#ffffff;">创建EntityManagerFactory</font>
<font style="color:#080808;background-color:#ffffff;">执行父类：#afterPropertiesSet</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735460159503-48255bbc-405e-46ce-893b-0323e7aab152.png" width="755" title="" crop="0,0,1,1" id="u6f64e366" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">最终创建一个EntityManagerFactory的代理对象出来， 通过EntityManagerFactoryBean 获取的对象即该代理对象</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735389234247-42f08e7c-f739-4f44-88ab-3e67dc12c48e.png" width="1086" title="" crop="0,0,1,1" id="u7162052a" class="ne-image">



代理对象拦截器即：持有EntityManagerFactoryBean对象

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735390236473-cab9ddee-2ecc-438e-b48d-a3b4b1eba091.png" width="1130" title="" crop="0,0,1,1" id="u362d12eb" class="ne-image">



### <font style="color:#080808;background-color:#ffffff;">PersistenceAnnotationBeanPostProcessor</font>
> 为 <font style="color:#080808;background-color:#ffffff;">PersistenceContext、 PersistenceUnit 注解 注入对应的属性</font>
>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">注入EntityManager对象给 @PersistenceContext 属性时：</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735391000225-d5a611c4-6313-4db7-8f18-90a79c540346.png" width="995" title="" crop="0,0,1,1" id="u241c16ce" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735391252933-f37ed3c3-f112-4928-9cdb-f1b3b0fe4a54.png" width="1207" title="org.springframework.orm.jpa.SharedEntityManagerCreator#createSharedEntityManager" crop="0,0,1,1" id="ucc9b9bd5" class="ne-image">



### <font style="color:rgb(25, 27, 31);">Repositories 注册</font>
#### <font style="color:rgb(25, 27, 31);">JPARepositoriesRegistrar</font>
> 将自定义的Repository 类 转换为一个**<font style="color:#080808;background-color:#ffffff;">JpaRepositoryFactoryBean</font>**** **对象
>
>   <font style="color:#080808;background-color:#ffffff;">JpaRepositoriesRegistrar extends RepositoryBeanDefinitionRegistrarSupport</font>
>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">最终执行：RepositoryBeanDefinitionRegistrarSupport#registerBeanDefinitions</font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735443225850-d7e38a1e-23e8-4fa6-9d21-3b76a768441c.png" width="805" title="" crop="0,0,1,1" id="u15aafd8b" class="ne-image">



<font style="color:#080808;background-color:#ffffff;">会将用户定义的Repository 转换成一个 </font>**<font style="color:#080808;background-color:#ffffff;">JpaRepositoryFactoryBean</font>**<font style="color:#080808;background-color:#ffffff;"> 对象。 在截图中间的for 会调用build 方法构建BeanDefinition对象，</font>**<font style="color:#080808;background-color:#ffffff;">lazyInit</font>**<font style="color:#080808;background-color:#ffffff;"> 也会在这里设置（即 BootstrapMode#LAZY）</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735442960251-e8aa6562-2b6f-4035-ae15-de827e8e768a.png" width="1136" title="org.springframework.data.repository.config.RepositoryConfigurationDelegate#registerRepositoriesIn" crop="0,0,1,1" id="rU3iU" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">在上面扫描Bean时：</font>

<font style="color:#080808;background-color:#ffffff;">这里会自定排除NoRepositoryBean的注解对象（JPA 的一些内置接口有这个定义：JpaRepositoryImplementation）。  只扫描Repository接口的、以及注解RepositoryDefinition的类</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735441172252-d64c6acf-04b1-4cfb-bc1e-36e8645e24c2.png" width="833" title="" crop="0,0,1,1" id="u67d87ea4" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

#### **<font style="color:#080808;background-color:#ffffff;">JpaRepositoryFactory</font>**
<font style="color:#080808;background-color:#ffffff;">由于实现了InitializingBean，</font>当bean初始化完成后 会调用afterPropertiesSet方法：



首先会创建一个Jpa<font style="color:#080808;background-color:#ffffff;">RepositoryFactory对象，然后调用其getRepository 获取真正的代理对象。</font>

<font style="color:#080808;background-color:#ffffff;">（当代码中注入Respository 对象时， 也就是该repository对象， FactoryBean# getObject）</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735444761277-05f046cb-8f91-4560-a554-8c8a802868a4.png" width="1070" title="" crop="0,0,1,1" id="Cgn8Q" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">JpaRepositoryFactory extends RepositoryFactorySupport</font>

```java
    public <T> T getRepository(Class<T> repositoryInterface, RepositoryFragments fragments) {

// 获取Repository接口的 相关信息，包括泛型ID 之类的
RepositoryMetadata metadata = getRepositoryMetadata(repositoryInterface);
RepositoryComposition composition = getRepositoryComposition(metadata, fragments);
// 通过接口信息获取接口实现基类： 默认SimpleJpaRepository
RepositoryInformation information = getRepositoryInformation(metadata, composition);
// 实例化SimpleJpaRepository 类
Object target = getTargetRepository(information);

// Create proxy,
ProxyFactory result = new ProxyFactory();
result.setTarget(target);
result.setInterfaces(repositoryInterface, Repository.class, TransactionalProxy.class);
// 添加各种的advisor： 
result.addAdvisor(ExposeInvocationInterceptor.ADVISOR);
postProcessors.forEach(processor -> processor.postProcess(result, information));

    .......
// 调用底层的代理工厂 创建代理类，默认JDK
T repository = (T) result.getProxy(classLoader);

return repository;
```

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">最终添加的Advisor 如下：</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735448070869-626c625b-96be-476c-bd92-c3240cafd33a.png" width="951" title="" crop="0,0,1,1" id="w0iHK" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>





<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

### <font style="color:rgb(26, 32, 41);">@Repository</font>
> 该注解内部被标识为@Componet。
>

通过上面源码分析，JPA 会自动扫描Repository 接口的实现类，因此该注解可以直接忽略。



### JPA 的实现类处理过程
> 默认 以Impl 结尾的类
>

前面提到在转换用户的Repository 到**<font style="color:#080808;background-color:#ffffff;">JpaRepositoryFactoryBean</font>**<font style="color:#080808;background-color:#ffffff;"> 对象时，会在下面代码构建JpaRepositoryFactoryBean的beanDefinition</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735565983934-43368bc8-37b3-4c0d-b7f9-cf9df3742217.png" width="969" title="" crop="0,0,1,1" id="X3PEe" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735566327931-97aa0c1d-0d5b-4c5c-ad66-87a45200c3f6.png" width="1028" title="" crop="0,0,1,1" id="X00Ko" class="ne-image">



#### <font style="color:#080808;background-color:#ffffff;">registerCustomImplementation</font>
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735566891450-40c41693-2761-474f-ac8d-529c69e3e373.png" width="1257" title="" crop="0,0,1,1" id="sVl4Q" class="ne-image">



##### <font style="color:#080808;background-color:#ffffff;">toLookupConfiguration</font>
<font style="color:#080808;background-color:#ffffff;">DefaultImplementationLookupConfiguration：通过名称拼接类名</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735566443630-1608d022-d087-4cac-8f5c-f94c58db1ae5.png" width="1055" title="" crop="0,0,1,1" id="Vk9UK" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

##### <font style="color:#080808;background-color:#ffffff;">detectCustomImplementation</font>
> 查找imple 的类
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735567336021-8aa00954-764d-40b9-a288-62ee31379fb6.png" width="1491" title="" crop="0,0,1,1" id="sdFdQ" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">最终走到如下： 将该目录所有的Impl 结尾的类都扫描出来</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735567137902-7d994a65-43fc-4fcf-87c0-5caca29a5893.png" width="1204" title="" crop="0,0,1,1" id="N4Dds" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

#### <font style="color:#080808;background-color:#ffffff;">构造拦截器：</font>
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735568481467-66d0f39c-8549-4b8f-9ea0-884ae570ccc7.png" width="1277" title="" crop="0,0,1,1" id="V12Iz" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">将自定义的实现类作为ImplementationMethodExecutionInterceptor 对象添加到advisor：</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735568636562-a8ce6831-59da-4e42-880a-c01400db2e59.png" width="1490" title="org.springframework.data.repository.core.support.RepositoryFactorySupport#getRepository" crop="0,0,1,1" id="kvGD5" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

#### <font style="color:#080808;background-color:#ffffff;">ImplementationMethodExecutionInterceptor：</font>
> 执行的时候会走入该拦截器
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735568865080-b5269c49-9f7e-46c4-8336-64c3ddb47846.png" width="1236" title="" crop="0,0,1,1" id="a7Z5Q" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735568942334-c7f76139-d4af-4f66-8f6a-fecf3cd4723c.png" width="1175" title="" crop="0,0,1,1" id="i9ED0" class="ne-image">





前面会查找该method 属于哪个fragments，然后执行对应的目标：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735569339366-2e6124fe-eeea-40e6-ad05-908892fe387f.png" width="1093" title="" crop="0,0,1,1" id="Ag7VV" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

也不需要加注解：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735482821989-59652f4a-e52b-40d2-928c-8d1c690a00ce.png" width="683" title="" crop="0,0,1,1" id="rd8YL" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735482747243-bc9e9018-c989-4480-b615-6fbc33be7085.png" width="960" title="RepositoryFactorySupport.ImplementationMethodExecutionInterceptor#invoke" crop="0,0,1,1" id="Uk4ip" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;"></font>

### <font style="color:#080808;background-color:#ffffff;">自定义接口 </font><font style="color:rgb(25, 30, 30);">fragment interface</font>
InsertRepository为自定义的接口：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735632973056-75dc973f-d6dd-4bb6-8680-d7c463f9535d.png" width="1000" title="" crop="0,0,1,1" id="xIWOp" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735632849762-f5329ea4-d990-452e-98e8-32baf7e9357c.png" width="1099" title="" crop="0,0,1,1" id="YO34t" class="ne-image">





#### <font style="color:#080808;background-color:#ffffff;">registerRepositoryFragmentsImplementation</font>
> 会过滤掉@NoRepositoryBean， <font style="color:#080808;background-color:#ffffff;">JpaRepository 被标记过</font>
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735634340823-6aa11602-4b78-4470-a3af-8e4a8c7d6241.png" width="1138" title="RepositoryBeanDefinitionBuilder#registerRepositoryFragmentsImplementation" crop="0,0,1,1" id="GoatX" class="ne-image">





##### **<font style="color:#DF2A3F;background-color:#ffffff;">detectRepositoryFragmentConfiguration </font>**<font style="color:#DF2A3F;background-color:#ffffff;">---></font>**<font style="color:#DF2A3F;background-color:#ffffff;">detectCustomImplementation</font>**
<font style="color:#080808;background-color:#ffffff;">implementationCandidates 定义为一个Lazy， 在扫描自定义 Impl的时候，如果扫描过了，后面处理</font>**<font style="color:#080808;background-color:#ffffff;">InsertRepositoryImpl</font>**<font style="color:#080808;background-color:#ffffff;"> 将不会触发扫描。因此这里只会扫描一次。</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735656577561-67a1751f-7ade-455b-8ad0-7253f85b2ba0.png" width="1027" title="" crop="0,0,1,1" id="u8f81247d" class="ne-image">



这里就不会调用<font style="color:#080808;background-color:#ffffff;">findCandidateBeanDefinitions</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735656747100-2e692752-757b-40a5-b70d-11b4edcea754.png" width="1151" title="" crop="0,0,1,1" id="u5862a7f1" class="ne-image">

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">要解决上诉问题有如下方案：</font>

1. <font style="color:#080808;background-color:#ffffff;">将</font><font style="color:rgb(25, 30, 30);">fragment 相关内容放入Repository同一个包下</font>
2. <font style="color:rgb(25, 30, 30);">直接添加一个新的 basePackge 扩展路径</font>



##### **<font style="color:#080808;background-color:#ffffff;">potentiallyRegisterFragmentImplementation</font>**
<font style="color:#080808;background-color:#ffffff;">注册实现类的BeanDefinition</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735633997212-3da8271b-f68f-4de8-a3e3-bba44ba0a9b6.png" width="1051" title="" crop="0,0,1,1" id="mkeIp" class="ne-image">



##### **<font style="color:#080808;background-color:#ffffff;">potentiallyRegisterRepositoryFragment</font>**
<font style="color:#080808;background-color:#ffffff;">注册repositoryFragment 的beanDefinition</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735632567532-8f0bca0c-aff6-4aef-bd9d-882bb7826c69.png" width="969" title="" crop="0,0,1,1" id="kM9wV" class="ne-image">

<font style="color:rgb(51, 51, 51);"></font>



#### 构造拦截器
可以看到实现类都添加进了composition， 当调用目标方法时，会在这几个实现类中查找 具体方法。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1735703839231-24c0a1dd-d829-4c76-82da-85c0c75e0b5f.png" width="1162" title="" crop="0,0,1,1" id="u61ad7b0d" class="ne-image">



## 调用JPA 方法执行流程
<font style="color:rgb(51, 51, 51);">见本地：SpringDataJpa 源码.md</font>

<font style="color:rgb(51, 51, 51);">核心：TransactionAspectSupport#invokeWithinTransaction</font>

<font style="color:rgb(51, 51, 51);"></font>

<font style="color:#080808;background-color:#ffffff;">JPA 的接口方法默认</font>**<font style="color:#080808;background-color:#ffffff;">都会执行该方法</font>**<font style="color:#080808;background-color:#ffffff;">，但是事务的是否开启只取决于 执行目标类中是否有 </font>**<font style="color:#080808;background-color:#ffffff;">@Transactional</font>**<font style="color:#080808;background-color:#ffffff;">注解、 以及是否设置 enableDefaultTransactions = false （默认true）有关系。</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735465900969-2e6461e6-b6b9-4196-b3e0-c0e1b126b252.png" width="1071" title="" crop="0,0,1,1" id="u41ec59e2" class="ne-image">

<font style="color:rgb(51, 51, 51);"></font>

<font style="color:rgb(51, 51, 51);"></font>

### <font style="color:rgb(51, 51, 51);">解析@Transactional 注解</font>
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735465975746-855285af-684d-4b11-81ad-1e79884b0256.png" width="868" title="" crop="0,0,1,1" id="uf0cdc8f6" class="ne-image">

<font style="color:rgb(51, 51, 51);">查看@Transactional 注解设置的信息：</font>

<font style="color:rgb(51, 51, 51);"></font>

<font style="color:#080808;background-color:#ffffff;">ClassUtils.getMostSpecificMethod： 会查找SimpleJapRepository 相关的所有父类。</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735465503035-a2f883d5-2042-4de8-b6ff-e019ee3a41c1.png" width="986" title="TransactionalRepositoryProxyPostProcessor.RepositoryAnnotationTransactionAttributeSource" crop="0,0,1,1" id="u8f54a172" class="ne-image">

<font style="color:rgb(51, 51, 51);"></font>

<font style="color:rgb(51, 51, 51);"></font>

### <font style="color:rgb(51, 51, 51);">开启事务</font>
<font style="color:#080808;background-color:#ffffff;">createTransactionIfNecessary： 会根据txAttr的状态来判断</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735465782163-86d63cb9-6f22-45ce-b5e2-7836a8003645.png" width="903" title="" crop="0,0,1,1" id="u1c972b6c" class="ne-image">





根据不同的传递模式进入不同的 分支：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735466338063-273d242f-3fb4-46d2-ad02-da106407747f.png" width="1017" title="" crop="0,0,1,1" id="uf05e3cbf" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735467279117-8b1d6435-103c-4938-9256-2d526ee58817.png" width="1090" title="" crop="0,0,1,1" id="uc33bd246" class="ne-image">



#### doBegin
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735467195960-8bfdc24d-345a-4d14-8175-4a40d305864d.png" width="1157" title="" crop="0,0,1,1" id="ue05dd317" class="ne-image">



**<font style="color:#080808;background-color:#ffffff;">beginTransaction</font>**

<font style="color:#080808;background-color:#ffffff;">getSession： 实际上这里就是返回的EntityManager对象本身。</font>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735479554578-739da01a-ce92-4c8b-a73b-1fbfd60b336f.png" width="1087" title="" crop="0,0,1,1" id="uc9995d37" class="ne-image">





获取真实的Connection：会通过dataSource获取Connection

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735467547984-bdec920c-f165-4e1e-9d09-57888f6438b0.png" width="766" title="" crop="0,0,1,1" id="u44f247bc" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735478318803-c43c437f-ab7e-4b53-ac45-65b869282189.png" width="947" title="" crop="0,0,1,1" id="ue11121d6" class="ne-image">





**底层readOnly **

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735478233752-1d480cd5-6e43-4a2f-bf8e-da51f29ef562.png" width="1156" title="com.mysql.cj.jdbc.ConnectionImpl#setReadOnlyInternal" crop="0,0,1,1" id="uf1e237db" class="ne-image">



#### <font style="color:#080808;background-color:#ffffff;">prepareSynchronization</font>
> 绑定状态信息
>

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735467241861-04b9f579-3a40-4ca7-a78f-001e39a74031.png" width="954" title="" crop="0,0,1,1" id="u06dbce7f" class="ne-image">



### 事务信息管理
会将当前线程的事务信息放入ThreadLocal

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735483529148-a9714287-dcf4-4fa9-8e64-3c02e9f57cd4.png" width="957" title="org.springframework.orm.jpa.JpaTransactionManager#doBegin" crop="0,0,1,1" id="u187a7e98" class="ne-image">





下面方法就是获取上面放入ThreadLocal的连接对象：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735483897955-7c95d156-6ec0-4c7e-bb45-339d6cf66afe.png" width="915" title="" crop="0,0,1,1" id="u2a3b3c60" class="ne-image">

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735483877257-d32e8469-1cf1-46f0-acaf-f9bff4c66d88.png" width="830" title="" crop="0,0,1,1" id="u353208bf" class="ne-image">





### 执行JPA 目标方法
<font style="color:#080808;background-color:#ffffff;">在JPA 实现类处理过程中分析到，最终生成的advisor 中有一个：</font>**<font style="color:#080808;background-color:#ffffff;">ImplementationMethodExecutionInterceptor</font>**

<font style="color:#080808;background-color:#ffffff;">该类会判断目标方法数据在哪一个实现类中存在：  即会在 fragments 类中查找 调用目标方法，当找到了会缓存到fragmentCache 中。方便下一次快速调用目标方法。</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1735982620755-cb8616ec-27a8-4120-a779-f378084f4918.png" width="1203" title="org.springframework.data.repository.core.support.RepositoryFactorySupport.ImplementationMethodExecutionInterceptor#invoke" crop="0,0,1,1" id="u8ac2a1b6" class="ne-image">



### JPQL 执行 过程
#### Query
<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734784066114-b8fe9e8d-ea0b-4c98-9239-158070564e17.png" width="489" title="" crop="0,0,1,1" id="udd54a95d" class="ne-image">



当执行上面方法时，首先通过拦截器链进入 JpaQueryExecution#execute

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734784284208-388a5d72-4607-4a8f-a226-191950377bac.png" width="948" title="" crop="0,0,1,1" id="FkBPA" class="ne-image">



通过createQuery 创建Query对象， 然后调用getSingleResult 获取结果

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1734784380229-660595c1-1093-4098-8f4a-e52e4348eebb.png" width="660" title="" crop="0,0,1,1" id="u86dbe490" class="ne-image">



## Spring data jpa 自带方法
注解：

@Query： 不会查询缓存，直接查询数据库，但是结果会放入缓存。底层：session#createQuery

@Modify： 使用该注解的时候，也是直接 执行SQL 到数据库，不会影响缓存中的数据。



内置方法：实现基本都在**<font style="color:#080808;background-color:#ffffff;">SimpleJpaRepository，核心都是通过EntityManager调用目标方法</font>**

<font style="color:#080808;background-color:#ffffff;"></font>

findById： 底层调用session#find

deleteById:   底层： session# <font style="color:#080808;background-color:#ffffff;">delete(findById(id))</font>

<font style="color:#080808;background-color:#ffffff;">save：id字段有值  调用persist， 无则调用merge</font>

<font style="color:#080808;background-color:#ffffff;"></font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1735983095993-2a50b833-728d-4522-85ff-7062e57ba618.png" width="483" title="" crop="0,0,1,1" id="u08d5f1e2" class="ne-image">



## SharedEntityManagerInvocationHandler
该对象作为EntityManager的代理对象，即当通过EntityManager 调用目标方法时，会首先在这里进行处理。

在**<font style="color:#080808;background-color:#ffffff;">SimpleJpaRepository</font>**<font style="color:#080808;background-color:#ffffff;"> 中核心也是通过EntityManager代理对象来调用目标方法。</font>

<font style="color:#080808;background-color:#ffffff;"></font>

<font style="color:#080808;background-color:#ffffff;">核心即通过ThreadLocal 获取当前事务的EntityManager对象来执行相关的目标方法： 即执行SessionImpl 中的方法。</font>

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1735983298810-808a1f7c-7142-4945-8fab-6987915bf661.png" width="228" title="" crop="0,0,1,1" id="u5dae34ce" class="ne-image">

```java
public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
    // Invocation on EntityManager interface coming in...

    if ...
    else if (method.getName().equals("getEntityManagerFactory")) {
        // JPA 2.0: return EntityManagerFactory without creating an EntityManager.
        return this.targetFactory;
    }
     else if (method.getName().equals("unwrap")) {
        // JPA 2.0: handle unwrap method - could be a proxy match.
        Class<?> targetClass = (Class<?>) args[0];
        if (targetClass != null && targetClass.isInstance(proxy)) {
            return proxy;
        }
    }

    // 当JPA开启事务后，这里会返回缓存中的EntityManager对象，否则返回空
    EntityManager target = EntityManagerFactoryUtils.doGetTransactionalEntityManager(
        this.targetFactory, this.properties, this.synchronizedWithTransaction);

    if (method.getName().equals("getTargetEntityManager")) {
             return target;
    }
    else if (method.getName().equals("unwrap")) {
        ...
    }
    else if (transactionRequiringMethods.contains(method.getName())) {
        // 如果是需要事务的方法，这里进行一些校验是否有事务（即上面target 不为空）
       if (target == null || (!TransactionSynchronizationManager.isActualTransactionActive() &&
             !target.getTransaction().isActive())) {
          throw new TransactionRequiredException("No EntityManager with actual transaction available " +
                "for current thread - cannot reliably process '" + method.getName() + "' call");
       }
    }

    // Regular EntityManager operations.
    boolean isNewEm = false;
    if (target == null) {  // 没有开启事务，创建一个新的EntityManager
       logger.debug("Creating new EntityManager for shared EntityManager invocation");
       target = (!CollectionUtils.isEmpty(this.properties) ?
             this.targetFactory.createEntityManager(this.properties) :
             this.targetFactory.createEntityManager());
       isNewEm = true;
    }

    // Invoke method on current EntityManager.
    try {
       Object result = method.invoke(target, args);
       if (result instanceof Query) {
           if (isNewEm) {
               Query query = (Query) result;
               为result 生成代理对象：DeferredQueryInvocationHandler
               ...
               isNewEm = false;
           }
       }
       return result;
    }
    finally {
       if (isNewEm) { // 如果是新创的EntityManager对象，结束的时候关闭连接
          EntityManagerFactoryUtils.closeEntityManager(target);
       }
    }
}
```

从上面代码可以知道，在操作EntityManager代理对象的**非事务**方法时，如果当前没有被事务进行管理，会在 **SharedEntityManagerInvocationHandler** 中创建一个底层的EntityManager对象。



同时如果执行的是创建**Query对象**时，在返回的时候会为Query对象也生成一个代理对象**DeferredQueryInvocationHandler，**此时不会关闭刚创建的EntityManager对象。



对于**非Query对象**的创建，则会立即关闭底层EntityManager对象



**<font style="color:#080808;background-color:#ffffff;">SimpleJpaRepository</font>**<font style="color:#080808;background-color:#ffffff;">中执行的操作同样是通过EntityManager进行执行，默认请求每个方法都会开启事务，因此不会存在调用createQuery后立即关闭，造成不必要的额外开销。 </font>

<font style="color:#080808;background-color:#ffffff;">实际上普通的查询使用事务也完全没必要（JPA 这么设计是为啥呢）。</font>

## DeferredQueryInvocationHandler
当EntityManager对象调用createXX，返回Query对象时，会创建该代理对象返回。



Query对象执行的是需要终止的方法时，则执行结束会尝试关闭底层EntityManager。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1743470920614-44ac5677-d46e-4d27-88cd-d5fb68c25197.png" width="936" title="" crop="0,0,1,1" id="u4bd5f2d9" class="ne-image">



因此，下面demo，在调用getResultList时就会自动关闭链接。

```java
@PersistenceContext
private EntityManager entityManager;

public void testConnection() {
    Query nativeQuery = entityManager.createNativeQuery("select * from cloud_eu_invoice_setting where reseller_no = 110486 limit 1");
    List resultList = nativeQuery.getResultList();
    System.out.println(resultList);
}
```







## 自定义 Repository
自定义update，防止对象处于托管态时，save的时候会查询数据库。 通过自定义逻辑调用底层连接对象，直接发起更新SQL 到数据库。



先看下Hibernate内部是如何获取的底层连接对象来执行SQL 的。

### SingleTableEntityPersister
> 该类是调用底层JDBC 方法最核心的一个类，提供的 insert，update 相关SQL 的生成，以及参数绑定。最终调用JDBC执行对应的SQL。
>

这里简单跟踪下执行insert 方法：



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1735984584277-82d792e1-d1e5-49ce-8d75-36dd0670897b.png" width="792" title="" crop="0,0,1,1" id="qh7wl" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1735996402862-b32c3e00-6f84-47f6-8b9c-0659beff5056.png" width="754" title="" crop="0,0,1,1" id="ua35cc9ba" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1735996437834-6760f4c8-67f5-4d9b-84a3-03d505954739.png" width="1053" title="通过session对象获取PreparedStatement" crop="0,0,1,1" id="u346262dd" class="ne-image">



<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1735984934869-985dfc39-283c-4c20-9415-f2a86058fa3e.png" width="889" title="" crop="0,0,1,1" id="lhwpp" class="ne-image">





### 自定义实现
通过上面可以看到我们可以通过session 对象直接获取PreparementStatement对象：

即我们可以写出下面代码来获取：

```java
SessionImpl session = entityManager.unwrap(SessionImpl.class);
@Cleanup PreparedStatement preparedStatement = session.getJdbcCoordinator().getStatementPreparer()
.prepareStatement("select * from users", Statement.NO_GENERATED_KEYS);
boolean ints = preparedStatement.execute();
ResultSet resultSet = preparedStatement.getResultSet();
resultSet.next();
String string = resultSet.getString(1);
System.out.println(string);
```





具体实现参考仓库：

[https://gitee.com/xiaoye2018/boot-integration/blob/master/src/main/java/com/example/bootintegration/dao/jpa/repository/UpdateRepositoryImpl.java](https://gitee.com/xiaoye2018/boot-integration/blob/master/src/main/java/com/example/bootintegration/dao/jpa/repository/UpdateRepositoryImpl.java)





# JPA 遇到的问题
## 保持丢失
> 在同一个事务中， 先查询出对象a，然后在删除a， 最后新增一个对象a。 事务提交后，a 对象没有新增成功，也没有任务错误信息。
>



demo：

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1756870346273-16a92529-e7d2-4ed3-a1f0-10bfa6cfc16f.png" width="1183" title="" crop="0,0,1,1" id="ub73dff54" class="ne-image">

<font style="color:#080808;background-color:#ffffff;">意图是新增一个相同的对象，单实际上是不同的对象了（key 不同）</font>

<font style="color:#080808;background-color:#ffffff;"></font>

### 异常分析：
经debug 发现数据库对char类型有不同的处理：

> 当前数据库为sybase， 有一个联合索引作为聚集索引，该聚集索引中有一个字段 xref_type 为char(10)
>
> + sybase 默认会将char类型字段的结果用空格补齐到指定长度。
> + mysql 在处理结果集时会清理末尾空格。因此不会有问题
>



当调用saveAll 方法时，最终执行到下面方法

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1737122749026-ad847fb0-0c8b-4bd4-8e4d-ce322d0ea6d1.png" width="964" title="org.hibernate.event.internal.DefaultMergeEventListener#entityIsDetached" crop="0,0,1,1" id="u3356b91a" class="ne-image">



因为new 处理的对象手动指定了key，同时xrefType不带空格，因此缓存中是取不到对象的

继续查询DB，生成一个缓存对象，由于这里是指定的对象key（会调用 find api），那么将<font style="color:#DF2A3F;">手动指定的对象key </font>作为缓存的key。



查询出了对象，因此走merge 分支，即使用代码中new 出来的对象覆盖 缓存中的对象。



现在缓存中对象如下：

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735089032236-9fd27053-d403-4e06-9801-a7bac881608b.png" width="974" title="" crop="0,0,1,1" id="u74e9e294" class="ne-image">



提交事务后：

处理缓存中的对象信息。生成对于的EventAction

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735089541543-36c4b57a-a7d5-4d3f-a4fa-b44e011ddbba.png" width="1077" title="" crop="0,0,1,1" id="u536239db" class="ne-image">





这里会发现有两个事件，但是执行顺序是先执行 updateAction、然后执行deleteAction。 因此数据最终被删除。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735089856883-e36444ba-dd6b-458a-b0ee-ae271f090bea.png" width="1065" title="" crop="0,0,1,1" id="u8547e958" class="ne-image">







### 正常执行情况
如果new 对象的时候手动指定与 查询结果相同的内容： 即手动补充空格

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735176346430-e3f89457-901b-46d4-87ab-54da28120a05.png" width="805" title="" crop="0,0,1,1" id="ufc478ce8" class="ne-image">



那么在最终执行save的时候，会获取到缓存中的对象，状态为deleted 。进入save 逻辑



<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735176621998-fc2200a3-a8ce-43ac-8733-6914ad699405.png" width="1036" title="" crop="0,0,1,1" id="u126acb17" class="ne-image">





最终执行到这里： 会判断缓存中是否有值， 这里缓存中已经为deleted，就先flush， 生成delete的action，同时发出delete的sql。

方法末尾再次添加一个insert的ActionQueue ，事务提交的时候就直接执行insert 。

<img src="https://cdn.nlark.com/yuque/0/2024/png/12552539/1735176692183-a74c3732-b8df-4bad-9452-3d86943a32f7.png" width="851" title="" crop="0,0,1,1" id="u623783c0" class="ne-image">

## 
解决方案

1. 更改数据表字段类型为varchar
2. 调用deleteById 后，手动调用flush，强制先执行delete。

## 
## 生成Version 报错：
由于手动创建数据的时候没有手动指定version的字段值，JPA 在更新的时候递增version字段发生异常：



```java
java.lang.NullPointerException
	at org.hibernate.type.IntegerType.next(IntegerType.java:70)
	at org.hibernate.type.IntegerType.next(IntegerType.java:22)
	at org.hibernate.engine.internal.Versioning.increment(Versioning.java:92)
	at org.hibernate.event.internal.DefaultFlushEntityEventListener.getNextVersion(DefaultFlushEntityEventListener.java:425)
	at org.hibernate.event.internal.DefaultFlushEntityEventListener.scheduleUpdate(DefaultFlushEntityEventListener.java:302)
	at org.hibernate.event.internal.DefaultFlushEntityEventListener.onFlushEntity(DefaultFlushEntityEventListener.java:170)
	at org.hibernate.event.internal.AbstractFlushingEventListener.flushEntities(AbstractFlushingEventListener.java:232)
	at org.hibernate.event.internal.AbstractFlushingEventListener.flushEverythingToExecutions(AbstractFlushingEventListener.java:92)
```





在save 的时候会自动递增Version：

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1737008729970-c13ec414-6d9a-4047-b2c0-e1134205121f.png" width="875" title="" crop="0,0,1,1" id="u68fe04c8" class="ne-image">



具体可添加断点查看具体如何设值：

首先是写入的数据库对应的Version 值，在update 的时候设置新的递增值。

<img src="https://cdn.nlark.com/yuque/0/2025/png/12552539/1737010013628-b97422e2-b211-4b4c-aecd-1bc80b5b9055.png" width="714" title="" crop="0,0,1,1" id="u190f8051" class="ne-image">
