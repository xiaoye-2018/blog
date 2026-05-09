# 查看通用日志配置
show variables like '%general%';
show variables like '%connection%';
set global general_log=on;  # 开启通用日志记录
show variables like '%log_output%';  # 查看慢查询日志输出格式
show variables like '%quer%';   # 查看查询日志配置
show variables like 'innodb_stats_persistent'; # on: 表示表的统计信息会持久化存储， off：存储在内存中
# 开启慢查询日志
set global slow_query_log='ON';

show global status like '%slow%';
show global status like '%thread%';
show variables like '%bin%';
show variables like '%allow%';
show global variables like '%query_cache%';
show variables like 'optimizer%';
show variables like '%warnings%';
show variables like '%auto%';
show charset;

select @@transaction_isolation;

show engines;

show binlog events in 'binlog.000008';

# mysqlbinlog  -vv data/master.000001 --start-position=8900;
# mysqlbinlog master.000001  --start-position=2738 --stop-position=2973 | mysql -h127.0.0.1 -P13000 -u$user -p$pwd;
use test;
CREATE TABLE `t` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `a` int(11) DEFAULT NULL,
  `b` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `a` (`a`),
  KEY `b` (`b`)
) ENGINE=InnoDB;


delimiter ;;
create procedure idata()
begin
  declare i int;
  set i=1;
  while(i<=100000)do
    insert into t values(i, i, i);
    set i=i+1;
  end while;
end;;
delimiter ;
call idata();


select count(*) from t;


explain select * from t where a between 10000 and 20000;

set long_query_time=0;
select * from t where a between 10000 and 20000; /*Q1*/
select * from t force index(a) where a between 10000 and 20000;/*Q2*/

# 查看表的索引统计基数
show index from t;
# 重新统计索引信息
analyze table t;

insert into t value (5,8,8);

select * from t where (a between 1 and 1000)  and (b between 20000 and 40000) order by b limit 1;
select * from t force index(a) where (a between 1 and 1000)  and (b between 20000 and 40000) order by b limit 1;

-- 选错索引问题解决方法：
# 选择了索引b
explain select * from t where (a between 1 and 1000)  and (b between 20000 and 40000) order by b limit 1;
# 选择索引a
explain select * from t where (a between 1 and 1000)  and (b between 20000 and 40000) order by b,a limit 1;
# 用 limit 100 让优化器意识到，使用 b 索引代价是很高的。其实是我们根据数据特征诱导了一下优化器，也不具备通用性。
explain select * from  (select * from t where (a between 1 and 1000)  and (b between 20000 and 40000) order by b limit 100)alias limit 1;
# 删除索引b

select distinct stu_code, age from student;
select count(*) from student;
-- 默认string --> int
select "29" > 209;
select "29" > cast(209 as char(3));

show slave status ;


select * from performance_schema.data_locks;

show engine innodb status;

# https://www.cnblogs.com/nsw2018/p/17261375.html
show processlist;
kill 1205;
# 查看正在锁的表
show open tables where in_use > 0;
show status like '%lock%';
CREATE TABLE innodb_lock_monitor (a INT) ENGINE=INNODB;


select * from stellr_billing_map;
show profiles ;

SELECT @@optimizer-trace-features;

SET session optimizer_trace_limit=10;
SET optimizer_trace_offset=0;
SET optimizer_trace="enabled=on";
#2. 记录现在执行目标 sql 之前已经读取的行数
select VARIABLE_VALUE into @a from performance_schema.session_status where variable_name = 'Innodb_rows_read';

select * from stellr_billing_map where oid > 1;
SELECT * FROM information_schema.OPTIMIZER_TRACE;


select * from test.student2;

create table test.student2
(
    id       int,
    id2      int         null,
    stu_code varchar(20) null,
    age      int         null,
    constraint student_pk_2
        unique (id, id2)
);


select @@version;
show databases ;

create database  test;


show processlist ;