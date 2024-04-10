# 线程池分析（4）｜ThreadPoolExecutor相关类原码解析

[TOC]

## 拒绝策略担当——RejectedExecutionHandler

**我对 RejectedExecutionHandler 的理解**

> 它代表着任务的拒绝方式，任务无法被所预先配置线程池得到执行时，会执行这个类的具体实现

**分析：**

```java
// 接口规范有且只有这一个方法。参数：用户的处理逻辑内容、线程池执行器
void rejectedExecution(Runnable r, ThreadPoolExecutor executor);
```

> 4个实现类：AbortPolicy、CallerRunsPolicy、DiscardOldestPolicy、DiscardPolicy 均是`ThreadPoolExecutor`的静态内部类

### AbortPolicy

```java
// 直接抛出异常
public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
    throw new RejectedExecutionException("Task " + r.toString() +
                                         " rejected from " +
                                         e.toString());
}
```

### CallerRunsPolicy

```java
// 不再在新线程中执行用户处理逻辑，而是由调用者所在的线程执行用户处理逻辑，相当于同步执行（可能会造成阻塞）
public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
    if (!e.isShutdown()) {
        r.run();
    }
}
```

### DiscardOldestPolicy

```java
// 若没有关闭线程池，则将队列头部（最旧）的用户处理逻辑弹出直接丢弃掉，然后线程池尝试处理这个新进来的用户处理逻辑
// 换句百度知识的话说，将任务等待队列中的旧任务抛掉，并将这个新任务加入等待队列
public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
    if (!e.isShutdown()) {
      // 弹出旧的
        e.getQueue().poll();
      // 尝试执行新的，得不到执行，一般会加入等待队列
        e.execute(r);
    }
}

// 获取任务等待队列
public BlockingQueue<Runnable> getQueue() {
        return workQueue;
}
```

**属性：workQueue**

> 任务等待队列：指的是任务等待被执行的队列，先进先出
>
> 这里的任务指：用户的实际处理逻辑代码块

### DiscardPolicy

```java
// 不做任何处理，直接丢弃
public void rejectedExecution(Runnable r, ThreadPoolExecutor e) {
}
```

## Condition

**我对`Condition`的理解**

> 这个接口中提供了很多与Object顶级类中的等待/通知机制一致的方法，我们为了理解它存在的目的，需要跟Object做一个对比
>
> **另一个重要的一点是，等待会释放当前线程的锁后再放入等待队列，这点之后讲解涉及到对await的理解，很重要**

|         角度          |                          Condition                           |                            Object                            |
| :-------------------: | :----------------------------------------------------------: | :----------------------------------------------------------: |
| **等待/通知基础名称** |                    await/signal/signalAll                    |                    wait/notify/notifyAll                     |
| **等待超时时间指定**  | 1、比Object有更灵活的超时时间指定方式（可以指定单位或期限）；2、可以支持不响应中断 | 虽然也可以支持更精确的超时时间，但形式基础、单一，不支持不响应中断 |
|     **底层结构**      | 每个实例都会有自己的一个线程等待队列（底层是单链表），可以new 多个Condition对象 |                     只有一个线程等待队列                     |
|   **Java代码层面**    |    **面向语言级别，Condition与Lock配合完成等待通知机制**     | **面向java底层，与对象监视器配合完成线程间的等待/通知机制**  |

