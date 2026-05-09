<h1>
  <center>LinkedTransferQueue</center>
</h1>

https://www.cnblogs.com/hiramxq/p/13293498.html

> 自 JDK 1.7引入

- 无锁化实现的同步队列，类似SynchronousQueue
- 功能丰富，transfer方法支持以异步、同步、超时的方式进行提交



## 基本属性

```java
transient volatile Node head;
/** tail of the queue; null until first append */
private transient volatile Node tail;
//The number of apparent failures to unsplice removed nodes
private transient volatile int sweepVotes;
// xfer 方法的参数类型
private static final int NOW   = 0; // for untimed poll, tryTransfer
private static final int ASYNC = 1; // for offer, put, add
private static final int SYNC  = 2; // for transfer, take
private static final int TIMED = 3; // for timed poll, tryTransfer
```



## Node

```java
static final class Node {
    final boolean isData;   // false if this is a request node
    // 被匹配、中断、超时后 set 为 this
    volatile Object item;   // initially non-null if isData; CASed to match
    volatile Node next;
    volatile Thread waiter;
    final void forgetNext() {
        UNSAFE.putObject(this, nextOffset, this);
    }
    /**
         * Links node to itself to avoid garbage retention.  Called
         * only after CASing head field, so uses relaxed write.
         */
    
    // next 赋值为this，避免垃圾保留
    final void forgetNext() {
        UNSAFE.putObject(this, nextOffset, this);
    }

    // 当节点被匹配，或者取消时，会调用该方法
    final void forgetContents() {
        UNSAFE.putObject(this, itemOffset, this);
        UNSAFE.putObject(this, waiterOffset, null);
    }

    // 节点是否已经匹配
    final boolean isMatched() {
        Object x = item;
        return (x == this) || ((x == null) == isData);
    }

    // return true： 表示这是不匹配的节点
    final boolean isUnmatchedRequest() {
        return !isData && item == null;
    }

    // return true: 不能将当前节点添加到队列，由于当前节点与tail模式相反，
    final boolean cannotPrecede(boolean haveData) {
        boolean d = isData;
        Object x;
        return d != haveData && (x = item) != this && (x != null) == d;
    }

	// 尝试匹配节点
    final boolean tryMatchData() {
        // assert isData;
        Object x = item;
        if (x != null && x != this && casItem(x, null)) {
            LockSupport.unpark(waiter); // 唤醒匹配的节点
            return true;
        }
        return false;
    }

}
```



## xfer

```java
private E xfer(E e, boolean haveData, int how, long nanos) {
    if (haveData && (e == null))
        throw new NullPointerException();
    Node s = null;                        // the node to append, if needed

    retry:
    for (;;) {                            // restart on append race
		// 循环队列中的节点
        for (Node h = head, p = h; p != null;) { // find & match first node
            boolean isData = p.isData;
            Object item = p.item;
            if (item != p && (item != null) == isData) { // unmatched，队列中的节点还没有被匹配
                if (isData == haveData)   // can't match，节点与当前请求类型相同，不能匹配，应该进入队列排队
                    break;
                if (p.casItem(item, e)) { // match， 当前节点与p能够匹配,将item设置为匹配的值
                    for (Node q = p; q != h;) { // 重试
                        Node n = q.next;  // update by 2 unless singleton
                        // 由于当前以及匹配上，因此从新set head
                        if (head == h && casHead(h, n == null ? q : n)) {
                            h.forgetNext(); // h.next = this
                            break;
                        }          
                        // advance and retry，上面失败，进行重试
                        if ((h = head)   == null || // head 被其他节点匹配，队列已为null
                            (q = h.next) == null || // head被更新
                            !q.isMatched())		// 上面cas 失败，q节点被match或cancel
                            break;        // unless slack < 2
                    }
                    LockSupport.unpark(p.waiter); // 唤醒等待的线程，p.waiter可能为null，不影响运行
                    return LinkedTransferQueue.<E>cast(item);
                }
            }
            // 如果p已经被匹配，那么会走下面逻辑
            Node n = p.next;
            // 使用n来匹配当前请求，或者重新从head开始寻找匹配的节点
            p = (p != n) ? n : (h = head); // Use head if p offlist
        }
		// 队列的tail 与当前请求不匹配，或者队列为空 会走到这里
        if (how != NOW) {                 // No matches available
            if (s == null)
                s = new Node(e, haveData);
            Node pred = tryAppend(s, haveData); // 将s 作为 tail，返回前驱
            if (pred == null)  // 表示s无法添加到队列，模式不匹配或者竞争导致
                continue retry;           // lost race vs opposite mode
            if (how != ASYNC)
                // 不是异步，那么进行阻塞
                return awaitMatch(s, pred, e, (how == TIMED), nanos);
        }
        return e; // not waiting
    }
}
```



## tryAppend

