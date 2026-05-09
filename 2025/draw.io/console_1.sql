-- 间隙锁 之间不会冲突，间隙锁与insert 的语句会冲突
-- 对不存在的数据update 会直接结束，并不会阻塞 ???

# 对于不存在索引的字段进行加锁， 会锁表

# 原则 1：加锁的基本单位是 next-key lock。next-key lock 是前开后闭区间。
# 原则 2：查找过程中访问到的对象才会加锁。
# 优化 1：索引上的等值查询，给唯一索引加锁的时候，next-key lock 退化为行锁。
# 优化 2：索引上的等值查询，向右遍历时且最后一个值不满足等值条件的时候，next-key lock 退化为间隙锁。


update t set d = d + 1 where d = 5;    -- 锁表

update t set d = d + 1 where id = 7;   -- id (5, 10) 加锁， 其他事务不能insert

select id from t where c = 5 lock in share mode;    -- 仅 c (0,10)  ,  由于覆盖索引导致id 主键 没任何锁，  改为 select d，避免主键不加锁
select id from t where c = 5 for update;       -- 会同时在主键上加锁

select * from t where id=10 for update;

select * from t where id>=10 and id<11 for update;       -- id [10, 15]

select * from t where c >=10 and c<11 for update;   -- c (5, 10], (10, 15]

select * from t where id >10 and id<=15 for update;     -- id (10, 15]

-- c存在两个10
insert into t values(30,10,30);
delete from t where c = 10;     -- gap lock: ( (c = 5, id = 5) ---- (c = 15, id = 15)  )

delete from t where c = 10 limit 2;   -- lock:  (c = 5, id = 5

-- dead lock
select id from t where c = 10 lock in share mode ;
insert into t values(8,8,8);


select * from t where id>9 and id<12 order by id desc for update;     -- id (0, 5], (5, 10], (10, 15) 加锁

select id from t where c in(5,20,10) lock in share mode;          -- 先对5 加(0,5],(5,10)， 在对20加 (15,20], (20, 25)， 然后10加 (5, 10], (10, 15)      使用了优化二

select id from t where c in(5,20,10) order by c desc for update;  -- 加锁顺序： 20， 10， 5，  如果该条语句与上面语句同时在两个事务中执行，那么会出现死锁， 尽管间隙锁不会冲突， 但是都会加5， 10 ，20 的记录锁

select * from t;

select * from t2 where id > 9 for update ;




select * from student;

begin;
select * from student;
update student  set name = '2sfs', age = 1 where id=4 and id2=2 and t_version = 3;
commit ;