![AQS持有多个Condition.png](https://tva1.sinaimg.cn/large/e6c9d24ely1h4ix1yad6rj20lv0cb75d.jpg)

**分析：**

```java
// 使当前线程等待，直到它发出信号（唤醒）或被中断
void await() throws InterruptedException;
// 使当前线程等待，直到它发出信号（唤醒）
void awaitUninterruptibly();
// 当前线程指定时间等待
long awaitNanos(long nanosTimeout) throws InterruptedException;
// 当前线程指定值与单位等待
boolean await(long time, TimeUnit unit) throws InterruptedException;
// 当前线程指定等待期限等待
boolean awaitUntil(Date deadline) throws InterruptedException;
// 唤醒一个等待线程
void signal();
// 唤醒所有等待线程
void signalAll();
```

> 其线程池相关子类实现：`AbstractOwnableSynchronizer$ConditionObject`

由于`ConditionObject`用到了Node节点，而且均属于`AbstractOwnableSynchronizer`子类`AQS`中的内部类，`AOS`由顶层逐步讲起

## AbstractOwnableSynchronizer

**我对 AbstractOwnableSynchronizer 的理解**

> 称为：独占同步器
>
> 1、抽象模板方法，线程独占的同步器，定义了独占线程的存取
>
> 2、可序列化，但是排除独占的线程序列化

**分析：**

```java

// 构造函数：只能被子类调用
protected AbstractOwnableSynchronizer() { }

// 属性：忽略独占线程的序列化，私有独占线程
private transient Thread exclusiveOwnerThread;

//方法
protected final void setExclusiveOwnerThread(Thread thread) {
    exclusiveOwnerThread = thread;
}

protected final Thread getExclusiveOwnerThread() {
     return exclusiveOwnerThread;
}
```

> 子类：AbstractQueuedSynchronizer（AQS），抽象队列同步器，队列资源抢占方式

### AbstractQueuedSynchronizer（AQS）

**我对`AQS`的理解**

> - 实现了`AOS`，拥有了独占线程存取功能
> - 维护了Node内部类、ConditionObject内部类。Node代表一个节点，提供了多个节点指针插口实现不同功能的链表结构；ConditionObject提供了线程的等待通知机制。

**分析：**

首先它是一个抽象模板方法

**前置数据结构图示意**

![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4ho6rwp5sj21ch0u0qcs.jpg)

**大概预先了解：**

- AQS内部维护一个双向链表，一个state实现线程征用同步锁，一个Condition单链表

#### 静态内部类：Node

**我对`Node`的理解**

> 代表着一个可实现多种类型链表的线程节点，除了维护Thread以外，内部维护了一些节点指针信息prev、next、nextWaiter，以及必不可少的waitStatus（所维护的线程状态）

**分析：**

属性

```java
// 标记一个node节点是在 共享模式 下等待
static final Node SHARED = new Node();
// 标记一个node节点是在 独占模式 下等待
static final Node EXCLUSIVE = null;
// 以下是等待状态的常量值（waitStatus）
static final int CANCELLED =  1; // 当前节点线程取消对锁的争夺，需要直接清理掉（只有这个状态 > 0）
static final int SIGNAL    = -1; // 表明当前线程需要唤醒通知下一个可用节点（unpark）
static final int CONDITION = -2; // 表明是 ConditionObject类型的节点
static final int PROPAGATE = -3; // 表明释放共享资源的时候会向后传播释放其他共享节点

// 当前节点的等待状态（以上四种状态）
volatile int waitStatus;
// 当前节点的前置节点
volatile Node prev;
// 当前节点的下一个节点
volatile Node next;
// 该节点所代表的线程（使用该节点入队的线程）
volatile Thread thread;
// 指向下一个ConditionObject类型的Waiter节点（即：同一个节点即维护了一个线程双链表，也维护了一个Condition单链表节点）
Node nextWaiter;
```

构造函数

```java
// 用于建立初始头部（AQS中的head属性）或者共享模式标记
Node() {
}
// addWaiter 时使用
Node(Thread thread, Node mode) {
    this.nextWaiter = mode;
    this.thread = thread;
}
// Condition 时使用
Node(Thread thread, int waitStatus) { 
    this.waitStatus = waitStatus;
    this.thread = thread;
}
```

方法

```java
// 是否是共享模式
final boolean isShared() {
    return nextWaiter == SHARED;
}
// 获取前置节点，没有则报空指针
final Node predecessor() throws NullPointerException {
    Node p = prev;
  	if (p == null)
    	throw new NullPointerException();
  	else
    	return p;
}
```

#### 静态内部类：ConditionObject

**我对`ConditionObject`的理解**

> - 实现了`Condition`，提供了等待/通知的功能
> - 实例维护了节点的起始，也就维护了一个队列
> - 通过队列来维护`Node`形式的线程节点，实现等待通知机制

为了更好的了解ConditionObject的整个等待/通知机制，我们来看一个流程实现（看不懂也没多大关系）：

```java
// newCondition，每实例化一个，就创建一个线程等待队列，producer.await();当前线程加入producer的等待队列中，consumer.signalAll();唤醒consumer等待队列中的线程

package com.lsb.java.base.JUC;

import java.util.LinkedList;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

public class MyContainer2<T> {
    final private LinkedList<T> lists = new LinkedList<>();
    final private int MAX = 10; //最多10个元素
    
    private Lock lock = new ReentrantLock();
    private Condition producer = lock.newCondition();
    private Condition consumer = lock.newCondition();
    
    public void put(T t) {
        lock.lock();
        try {
            while(lists.size() == MAX) { //想想为什么用while而不是用if？
                producer.await();
            }
            
            lists.add(t);
            consumer.signalAll(); //通知消费者线程进行消费
        } catch (InterruptedException e) {
            e.printStackTrace();
        } finally {
            lock.unlock();
        }
    }
    
    public T get() {
        T t = null;
        lock.lock();
        try {
            while(lists.size() == 0) {
                consumer.await();
            }
            t = lists.removeFirst();
            producer.signalAll(); //通知生产者进行生产
        } catch (InterruptedException e) {
            e.printStackTrace();
        } finally {
            lock.unlock();
        }
        return t;
    }
    
    public static void main(String[] args) {
        MyContainer2<String> c = new MyContainer2<>();
        //启动消费者线程
        for(int i=0; i<10; i++) {
            new Thread(()->{
                for(int j=0; j<5; j++) System.out.println(c.get());
            }, "c" + i).start();
        }
        
        try {
            TimeUnit.SECONDS.sleep(2);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        
        //启动生产者线程
        for(int i=0; i<2; i++) {
            new Thread(()->{
                for(int j=0; j<25; j++) c.put(Thread.currentThread().getName() + " " + j);
            }, "p" + i).start();
        }
    }
}
```

**ConditionObject分析：**

属性 & 相关方法 & 构造函数

```java
// 说明每个实例都维护了一个单链表，Node指针属性为nextWaiter，先进先出，即：维护了一个等待队列
private transient Node firstWaiter;
private transient Node lastWaiter;
// 空参构造
public ConditionObject() { }

// 该模式意味着在退出或等待时，重新中断
private static final int REINTERRUPT =  1;
// 该模式意味着在退出或等待时，抛出中断异常
private static final int THROW_IE    = -1;
```

![condition-condition-A97bUS](https://tva1.sinaimg.cn/large/e6c9d24ely1h4hrmupnfcj20kc0723yw.jpg)

##### 方法：await

**当调用condition.await()方法后会使得当前获取lock的线程进入到等待队列，若是该线程可以从await()方法返回的话必定是该线程获取了与condition相关联的lock，否则，即获取不到lock就会阻塞**

```java
// 插入到等待队列--释放锁--唤醒--后续操作
public final void await() throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
  // 将当前线程Node尾插入到等待队列中
    Node node = addConditionWaiter();
	// 完全释放锁（本质：修改本节点状态，唤醒下一个节点）
    int savedState = fullyRelease(node);
    int interruptMode = 0;// 标识什么类型的原因唤醒了当前线程
  // isOnSyncQueue：表明已经唤醒进入了同步等待队列，准备获取资源执行。
  // 这里就是await就是需要park，没有得到唤醒，是没办法到等待队列中的
    while (!isOnSyncQueue(node)) {
      // 当前线程进入到等待
        LockSupport.park(this);
      // 被唤醒后，检测是否因为中断唤醒
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            break;
    }
		// 自旋等待获取到资源（即获取到lock），并且即便中断也不需要抛异常
    if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
      // 就设置为重新中断模式
        interruptMode = REINTERRUPT;
    if (node.nextWaiter != null) // clean up if cancelled
      // 不为null，就清洗一下等待队列
        unlinkCancelledWaiters();
	  // 处理被中断的状况
    if (interruptMode != 0)
        reportInterruptAfterWait(interruptMode);
}
```

咱们都知道**当当前线程调用condition.await()方法后，会使得当前线程释放lock而后加入到等待队列中，直至被signal/signalAll后会使得当前线程从等待队列中移至到同步队列中去，直到得到了lock后才会从await方法返回，或者在等待时被中断会作中断处理**。那么关于这个实现过程咱们会有这样几个问题：

- 是怎样将当前线程添加到等待队列中去的？
- 释放锁的过程？
- 怎样才能从await方法退出？

###### **是怎样将当前线程添加到等待队列中去的？**

> addConditionWaiter：添加`Condition`类型等待节点

```java
// 在等待队列中添加一个Condition类型的Waiter节点
private Node addConditionWaiter() {
    Node t = lastWaiter;
    // 如果 lastWaiter 被取消，则清除
    if (t != null && t.waitStatus != Node.CONDITION) {
      // 刷新整个Conditidon等待队列，并重置 lastWaiter 到单链表最后一个节点位置
        unlinkCancelledWaiters();
      // 重新赋值
        t = lastWaiter;
    }
  // 将当前线程包装成Node
    Node node = new Node(Thread.currentThread(), Node.CONDITION);
    if (t == null)
      // 若链表为空，则新节点即是头一个等待节点，又是最后一个等待节点
        firstWaiter = node;
    else
      // 尾插入
        t.nextWaiter = node;
		// 更新lastWaiter
    lastWaiter = node;
    return node;
}
```

> unlinkCancelledWaiters：剔除之前是现在却不是的Condition节点

```java
// 之前为Condition类型的节点现在变为非Condition节点，此方法的目的就是在此节点变为非Condition节点之后，从单链表中清除此节点的同时，重新调整Condition单链表的起始位置和中止位置
private void unlinkCancelledWaiters() {
    Node t = firstWaiter;
  // 负责定位追踪最后一个Condition类型的等待节点
    Node trail = null;
    while (t != null) {
        Node next = t.nextWaiter;
        if (t.waitStatus != Node.CONDITION) {
          // 找到非Condition节点后负责将其与Condition节点断开连接，保证所有关联到的节点都是Condition类型，没有多余的非Condition节点指向Condition节点或者被Condition节点指向
          // 剔除掉非Condition节点
            t.nextWaiter = null;
            if (trail == null)
              // 说明剔除节点为之前Condition单链表的头节点
                firstWaiter = next;
            else
              // 说明剔除节点为之前Condition单链表的中间节点
                trail.nextWaiter = next;
            if (next == null)
              // 将 lastWaiter指针 指向目前单链表中最后一个节点
                lastWaiter = trail;
        }
        else
            trail = t;
        t = next;
    }
}
```

> 理解：unlinkCancelledWaiters

## ![线程池](https://tva1.sinaimg.cn/large/e6c9d24egy1h4ht4xrin6j20u0107779.jpg)

这段代码就很容易理解了，将当前节点包装成Node，若是等待队列的firstWaiter为null的话（等待队列为空队列），则将firstWaiter指向当前的Node,不然，更新lastWaiter(尾节点)便可。就是**经过尾插入的方式将当前线程封装的Node插入到等待队列中便可**，同时能够看出等待队列是一个**不带头结点的链式队列**，以前咱们学习AQS时知道同步队列**是一个带头结点的链式队列**，这是二者的一个区别。将当前节点插入到等待对列以后，会使当前线程释放lock，由fullyRelease方法实现：

###### **释放锁的过程？**

> final int fullyRelease(Node node)

```java
// 完全释放锁（本质：节点对共享状态进行修改，并修改自己的节点线程状态，尝试唤醒下一个应该被唤醒的节点线程，因为重入锁释放后进入等待队列，再此被唤醒时需要回复重入锁状态，所以要将重入state返回，供唤醒时使用）
final int fullyRelease(Node node) {
    boolean failed = true;// 是否释放锁失败
    try {
        int savedState = getState();
      // 释放锁（本质：修改规则之下维护的共享变量state值，也可能不需要修改）
        if (release(savedState)) {
            failed = false;
            return savedState;
        } else {
						// 不成功释放同步状态抛出异常
            throw new IllegalMonitorStateException();
        }
    } finally {
      // 释放锁失败，则当前节点标记为取消对锁的争用，等待下次请理时剔除掉
        if (failed)
            node.waitStatus = Node.CANCELLED;
    }
}
```

```java
public final boolean release(int arg) {
  // 子类允许释放锁，那就去唤醒头节点的下一个节点，返回true。
  // 不允许则返回false
    if (tryRelease(arg)) {
        Node h = head;
        if (h != null && h.waitStatus != 0)
          // 唤醒后继节点
            unparkSuccessor(h);
        return true;
    }
    return false;
}

// 必须有子类来实现
protected boolean tryRelease(int arg) {
    throw new UnsupportedOperationException();
}
```



```java
// 唤醒节点的后继节点
private void unparkSuccessor(Node node) {

    int ws = node.waitStatus;
    if (ws < 0)
         // 为负的话，说明该节点可用，并将这个节点改为sync队列中普通的等待节点
        compareAndSetWaitStatus(node, ws, 0);

    // 唤醒当前节点后面第一个不为取消状态（waitStatus=1）的节点线程
    Node s = node.next;
    if (s == null || s.waitStatus > 0) {
        s = null;
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    if (s != null)// 找到要唤醒的节点
        LockSupport.unpark(s.thread);// 唤醒对应的线程
}
```

###### **怎样从await方法退出？**

```java
while (!isOnSyncQueue(node)) {
	// 3. 当前线程进入到等待状态
    LockSupport.park(this);
    if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
        break;
}
```

我们根据代码可以看到，出口为两个地方：

- **逻辑走到break退出while循环；**
  - 当前等待的线程被中断后代码会走到break退出
- **while循环中的逻辑判断为false；**
  - 即另外线程调用的condition的signal或者signalAll方法，将当前节点被移动到了同步队列中

**当前等待的线程被中断后代码会走到break退出**

```java
// 确保节点是正常唤醒（signal），如果不是，仍然需要放入同步等待队列等待唤醒
private int checkInterruptWhileWaiting(Node node) {
    return Thread.interrupted() ?
        (transferAfterCancelledWait(node) ? THROW_IE : REINTERRUPT) :
        0;
}

// 确保在因为超时或者中断取消等待后，转移节点到同步队列中
final boolean transferAfterCancelledWait(Node node) {
  // 当前节点状态为CONDITION，说明在通知（signal）前取消了等待（await）（即：中断后得到的继续执行），则需要设置状态为0，并将节点尾插法加入到同步等待队列，返回true
    if (compareAndSetWaitStatus(node, Node.CONDITION, 0)) {
        enq(node);
        return true;
    }
  // 如果节点状态不为CONDITION，则说明已经被通知，可能在入同步队列的过程中，通过自旋来保证入队成功，并返回false，代表线程在通知之后被取消等待
    while (!isOnSyncQueue(node))
        Thread.yield();
    return false;
}
```

**正常通知，导致循环退出的情况**

```java
// 获取资源
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;//标记是否成功拿到资源
    try {
        boolean interrupted = false;//标记等待过程中是否被中断过
      //“自旋”！
        for (;;) {
            final Node p = node.predecessor();//拿到前驱
          //如果前驱是head，即该结点已成老二，那么便有资格去尝试获取资源（可能是老大释放完资源唤醒自己的，当然也可能被interrupt了）。
            if (p == head && tryAcquire(arg)) {
             //拿到资源后，将head指向该结点。所以head所指的标杆结点，就是当前获取到资源的那个结点或null。
                setHead(node);
              // setHead中node.prev已置为null，此处再将head.next置为null，就是为了方便GC回收以前的head结点。也就意味着之前拿完资源的结点出队了！
                p.next = null; // help GC
              // 成功获取资源
                failed = false;
              //返回等待过程中是否被中断过
                return interrupted;
            }
//如果自己可以休息了，就通过park()进入waiting状态，直到被unpark()。如果不可中断的情况下被中断了，那么会从park()中醒过来，发现拿不到资源，从而继续进入park()等待。
            if (shouldParkAfterFailedAcquire(p, node) &&
                parkAndCheckInterrupt())
                interrupted = true;//如果等待过程中被中断过，哪怕只有那么一次，就将interrupted标记为true
        }
    } finally {
      // 如果等待过程中没有成功获取资源（如timeout，或者可中断的情况下被中断了），那么取消结点在队列中的等待。
        if (failed)
            cancelAcquire(node);
    }
}
```

```java
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
    int ws = pred.waitStatus;
    if (ws == Node.SIGNAL)
      // 如果已经告诉前驱拿完号后通知自己一下，那就可以安心休息了
        return true;
    if (ws > 0) {
      /*
         * 如果前驱放弃了，那就一直往前找，直到找到最近一个正常等待的状态，并排在它的后边。
         * 注意：那些放弃的结点，由于被自己“加塞”到它们前边，它们相当于形成一个无引用链，稍后就会被保安大叔赶走了(GC回收)！
         */
        do {
            node.prev = pred = pred.prev;
        } while (pred.waitStatus > 0);
        pred.next = node;
    } else {
       //如果前驱正常，那就把前驱的状态设置成SIGNAL，告诉它拿完号后通知自己一下。有可能失败，人家说不定刚刚释放完呢！
        compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
    }
    return false;
}

private final boolean parkAndCheckInterrupt() {
 	   LockSupport.park(this);//调用park()使线程进入waiting状态
     return Thread.interrupted();//如果被唤醒，查看自己是不是被中断的。
}
```

##### 方法：signal

```java
// 将等待时间最长的线程（如果存在）从该条件的等待队列移动到拥有锁的等待队列。
public final void signal() {
  // 当前的线程是否已经获取到了同步状态
    if (!isHeldExclusively())
        throw new IllegalMonitorStateException();
    Node first = firstWaiter;
    if (first != null)
      // 去唤醒（本质：从Condition等待队列移除，放入等待唤醒队列）
        doSignal(first);
}
```

```java
private void doSignal(Node first) {
    do {
      // 队列头节点弹出来，抹去等待队列的指针
        if ( (firstWaiter = first.nextWaiter) == null)
            lastWaiter = null;
        first.nextWaiter = null;
    } while (!transferForSignal(first) &&
             (first = firstWaiter) != null);
}

// 
final boolean transferForSignal(Node node) {
    // 从Condition等待队列移除，自然要改变节点状态，改变不了就去求吧～
    if (!compareAndSetWaitStatus(node, Node.CONDITION, 0))
        return false;
  // 尾插到唤醒等待队列，并得到原来的尾巴节点（因为当前节点的唤醒是按照上个节点的状态来通知是否应该唤醒当前节点的）
    Node p = enq(node);
  // 
    int ws = p.waitStatus;
  // 原来的尾节点不参与竞争了（取消掉了：1 = CANCEL）自然到了本节点执行，但若是原来的尾部节点仍然参与锁的竞争，那么我们修改他的状态来保证本节点在后面排队
    if (ws > 0 || !compareAndSetWaitStatus(p, ws, Node.SIGNAL))
        LockSupport.unpark(node.thread);
    return true;
}

// 尾插法插入当前节点到同步锁竞争队列中，唤醒等待排队，并返回前一个节点
private Node enq(final Node node) {
    // CAS自旋
    for (;;) {
        Node t = tail;
        if (t == null) { 
          // 初始化AQS同步等待队列
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            node.prev = t;
						// CAS设置本节点到尾部，并返回原来的尾部节点
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
```

#### AQS总结

![未命名文件](https://tva1.sinaimg.cn/large/e6c9d24ely1h4k9dt4f3tj20u010ftcg.jpg)

**区分概念：**

- Condition维护等待队列（单链表）、AQS负责维护资源抢占双向链表
- 线程通过await封装成Node加入到等待队列等待通知，在signal中将等待队列中的要唤醒的元素加入到抢占资源队列
- 等待过程中，线程发生中断，会停止线程等待继续执行，按照同步队列的要求，我们head节点才有抢占到资源分配资源到其他节点的资格，所以我们要在线程唤醒后执行的时候多做判断一步该线程是否可继续执行





## Worker

**我对 Worker 的理解**

> s

**分析：**