```java
/**
* Tries to append node s as tail.
*
* @param s the node to append
* @param haveData true if appending in data mode
* @return null on failure due to losing race with append in
* different mode, else s's predecessor, or s itself if no
* predecessor
*/
private Node tryAppend(Node s, boolean haveData) {
    for (Node t = tail, p = t;;) {        // move p to last node and append
        Node n, u;                        // temps for reads of next & tail
        if (p == null && (p = head) == null) { // 队列还没有元素
            if (casHead(null, s))	// 将s作为head，返回s
                return s;                 // initialize
        }
        else if (p.cannotPrecede(haveData)) // 模式不匹配，无法添加到队列
            return null;                  // lost race vs opposite mode
        else if ((n = p.next) != null)    // not last; keep traversing，tail变动了
            p = p != t && t != (u = tail) ? (t = u) : // stale tail，从tail从新开始
        (p != n) ? n : null;      // restart if off list
        else if (!p.casNext(null, s)) // 将s作为tail.next
            p = p.next;                   // re-read on CAS failure
        else {
            if (p != t) {                 // update if slack now >= 2
                while ((tail != t || !casTail(t, s)) &&
                       (t = tail)   != null &&
                       (s = t.next) != null && // advance and retry
                       (s = s.next) != null && s != t);
            }
            return p;	// 返回s前驱p
        }
    }
}


```



## awaitMatch

等待被匹配

```java
private E awaitMatch(Node s, Node pred, E e, boolean timed, long nanos) {
    final long deadline = timed ? System.nanoTime() + nanos : 0L;
    Thread w = Thread.currentThread();
    int spins = -1; // initialized after first item and cancel checks
    ThreadLocalRandom randomYields = null; // bound if needed

    for (;;) {
        Object item = s.item;
        if (item != e) {                  // matched
            // assert item != s;
            // set s.item to this, next to null
            s.forgetContents();           // avoid garbage
            return LinkedTransferQueue.<E>cast(item);
        }
        if ((w.isInterrupted() || (timed && nanos <= 0)) &&
            // 中断、超时，设置item为s
            s.casItem(e, s)) {        // cancel
            unsplice(pred, s); // unlink s
            return e;
        }

        if (spins < 0) {                  // establish spins at/near front
            if ((spins = spinsFor(pred, s.isData)) > 0)
                randomYields = ThreadLocalRandom.current();
        }
        else if (spins > 0) {             // spin
            --spins;
            if (randomYields.nextInt(CHAINED_SPINS) == 0)
                Thread.yield();           // occasionally yield
        }
        else if (s.waiter == null) {
            s.waiter = w;                 // request unpark then recheck
        }
        else if (timed) {
            nanos = deadline - System.nanoTime();
            if (nanos > 0L)
                LockSupport.parkNanos(this, nanos);
        }
        else {
            LockSupport.park(this);
        }
    }
}
```



## unsplice

```java
final void unsplice(Node pred, Node s) {
    s.forgetContents(); // forget unneeded fields
    /*
         * See above for rationale. Briefly: if pred still points to
         * s, try to unlink s.  If s cannot be unlinked, because it is
         * trailing node or pred might be unlinked, and neither pred
         * nor s are head or offlist, add to sweepVotes, and if enough
         * votes have accumulated, sweep.
         */
    // 如果pred仍然指向了s，那么尝试取消链接s。
    // 如果不能取消链接
    if (pred != null && pred != s && pred.next == s) {
        Node n = s.next;
        if (n == null ||
            (n != s && pred.casNext(s, n) && pred.isMatched())) {
            for (;;) {               // check if at, or could be, head
                Node h = head;
                if (h == pred || h == s || h == null)
                    return;          // at head or list empty
                if (!h.isMatched())
                    break;
                Node hn = h.next;
                if (hn == null)
                    return;          // now empty
                if (hn != h && casHead(h, hn))
                    h.forgetNext();  // advance head
            }
            if (pred.next != pred && s.next != s) { // recheck if offlist
                for (;;) {           // sweep now if enough votes
                    int v = sweepVotes;
                    if (v < SWEEP_THRESHOLD) {	
                        if (casSweepVotes(v, v + 1))
                            break;
                    }
                    else if (casSweepVotes(v, 0)) { // 当sweepvotes 达到最大阈值,调用sweep unlink mathed 的节点
                        sweep();
                        break;
                    }
                }
            }
        }
    }
}
```



## sweep

从head开始遍历，将mathched的节点取消

```java

/**
     * Unlinks matched (typically cancelled) nodes encountered in a
     * traversal from head.
     */
private void sweep() {
    for (Node p = head, s, n; p != null && (s = p.next) != null; ) {
        if (!s.isMatched()) // s还没有被match，遍历下一个节点
            // Unmatched nodes are never self-linked
            p = s;
        else if ((n = s.next) == null) // trailing node is pinned
            break;
        else if (s == n)    // stale， s已经被其他节点取消
            // No need to also check for p == s, since that implies s == n
            p = head;
        else
            p.casNext(s, n);  // 断开s，将p指向n
    }
}

```

