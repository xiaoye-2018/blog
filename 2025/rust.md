set RUSTUP_DIST_SERVER="https://rsproxy.cn"
set RUSTUP_UPDATE_ROOT="https://rsproxy.cn/rustup"

引用作用域的结束位置为最后一次使用的位置

同一时刻，你只能拥有要么一个可变引用，要么任意多个不可变引用
引用必须总是有效的

切片&[T]
切片类型 [T] 拥有不固定的大小，而切片引用类型 &[T] 则具有固定的大小，因为 Rust 很多时候都需要固定大小数据类型，因此 &[T] 更有用，&str 字符串切片也同理


结构体解析可以省略字段名(变量，字段相同时)

模式匹配：
if let
match
while let、 let else: 可驳模式 必须用发散的代码块处理


下划线忽略值或未使用变量 _,    _name 会转移所有权，_不会转移
.. 忽略多个值 
displace: 取代


全模式匹配：
使用@ 可以用来绑定值到一个变量。
此时确实拥有可以用于分支代码的变量 id

方法：
Self 指代被实现方法的结构体类型，self 指代此类型的实例， &self 借用
关联函数： 即构造函数。 使用new 作为构造器的名称。  Obj::new(xx)
结构体,枚举，特征(trait)都可以实现方法

泛型：
const泛型、const fn

Trait： 类似接口。 定义了一组可以被共享的行为，只要实现了特征，你就能使用这组行为。
		impl trait for XX {}

特征对象： Box<dyn Draw>, &dyn Draw

生命周期： 生命周期标注并不会改变任何引用的实际作用域
	三条消除规则：
		1. 每一个引用参数都会获得独自的生命周期
		2. 若只有一个输入生命周期（函数参数中只有一个引用类型），那么该生命周期会被赋给所有的输出生命周期
		3. 若存在多个输入生命周期，且其中一个是 &self 或 &mut self，则 &self 的生命周期被赋给所有的输出生命周期

&'static: 引用必须要活得跟剩下的程序一样久, 例如字符串字面量会被打包到二进制文件中，永远不会被drop。 变量依然会约束在作用域的生命周期。
			如果需要添加这个让代码工作，可能是设计上出问题了
T: 'static： T 必须活得和程序一样久



错误处理：
	?:   如果是error，直接return

Packages：一个 Cargo 提供的 feature，可以用来构建、测试和分享包
WorkSpace: 对于大型项目，可以进一步将多个crate 联合在一起，组织成工作空间
Crate：一个由多个模块组成的树形结构，可以作为三方库进行分发，也可以生成可执行文件进行运行
Module：可以一个文件多个模块，也可以一个文件一个模块，模块可以被认为是真实项目中的代码组织单元

路径引用：self、super、crate、module name


将结构体设置为 pub，但它的所有字段依然是私有的
将枚举设置为 pub，它的所有字段也将对外可见

use： 引入外部模块

pub use: 将模块暴露出去。
限制模块可见性
pub 意味着可见性无任何限制
pub(crate) 表示在当前包可见
pub(self) 在当前模块可见
pub(super) 在父模块可见
pub(in <path>) 表示在某个路径代表的模块中可见，其中 path 必须是父模块或者祖先模块


闭包： |params..| function  支持捕获变量
FnOnce：拿走被捕获变量的所有权。     move 关键字可以强制捕获所有权
FnMut: 可变借用的方式捕获了环境中的值
Fn:    同时实现 FnMut 和 FnOnce

三种 Fn 的关系
实际上，一个闭包并不仅仅实现某一种 Fn 特征，规则如下：
所有的闭包都自动实现了 FnOnce 特征，因此任何一个闭包都至少可以被调用一次
没有移出所捕获变量的所有权的闭包自动实现了 FnMut 特征
不需要对捕获变量进行改变的闭包自动实现了 Fn 特征



Sized: 所有在编译时就能知道其大小的类型，都会自动实现 Sized 特征
DST: 编译时不能知道大小的类型，会报错。需要通过Box、&dyn 进行包装成固定大小

?Sized 特征用于表明类型 T 既有可能是固定大小的类型，也可能是动态大小的类型
fn generic<T: ?Sized>(t: &T) {
    // --snip--
}



Box<T>，可以将值分配到堆上(jemalloc)。 leak() 可以将目标值从内存中泄漏，交给全局使用。
Rc<T>，引用计数类型，允许多所有权存在
Ref<T> 和 RefMut<T>，允许将借用规则检查从编译期移动到运行期进行


Deref: 实现这个特征，可以支持* 解引用。 大部分类型都自动实现了这个特征。 可以进行隐私转换
drop: 拿走目标值的所有权


Rc/Arc: 允许一个数据资源在同一时刻拥有多个所有者.只能进行读取. 前者用于单线程，后者实现了原子性可用于多线程
Cell/RefCell:  用于内部可变性. 前者用于copy特征的值，后者用于引用
Rc<T>/RefCell<T>用于单线程内部可变性， Arc<T>/Mutex<T>用于多线程内部可变性。

Weak: Rc类似，但不持有所有权，保留一份指向数据的弱引用。常用于解决循环引用的问题,  upgrade() 取值

线程：
thread::spawn
barrier
thread_local
condition/mutex
Once


channel: mpsc
mpsc::sync_channel(size); 同步，指定通道的大小，满了会阻塞
mpsc::channel()： 异步，可以无限发送

mutex

Atomic: cas, relax/seqcst, acquire/release,
		单线程	多线程
Once	OnceCell	OnceLock
Lazy	LazyCell	LazyLock

send/sync: marker trait
- 实现Send的类型可以在线程间安全的传递其所有权
- 实现Sync的类型可以在线程间安全的共享(通过引用)

归一化Error： 
使用特征 Result<String, Box<dyn Error>>
自定义异常
thiserror
anyhow

手动实现：
unsafe impl Sync for MyBox {}

block_on(futurn): 阻塞future
.await: 不会阻塞future， 调用后才会执行

全局变量：
const： 编译会内联
static： 不会内联， 必须使用unsafe才能访问。 或者声明原子类型。  lazy_static 解决无法使用函数进行声明的情况
Box::leak： 主动泄露局部变量为全局变量

!Unpin 特征： 表示对象不能被移动。 pin只是一个结构体，没有任何具体的效果
标记类型 PhantomPinned 会自动将结构体变为 !Unpin


async move: 会捕获环境中的变量

同时运行多个future： join!/ join_all, 会等待所有都执行结束
select!: 任何一个Future结束都可以立即被处理



tokio
IO： AsyncRead， AsyncWrite。 通常使用AsyncReadExt 提供的工具方法：read_to_end， write、write_all
	io::copy,  split, TcpStream::split