## 安装

https://blog.csdn.net/flyinmind/article/details/108437443

![image-20230622105916747](rust.assets/image-20230622105916747.png)

指定目录，默认安装到c:user/xxx/.cargo, 无法设置环境变量

![image-20230622095940113](rust.assets/image-20230622095940113.png)



提示Blocking waiting for file lock on package cache

![image-20230624204055244](rust.assets/image-20230624204055244.png)

```
原因:~\.cargo下的.package_cache被加锁阻塞
 
解决方法:删除.package_cache文件
```

