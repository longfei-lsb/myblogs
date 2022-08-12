# 线程池分析（4）｜AQS源码解析

[TOC]

# 前言

Java 中的很多同步类，如 `ReentrantLock`、`CountDownLatch` 等都是基于 **AbstractQueuedSynchronizer（简称为AQS）**实现的。AQS 是一种提供**原子式管理同步状态**、**阻塞和唤醒线程功能**以及**维护队列模型**的抽象框架，用来构建锁或者其他同步组件。本篇文章将重点介绍 AQS 框架的实现原理，围绕独占模式和共享模式对同步状态的获取、释放，以及入队阻塞和唤醒出队流程展开说明。

# 概述

AQS 框架的整体架构图如下图所示：
[![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4l8h5n9snj20u00r1zod.jpg)

AQS 框架大致分为上图中的五层，自上而下由浅入深，从 AQS 对外暴露的 API 到底层基础实现。AQS 设计基于模版方法模式，当需要自定义同步组件时，开发者只需要继承 AQS 并根据具体模式重写对应的 API 层方法，无需关注底层具体实现。当同步组件获取或释放同步状态时，AQS 模版方法会调用开发者重写的同步状态管理方法。

# 实现思路

AQS 内部维护了一个双向链表作为同步队列来管理线程节点。线程会首先尝试获取同步状态，如果获取成功则将当前线程设置为有效的工作线程。如果获取失败则将当前线程以及等待状态等信息封装成一个线程节点加入到同步队列中。接着会不断循环尝试获取同步状态（当前节点是队列头节点直接后继节点才会尝试），如果失败则阻塞挂起自己，直至被唤醒或中断。当持有同步状态的线程完全释放同步状态时，会唤醒队列中的后继节点。

AQS 实现过程如下图所示：
[![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4l8gyc5nlj21b40kagmz.jpg)

AQS 使用一个 `volatitle` 修饰的 `int` 类型的成员变量来表示同步状态，通过内部维护的同步队列来完成同步状态获取的排队工作。

## 主要工作

AQS 框架主要的工作体现在 `同步状态的管理`、`线程的阻塞和唤醒` 以及 `同步队列的维护` ，这三个任务都是基于同步状态的变化而流转的。

## 工作模式

AQS 支持共享模式 `SHARED` 和独占模式 `EXCLUSIVE`，具体实现哪种模式需要根据具体的同步组件功能而定。AQS 的设计是基于模版方法模式的，共享模式和独占模式各有一套自己固有的流程，动态变化的是交给具体同步组件实现获取同步状态的出口方法逻辑，模版方法的好处就体现出来了，AQS 内部方法会根据执行步骤调用重写的入口方法。

## 同步状态

| 方法名                                                       | 描述                    |
| ------------------------------------------------------------ | ----------------------- |
| protected final int getState()                               | 获取 state的值          |
| protected final void setState(int newState)                  | 设置 state的值          |
| protected final boolean compareAndSetState(int expect, int update) | 使用 CAS 方式更新 state |

基于 AQS 实现的同步组件，会实现它的出口方法来管理同步状态，每一种同步组件的同步状态 state 表示的语义是不一样的。而在出口方法中需要根据具体语义对同步状态进行更改，这时就需要使用 AQS 提供的以上三个方法。同步状态的变化影响着线程的阻塞入队和唤醒出队。需要注意的是，以上操作同步状态的方法都无法重写，只能内部使用。

## 出口方法

AQS 提供了大量用于自定义同步组件的出口方法，也就是 AQS 模版中的勾子方法。自定义同步组件需要按需实现以下方法：

| 方法名                                      | 描述                                                         |
| ------------------------------------------- | ------------------------------------------------------------ |
| protected boolean tryAcquire(int arg)       | 独占模式。尝试获取 arg 个同步状态，成功则返回 true ，失败则返回 false |
| protected boolean tryRelease(int arg)       | 独占模式。尝试释放 arg 个同步状态，成功则返回 true ，失败则返回 false |
| protected int tryAcquireShared(int arg)     | 共享模式。尝试获取 arg 个同步状态，负数表示失败；0表示成功，但没有剩余可用资源；正数表示成功，且有剩余资源 |
| protected boolean tryReleaseShared(int arg) | 共享模式。尝试释放 arg 个同步状态，如果释放后允许唤醒后续等待结点返回True，否则返回False |
| protected boolean isHeldExclusively()       | 当前线程是否正在独占资源，只有用到Condition才需要去实现它    |

一般来说，同步组件要么是独占模式，要么是共享模式，独占模式只需实现 `tryAcquire-tryRelease`，共享模式只需实现 `tryAcquireShared-tryReleaseShared`。当然 AQS 也支持同时实现独占和共享两种模式，如 `ReentrantReadWriteLock` 读写锁，而 `ReentrantLock` 是独占锁，因此需要实现 `tryAcquire-tryRelease` 。

## 模版方法

AQS 内部将同步状态的管理以模版方法模式封装好了，前文介绍的出口方法是交给具体子类实现的钩子方法，下面列举的核心方法是模版中共用的方法。

| 方法名                                                       | 描述                                                         |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| public final void acquire(int arg)                           | 获取独占同步状态，忽略中断。会调用 `tryAcquire(arg)` 方法，如果未获取成功，则会进入同步队列等待 |
| public final void acquireInterruptibly(int arg)              | 响应中断版本的 `acquire`                                     |
| public final boolean tryAcquireNanos(int arg, long nanosTimeout) | 响应中断 + 超时版本的 `acquire`                              |
| public final void acquireShared(int arg)                     | 获取共享同步状态，忽略中断。会调用 `tryAcquireShared` 方法，如果获取失败，则会进入同步队列等待 |
| public final void acquireSharedInterruptibly(int arg)        | 响应中断版本的 `acquireShared`                               |
| public final boolean tryAcquireSharedNanos(int arg, long nanosTimeout) | 响应中断 + 超时版本的 `acquireShared`                        |
| public final boolean release(int arg)                        | 释放独占模式的同步状态                                       |
| public final boolean releaseShared(int arg)                  | 释放共享模式的同步状态                                       |

# 源码分析

## 属性

```java
public abstract class AbstractQueuedSynchronizer
        extends AbstractOwnableSynchronizer
        implements java.io.Serializable {

    private static final long serialVersionUID = 7373984972572414691L;

    /**
     * Creates a new {@code AbstractQueuedSynchronizer} instance
     * with initial synchronization state of zero.
     */
    protected AbstractQueuedSynchronizer() {
    }

    /**
     * 延迟初始化的同步队列头，除了初始化，它只能通过方法setHead进行修改。
     * 注意：
     * 1 head 在逻辑上的含义是当前持有锁的线程，head 节点实际上是一个虚节点，本身并不会存储线程信息
     * 2 如果head存在，它的waitStatus保证不会被CANCELLED。
     */
    private transient volatile Node head;

    /**
     * 同步队列的尾部，延迟初始化。仅通过方法enq修改以添加新的等待节点。
     * 说明：
     * 当一个线程无法获取同步状态而需要被加入到同步队列时，会使用 CAS 来设置尾节点 tail 为当前线程对应的 Node 节点
     */
    private transient volatile Node tail;

    /**
     * 同步状态，在不同的同步组件中意义不一样
     */
    private volatile int state;

    /**
     *  继承自 AbstractOwnableSynchronizer 的属性，代表当前持有独占资源的线程。如：
     *  因为锁可以重入 reentrantLock.lock() 可以嵌套调用多次，所以每次用这个来判断当前线程是否已经拥有了锁，
     *  if (currentThread == getExclusiveOwnerThread()) {state++}
     */
   private transient Thread exclusiveOwnerThread; 
        
}
```

AQS 主要的属性就是以上四个，下面对其进行简要说明：

> 1 state 作为同步状态，不同的同步组件使用该属性表示不同的语义。如 ReentrantLock 中表示锁的语义；Semaphore 中表示许可证的语义；
> 2 head 和 tail 连通整个同步队列，除了头部的虚节点，队列中的每个节点都封装了一个线程和对应的状态
> 3 exclusiveOwnerThread 表示当前获取独占状态的线程

## 节点结构

```java
/**
  * Wait queue node class.
  */
 static final class Node {
     /**
      * 共享类型节点，表明节点在共享模式下等待
      */
     static final Node SHARED = new Node();
     /**
      * 独占类型节点，表明节点在独占模式下等待
      */
     static final Node EXCLUSIVE = null;

     /**
      * 等待状态 - 取消
      * 当前线程因为超时或被中断取消，属于一个终结态
      */
     static final int CANCELLED = 1;
     /**
      * 等待状态 - 通知（后继线程需要被唤醒）
      * 获取同步状态的线程释放同步状态或者取消后需要唤醒后继线程；这个状态一般都是后继线程来设置前驱节点的。
      */
     static final int SIGNAL = -1;
     /**
      * 等待状态 - 条件等待（线程在 Condition 上等待）
      * 0 状态 和 CONDITION 都属于初始状态
      */
     static final int CONDITION = -2;
     /**
      * 等待状态 - 传播（无条件向后传播唤醒动作）
      * 用于将唤醒的后继线程传递下去，该状态的引入是为了完善和增强共享状态的唤醒机制。
      * 特别说明：
      * 该状态的引入是为了解决共享同步状态并发释放导致的线程 hang 住问题
      */
     static final int PROPAGATE = -3;
     /**
      * 等待状态，初始值为 0，表示无状态
      */
     volatile int waitStatus;
     /**
      * 同步队列中使用，前驱节点
      */
     volatile Node prev;
     /**
      * 同步队列中使用，后继节点
      */
     volatile Node next;
     /**
      * 节点中封装的线程
      */
     volatile Thread thread;
     /**
      * 条件队列中使用，下一个节点
      */
     Node nextWaiter;

     /**
      * 判断当前节点是否处于共享模式等待
      */
     final boolean isShared() {
         return nextWaiter == SHARED;
     }

     /**
      * 获取前驱节点，如果为空的话抛出空指针异常
      *
      * @return
      */
     final Node predecessor() throws NullPointerException {
         Node p = prev;
         if (p == null)
             throw new NullPointerException();
         else
             return p;
     }

     Node() {    // Used to establish initial head or SHARED marker
     }

     /**
      * addWaiter会调用此构造函数
      */
     Node(Thread thread, Node mode) {     // Used by addWaiter
         this.nextWaiter = mode;
         this.thread = thread;
     }

     /**
      * Condition会用到此构造函数
      */
     Node(Thread thread, int waitStatus) { // Used by Condition
         this.waitStatus = waitStatus;
         this.thread = thread;
     }
 }
```

节点 Node 中的相关属性已经详细标注，就不再展开说明。考虑到 AQS 中有大量的状态判断与转换，下面简单梳理下 Node 的等待状态定义：

| 等待状态 waitStatus | 描述                                                         |
| ------------------- | ------------------------------------------------------------ |
| 0                   | Node 被初始化时的默认值                                      |
| CANCELLED (1)       | 线程获取同步状态的请求被取消，这是一个终结态                 |
| SIGNAL (-1)         | 这个状态一般都是后继节点来设置前驱节点的，本质上代表的不是自己的状态，而是后继节点的状态。后继线程节点已经准备好了，就等前驱节点同步状态释放。 |
| CONDITION (-2)      | 表示节点在条件队列中，节点线程等待唤醒                       |
| PROPAGATE (-3)      | 用于将唤醒后继节点传播下去，该状态的引入是为了解决共享同步状态并发释放导致的线程 hang 住问题 |

## 独占模式

### 获取同步状态

独占模式下，获取同步状态的入口有三个，在前面的**模版方法**一节中有简单介绍。由于其他两个方法都是基于 `acquire` 的基础上附加的简单逻辑，因此我们以该方法作为入口对 AQS 的整个独占模式流程进行分析。

```java
public final void acquire(int arg) {
    // 1 调用具体同步器实现的 tryAcquire 方法获取同步状态
    if (!tryAcquire(arg) &&

            // 2 获取同步状态失败，先调用 addWaiter 方法将当前线程封装成独占模式的 Node 插入到同步队列中，然后调用 acquireQueued 方法
            acquireQueued(addWaiter(Node.EXCLUSIVE), arg))

        // 3 执行到这里说明在等待期间线程被中断了，那么线程需要自我中断，用于复位中断标志
        selfInterrupt();
}
```

通过 `acquire` 方法我们可以知道，获取同步状态的线程首先会调用 `tryAcquire(arg)` 方法尝试获取同步状态，而该方法是 AQS 交给独占模式的同步组件实现的方法，用来为同步状态 `state` 定义对应的语义。如果该方法返回 true ，则说明当前线程获取同步状态成功，就直接返回了；如果获取失败，就需要加入到同步队列中，检测创建的 Node 是否为 head 的直接后继节点，如果是会尝试获取同步状态。如果获取失败则通过 LockSupport 阻塞当前线程，直至被释放同步状态的线程唤醒或则被中断，随后再次尝试获取同步状态，如此反复。下面我们对以上流程进行分解。

#### tryAcquire

```java
protected boolean tryAcquire(int arg) {
     throw new UnsupportedOperationException();
 }
```

上述方法是 AQS 提供给子类实现的，子类可根据具体的场景定义对同步状态 `state` 的操作来表示获取的结果。

#### addWaiter

获取同步状态失败后，会执行该方法将当前线程封装成独占模式的 Node 插入到同步队列尾部。具体实现如下：

```java
 /**
  * 在同步队列中新增一个节点 Node
  *
  * @param mode Node.EXCLUSIVE 类型是独占模式, Node.SHARED 类型是共享模式
  * @return 返回新创建的节点
  */
 private Node addWaiter(Node mode) {
     // 将当前线程和对应的模式 封装成一个 Node
     Node node = new Node(Thread.currentThread(), mode);

     // 将当前 node 设置为链表的尾部
     Node pred = tail;

     // 链表不为空
     if (pred != null) {

         // 先设置当前节点的前驱，确保 node 前驱节点不为 null
         node.prev = pred;

         // 通过CAS将当前节点设置为 tail
         if (compareAndSetTail(pred, node)) {

             // 上面的已经先处理 node.prev = pred ，再加上下面的  pred.next = node ，也就是实现了将当前节点 node 完整加入到链表中，也就是同步队列的末尾。
             pred.next = node;

             // 入队后直接返回当前节点
             return node;
         }
     }

     // 执行到这里说明队列为空(pred == null) 或者 CAS 加入尾部失败
     enq(node);

     return node;
 }

/**
  * 通过自旋+CAS 在队列中成功插入一个节点后返回。
  * 说明：
  *  该方法处理两种可能：等待队列为空，或者有线程竞争入队
  *
  * @param node the node to insert
  * @return node's predecessor
  */
 private Node enq(final Node node) {
     for (; ; ) {
         Node t = tail;

         // 队列为空处理
         if (t == null) { // Must initialize

             // head 和 tail 初始化的时候都是 null ，这里使用 CAS 为了处理多个线程同时进来的情况。
             // 注意：这里只是设置了 tail = head，并没有返回，也就是接着自旋
             if (compareAndSetHead(new Node()))
                 tail = head;


         } else {

             // 确保 node 前驱节点不为 null
             node.prev = t;

             // CAS 设置 tail 为 node，成功后把老的 tail也就是t连接到 node。
             // 注意：这里也是 CAS 操作，就是将当前线程节点排到队尾，有线程竞争的话排不上重复排
             if (compareAndSetTail(t, node)) {
                 t.next = node;
                 return t;
             }
         }
     }
 }
```

总的来说整个 `addWaiter` 方法就是在同步队列尾部（双向链表尾部）加入节点。以上的自旋和 CAS 操作都是为了保证节点正确加入到队列中。需要注意的是，节点在加入队列（双向链表）的过程中其实是有三步操作的，先是处理节点的前驱指针，接着将节点设置为尾节点，最后处理节点的后置指针。不难发现，如果在节点完整加入到队列前，其他线程通过后置指针访问队列可能获取的是 null ，但真实情况不应该是 null ，因此在 AQS 中涉及寻找节点的地方一般都是通过前驱指针查找，因为节点加入时前驱指针的处理是最先完成的。

此外，**同步队列的头节点是一个虚节点，不存存储关键信息（如不存储线程信息）只是占位，在初始化时或滑动同步队列时该头节点对应的是获取同步状态的线程，真正的第一个有数据的节点是从第二开始的**。下面以两个线程获取同步状态为例，线程 A 获取同步状态成功，线程 B 获取同步状态失败：

[![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4l8gaqxs6j21860e6my7.jpg)

如果再有线程获取同步状态失败，则依次在同步队列中往后排队即可。

#### acquireQueued

入队操作完成后，会将加入到队列的节点 node 作为参数进入到 `acquireQueued` 方法中，该方法可以对排队中的线程节点进行获取同步状态的操作，或者由于线程节点被中断而不再获取同步状态。

```java
final boolean acquireQueued(final Node node, int arg) {
       boolean failed = true;
       try {
           boolean interrupted = false;

           for (; ; ) {

               //  node 的前驱节点，如果为空会跑出 np 异常
               final Node p = node.predecessor();

               // 检测当前节点前驱是否 head，这是尝试获取同步状态的前提条件。注意，如果 p 是 head，说明当前节点在真实数据队列的首部，就尝试获取同步状态，头节点可是一个虚节点。
               // 执行这一步一般有两种情况：
               // 1 线程因获取不到同步状态而入队，在进入等待之前再次尝试获取同步状态，可能此时它的前驱节点已经完全释放同步状态，尽量避免将线程挂起带来的开销
               // 2 只能进入同步队列中等待，等醒来时继续尝试执行该方法
               if (p == head && tryAcquire(arg)) {

                   // 当前节点占领 head，并将 p 从同步队列中移除，防止内存泄漏
                   setHead(node);
                   p.next = null; // help GC

                   failed = false;
                   return interrupted;
               }

               // 执行到这里，说明上面的 if 分支没有成功，要么当前 node 的前驱节点不是 head ，要么就是 tryAcquire 没有竞争过其他节点。
               // 进入找“大哥：阶段，找到大哥后阻塞挂起自己。
               if (shouldParkAfterFailedAcquire(p, node) &&
                       parkAndCheckInterrupt())

                   // 如果阻塞过程中被中断，则设置 interrupted 为 true
                   interrupted = true;
           }

       } finally {
           // node.predecessor() 为空 或 tryAcquire 方法抛出异常的情况
           if (failed)
               cancelAcquire(node);
       }
   }
```

上述方法非常重要，它实现了线程入队后的系列操作：先是判断是否有资格（直接前驱是 head）尝试获取同步状态，主要是为了尽可能避免线程被挂起，如果比较幸运在这一步就获取同步状态成功了，直接占领头节点等待后续线程将其移出队列即可（再强调一遍，头节点是个虚节点）；如果不那么幸运，就需要进入寻找有效前驱节点的流程，找到后挂起自己；最后，处在同步队列中的节点要么被它的前驱唤醒要么被中断而醒来，醒来后会继续自旋尝试获取同步状态，如此反复。

了解了上述方法的逻辑后，下面对关键步骤进行拆解分析。

##### setHead

当获取同步状态成功后，当前线程节点会执行 `setHead` 方法占领同步队列头节点，即将自身节点设置为虚节点，也就是移除线程信息。注意，占领头节点并没有清除节点的等待状态信息。获取到同步状态的线程节点成为头节点后，等到该线程节点释放同步状态的时候会继续唤醒它的后继有效节点，如此反复。

```java
/**
 * 占领 head 节点，即将当前节点 node 设置为虚节点 head
 * 注意：
 * 1 头节点都是虚节点，它对应当前持有同步状态的节点。
 * 2 先当前节点的线程信息抹除掉，且断开和前置节点的联系，便于 GC
 * 3 不修改 waitStatus，因为它是一直需要用的数据
 *
 * @param node the node
 */
private void setHead(Node node) {
    head = node;
    node.thread = null;
    node.prev = null;
}
```

##### shouldParkAfterFailedAcquire

当线程节点没有资格获取同步状态或者获取同步状态失败，则会进入寻找有效前驱节点流程，因为挂起在同步队列中的线程节点需要依赖有效前驱节点唤醒的（不考虑被中断的情况）。

```java
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
        int ws = pred.waitStatus;

        // 前驱节点已经是 SIGNAL 状态，说明是有效的前驱，则后继节点（也就是当前节点）可以进入挂起模式等待它的前驱节点唤醒自己。
        // 因为节点状态为 SIGNAL 在释放同步状态时会唤醒后继节点。
        if (ws == Node.SIGNAL)
            /*
             * This node has already set status asking a release
             * to signal it, so it can safely park.
             */
            return true;

        // 前驱节点状态为 CANCELLED 状态，说明当前前驱节点取消了排队，是个无效的节点，需要把该节点剔除掉
        // 因此需要向前找第一个非取消节点作为 node 的有效前驱（就靠这个大哥到时候唤醒自己），往前遍历总能找到一个大哥
        if (ws > 0) {
            /*
             * Predecessor was cancelled. Skip over predecessors and
             * indicate retry.
             */
            do {
                node.prev = pred = pred.prev;
            } while (pred.waitStatus > 0);
            pred.next = node;

            // 前驱节点状态为 0 或者 PROPAGATE ，则设置前驱节点状态为 SIGNAL，即将当前 pred 对应的节点作为大哥
        } else {
            /*
             * waitStatus must be 0 or PROPAGATE.  Indicate that we
             * need a signal, but don't park yet.  Caller will need to
             * retry to make sure it cannot acquire before parking.
             */
            compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
        }

        // 返回 false ，那么最后会再走一次外部的 for 循环然后再次进入此方法
        return false;
    }
```

**下面对上述方法的特殊点进行说明：**

1. 前驱节点的 waitStatus=-1 是依赖于后继节点设置的。也就是说，当还没给前驱设置-1 时返回 false，第二次进来的时候状态就是-1了。
2. 进入同步队列中挂起的线程唤醒操作是由其有效前驱节点完成的。等着前驱节点获取到同步状态，然后释放同步状态时唤醒自己。也就是需要找到一个好“大哥”。
3. shouldParkAfterFailedAcquire 在读到前驱节点状态不为 SIGNAL 会给当前线程再一次获取同步状态的机会。
4. **上述方法会顺带剔除取消排队的节点**。

##### parkAndCheckInterrupt

当入队的线程节点找到了有效的前驱节点后，就可以挂起自己了，等待它的大哥叫醒自己或者被中断。

```java
/**
 * 挂起当前线程，返回当前线程的中断状态
 * 备注：
 * 1 interrupt() 中断线程，给线程设置一个中断标志
 * 2 interrupted() 判断当前线程是否被中断，返回一个boolean并清除中断状态，第二次再调用时中断状态已经被清除，将返回一个false。
 * 3 isInterrupted() 判断线程是否被中断，不清除中断状态
 *
 * @return {@code true} if interrupted
 */
private final boolean parkAndCheckInterrupt() {
    LockSupport.park(this);
    return Thread.interrupted();
}
```

至此，同步模式下的获取同步状态流程基本分析完毕。不过线程节点 node 进入同步队列后有个异常流需要被处理，也就是将 node 取消排队。下面我们重点对该流程进行分析。

#### cancelAcquire

```java
/**
     * 取消 node 排队。
     * 注意：
     * 取消的节点会在 shouldParkAfterFailedAcquire 中被踢掉
     *
     * @param node the node
     */
    private void cancelAcquire(Node node) {
        // Ignore if node doesn't exist
        if (node == null)
            return;

        // 设置节点 node 不关联任何线程
        node.thread = null;

        /* 寻找一个有效的前驱的节点作为 node 的前驱，下面在调整链表时会用到 */
        // 获取 node 的前驱节点
        Node pred = node.prev;

        // 跳过取消的节点，向前寻找第一个非取消节点作为 node 的前驱节点
        while (pred.waitStatus > 0)
            node.prev = pred = pred.prev;

        // 记录 node 的第一个有效前驱节点的后继节点，后续 CAS 会用到
        Node predNext = pred.next;

        // 直接把当前节点 node 的等待状态置为取消,后继节点即便也在取消也可以跨越 node节点。
        node.waitStatus = Node.CANCELLED;


        /* 根据当前取消节点 node 的位置，考虑以下三种情况：
         * 1 当前节点是尾节点
         * 2 当前节点是 head 的后继节点
         * 3 当前节点既不是 head 后继节点，也不是尾节点
         */

        // 1 如果 node 是尾节点，则使用 CAS 尝试将它的有效前驱节点 pred 设置为 tail
        if (node == tail && compareAndSetTail(node, pred)) {
            // 这里的CAS更新 pre d的 next 即使失败了也没关系，说明被其它新入队线程或者其它取消线程更新掉了。
            compareAndSetNext(pred, predNext, null);

            // 如果 node 不是尾节点，那么要做的事情就是将 node 有效前驱和后继节点连接起来
        } else {
            // If successor needs signal, try to set pred's next-link
            // so it will get one. Otherwise wake it up to propagate.
            int ws;

            // 2 当前节点不是 head 的后继节点：
            // a 判断当前节点前驱节点是否为 -1
            // b 如果不是，则把前驱节点设置为 SIGNAL 看是否成功
            // c 如果 a 和 b 中有一个为true，再判断当前节点的线程是否不为null
            // 如果上述条件都满足，把当前节点的前驱节点的后继指针指向当前节点的后继节点。
            if (pred != head &&
                    ((ws = pred.waitStatus) == Node.SIGNAL ||
                            (ws <= 0 && compareAndSetWaitStatus(pred, ws, Node.SIGNAL))) &&
                    pred.thread != null) {

                // 如果node的后继节点next非取消状态的话，则用CAS尝试把pred的后继置为node的后继节点
                Node next = node.next;
                if (next != null && next.waitStatus <= 0)
                    compareAndSetNext(pred, predNext, next);


                // 3 pred == head 或者 pred 状态取消或者 pred.thread == null ，这时为了保证队列的活跃性，会尝试唤醒一次后继线程。
            } else {
                unparkSuccessor(node);
            }

            // 将取消节点的 next 设置为自己而非 null，原因如下：
            //  AQS 中 Condition部分的isOnSyncQueue 方法会根据 next 判断一个原先属于条件队列的节点是否转移到了同步队列。同步队列中节点会用到 next 域，取消节点的 next 也有值的话，
            //  可以判断该节点一定在同步队列上
            node.next = node; // help GC
        }
    }
```

上述方法要做的就一件事，将节点 node 的状态标记为 `CANCELLED` ，取消排队。之所以处理得那么复杂，是要考虑到各种场景。但是我们可以看出，不管哪种场景都需要取消排队节点 node 的有效前驱，这个很好理解，为了重组链表，需要找到一个有效的前驱节点。根据当前取消节点 node 的位置会有三种情况，上述代码中已经详细标注，这里就不再说明。

**上述方法的注意事项如下：**

1. 取消的节点 node 会被后续入队线程节点从同步队列中剔除掉。
2. 当节点 node 不是尾节点时不会立即被剔除队列，只是设置等待状态为 `CANCELLED` ，需要后续线程节点去剔除。但需要将 node 的后继设置为自身，主要考虑到 `Condition` 的使用场景。
3. 取消节点逻辑都是对后继指针 next 进行操作，而没有对 prev 指针进行操作。因为当前节点的前驱节点可能已经从队列中出去了，如果此时修改 prev 指针会不安全（np异常）。因此，在整个 AQS 中可以放心地根据 prev 指针查找，而不会出现断裂的情况。

了解了获取同步状态的方法后，下面对另外两种扩展进行介绍，它们分别是 **可中断获取同步状态** 和 **超时获取同步状态** 。

### 可中断获取同步状态

```java
public final void acquireInterruptibly(int arg)
        throws InterruptedException {
    // 如果线程被中断则直接抛出中断异常
    if (Thread.interrupted())
        throw new InterruptedException();
    if (!tryAcquire(arg))
        // 线程如果被中断过会抛出中断异常
        doAcquireInterruptibly(arg);
}
 private void doAcquireInterruptibly(int arg)
        throws InterruptedException {
    final Node node = addWaiter(Node.EXCLUSIVE);
    boolean failed = true;
    try {
        for (; ; ) {
            final Node p = node.predecessor();
            if (p == head && tryAcquire(arg)) {
                setHead(node);
                p.next = null; // help GC
                failed = false;
                return;
            }
            if (shouldParkAfterFailedAcquire(p, node) &&
                    parkAndCheckInterrupt())
                // 发生中断，直接抛出异常
                throw new InterruptedException();
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
```

相比较 `acquire` 方法，上述方法仅仅对中断进行了抛出异常处理，其他流程同 `acquire` 方法。

### 超时获取同步状态

```java
  public final boolean tryAcquireNanos(int arg, long nanosTimeout)
          throws InterruptedException {
      if (Thread.interrupted())
          throw new InterruptedException();
      return tryAcquire(arg) ||
              // 获取同步状态失败，进入超时获取同步状态逻辑
              doAcquireNanos(arg, nanosTimeout);
  }
private boolean doAcquireNanos(int arg, long nanosTimeout)
          throws InterruptedException {
      if (nanosTimeout <= 0L)
          return false;
      
      // 记录超时时间
      final long deadline = System.nanoTime() + nanosTimeout;
      final Node node = addWaiter(Node.EXCLUSIVE);
      boolean failed = true;
      try {
          for (; ; ) {
              final Node p = node.predecessor();
              if (p == head && tryAcquire(arg)) {
                  setHead(node);
                  p.next = null; // help GC
                  failed = false;
                  return true;
              }

              // 获取同步状态等待时间
              nanosTimeout = deadline - System.nanoTime();
              // 超时则直接返回
              if (nanosTimeout <= 0L)
                  return false;

              // 寻找有效的前驱节点，找到后挂起当前线程 nanosTimeout 时间，在这段时间内没有被唤醒也会自动醒来
              if (shouldParkAfterFailedAcquire(p, node) &&
                      nanosTimeout > spinForTimeoutThreshold)
                  LockSupport.parkNanos(this, nanosTimeout);
              if (Thread.interrupted())
                  throw new InterruptedException();
          }
      } finally {
          if (failed)
              cancelAcquire(node);
      }
  }
```

相比较 `acquire` 方法，上述方法增加了对中断进行了抛出异常处理和超时等待同步状态逻辑，其他流程同 `acquire` 方法。

### 释放同步状态

前面对独占模式下获取同步状态的流程进行了详细分析，接下来对独占模式下释放同步状态流程进行分析。释放同步状态逻辑相比获取同步状态的逻辑简单很多，它的入口只有一个， `release` 方法 。

```java
public final boolean release(int arg) {
       // 调用 tryRelease 方法释放 arg 个同步状态
       if (tryRelease(arg)) {

           // 当前线程获取 head 节点
           Node h = head;

           // head 节点状态不会是 CANCELLED ，所以这里 h.waitStatus != 0 相当于 h.waitStatus < 0
           // 只有 head 存在且状态小于 0 的情况下唤醒
           if (h != null && h.waitStatus != 0)
               // 唤醒后继节点
               unparkSuccessor(h);
           return true;
       }
       return false;
   }
```

独占模式下释放同步状态，首先调用 `tryRelease` 方法尝试获取同步状态，获取同步状态失败直接返回；获取同步状态成功后，会尝试唤醒同步队列中的后继线程节点。

**需要特别说明的是唤醒的前置条件为什么是 `h != null && h.waitStatus != 0`：**

1. h == null 说明同步队列还初始化，里面并没有需要唤醒的线程节点。
2. h != null && h.waitStatus == 0 说明后继节点对应的线程仍在运行中，至少没有找到有效前驱节点，因此不需要唤醒。
3. h != null && h.waitStatus < 0 说明后继节点可能被阻塞了，需要唤醒。

**上述方法中的 head 的可能性有很多，不一定是当前线程对应的节点：**

1. null ，AQS 的 head 延迟初始化

2. 当前线程通过

    

   ```java
   tryRelease
   ```

    

   方法完全释放掉同步状态，刚好此时有新的线程节点入队并在

    

   ```java
   acquireQueue
   ```

    

   中获取到了同步状态并占领了 head。具体情况如下：

   ```tex
   情况一：
        时刻1:线程A通过acquireQueued，持锁成功，set了head
        时刻2:线程B通过tryAcquire试图获取独占锁失败失败，进入acquiredQueued
        时刻3:线程A通过tryRelease释放了独占锁
        时刻4:线程B通过acquireQueued中的tryAcquire获取到了独占锁并调用setHead
        时刻5:线程A读到了此时的head实际上是线程B对应的node
    情况二：
        时刻1:线程A通过tryAcquire直接持锁成功，head为null
        时刻2:线程B通过tryAcquire试图获取独占锁失败失败，入队过程中初始化了head，进入acquiredQueued
        时刻3:线程A通过tryRelease释放了独占锁，此时线程B还未开始tryAcquire
        时刻4:线程A读到了此时的head实际上是线程B初始化出来的虚节点 head
   ```

下面仍然对释放同步状态的流程进行拆解分析。

#### tryRelease

```java
protected boolean tryRelease(int arg) {
    throw new UnsupportedOperationException();
}
```

上述方法是 AQS 提供给子类实现的，子类可根据具体的场景定义对同步状态 `state` 的操作来表示释放的结果。

#### unparkSuccessor

当释放同步状态成功后，会根据当前头节点 head 的状态判断是否唤醒后继线程节点。

```java
/**
    * 唤醒后继节点（线程）
    *
    * @param node the node
    */
   private void unparkSuccessor(Node node) {

       // 尝试将 node 的等待状态设置为 0 ，这样的话后继竞争线程可以有机会再尝试获取一次同步状态
       int ws = node.waitStatus;
       if (ws < 0)
           compareAndSetWaitStatus(node, ws, 0);


       /**
        * 如果 node.next 存在且状态不为取消，则直接唤醒 s 即可。否则需要从 tail 开始向前找到 node 之后最近的非取消节点然后唤醒它，没有则无需唤醒。
        * 注意：s == null ，不代表 node 就是 tail ，因为节点入队并不是原子操作。如 addWaiter 方法过程：
        *  1 某时刻 node 为 tail
        *  2 有新的线程通过 addWaiter 方法添加自己到同步队列
        *  3 compareAndSetTail 成功，但此时 node.next 指针还没有更新完成，值仍为 null ，而此时 node 已经不是 tail，它有后继了
        */
       Node s = node.next;
       if (s == null || s.waitStatus > 0) {
           s = null;
           // 从tail向前查找最接近 node 的非取消节点 (waitStatus==1) 
           for (Node t = tail; t != null && t != node; t = t.prev)
               if (t.waitStatus <= 0)
                   s = t;
       }

       // 唤醒节点 s 中的线程
       if (s != null)
           LockSupport.unpark(s.thread);
   }
```

上述方法的唯一工作就是尝试唤醒节点 node 的直接有效后继节点。需要注意，如果 node 的后继节点是 null 或取消节点，那么需要从同步队列尾部向前找距离 node 最近的有效节点并唤醒。

这里寻找有效后继节点的条件是 `s == null || s.waitStatus > 0` 的原因如下：

1. s == null ，对应的是线程节点入队并不是原子操作，next 的指针还没有来得及处理，因此需要从后往前遍历才能够遍历完全部的节点。
2. s.waitStatus > 0 ，对应的是在产生 CANCELLED 状态节点的时候，处理的是 next 指针，prev 指针并未处理，因此也是需要从后往前遍历才能够遍历完全部的节点。

#### 唤醒后续流程

挂起在同步队列中的节点恢复，从以下方法返回。

```java
/**
    * 挂起当前线程，返回当前线程的中断状态
    * 备注：
    * 1 interrupt() 中断线程，给线程设置一个中断标志
    * 2 interrupted() 判断当前线程是否被中断，返回一个boolean并清除中断状态，第二次再调用时中断状态已经被清除，将返回一个false。
    * 3 isInterrupted() 判断线程是否被中断，不清除中断状态
    *
    * @return {@code true} if interrupted
    */
   private final boolean parkAndCheckInterrupt() {
       LockSupport.park(this);
       return Thread.interrupted();
   }
```

线程节点醒来的原因可能是其他线程唤醒的，也可能是挂起的线程被中断了，因此这里需要判断线程在等待期间是否被中断过。线程醒来后会再回到 `acquireQueued` 方法中，当parkAndCheckInterrupt 返回 ture 或者 false 的时候，interrupted 的值不同，但都会执行下次循环尝试获取同步状态。如果获取同步状态成功，当前线程节点会占领头节点，并将原来的头节点移除队列，最后会把 interrupted 返回，然后回到 `acquire` 方法，如下：

```java
public final void acquire(int arg) {
    // 1 调用具体同步器实现的 tryAcquire 方法获取同步状态
    if (!tryAcquire(arg) &&

            // 2 获取同步状态失败，先调用 addWaiter 方法将当前线程封装成独占模式的 Node 插入到同步队列中，然后调用 acquireQueued 方法
            acquireQueued(addWaiter(Node.EXCLUSIVE), arg))

        // 3 执行到这里说明在等待期间线程被中断了，那么线程需要自我中断，用于复位中断标志
        selfInterrupt();
}
```

如果 `acquireQueued` 返回 true ，就会执行 `selfInterrupt` 方法。

```java
/**
 * 中断当前线程，以复位中断标志
 */
static void selfInterrupt() {
    Thread.currentThread().interrupt();
}
```

在 `acquire` 中执行 **selfInterrupt** 和在 `acquireQueued` 中执行 **parkAndCheckInterrupt** 是相互呼应的，是为了复位线程的中断标志。为什么搞这么麻烦，因为不明确线程醒来的原因，可能是释放同步状态的线程唤醒的，也可能是被中断了。

至此，整个唤醒流程结束。

### 独占模式流程图

[![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4l8fy2r3xj214x0u00uk.jpg)

## 共享模式

### 获取同步状态

共享模式下，获取同步状态的入口也有三个，在前面的**模版方法**一节中有简单介绍。由于其他两个方法都是基于 `acquireShared` 的基础上附加的简单逻辑，因此我们也以该方法作为入口对 AQS 的整个共享模式流程进行分析。需要注意的是，**与独占模式区别关键在于共享模式允许多个线程持有同步状态**。

```java
 public final void acquireShared(int arg) {

     // 调用 tryAcquireShared 方法尝试获取同步状态
     if (tryAcquireShared(arg) < 0)
         // 获取失败
         doAcquireShared(arg);
}
```

获取同步状态的线程首先会调用 `tryAcquireShared(arg)` 方法尝试获取同步状态，该方法是 AQS 交给共享模式的同步组件实现的方法，用来为同步状态 `state` 定义对应的语义。如果该方法返回值大于等于 0 ，说明当前线程获取同步状态成功，直接返回即可；如果获取失败，则执行 `doAcquireShared(arg)` 方法，类似独占模式下的 `acquireQueued` 方法，不过共享模式有自己独特的传播特性，而独占模式没有传播特性。下面依然分解过程分析。

#### tryAcquireShared

```java
protected int tryAcquireShared(int arg) {
    throw new UnsupportedOperationException();
}
```

上述方法是 AQS 提供给共享模式的子类组件实现的方法。在实现 tryAcquireShared 方法时需要注意，返回负数表示获取失败；返回 0 表示成功，但是后继竞争线程不会成功；返回正数表示获取成功，并且后继竞争线程也可能成功。

#### doAcquireShared

获取同步状态失败后，会执行该方法。

```java
private void doAcquireShared(int arg) {

      // 将当前线程以共享模式的方式加入到同步队列
      final Node node = addWaiter(Node.SHARED);
      boolean failed = true;
      try {
          boolean interrupted = false;

          for (; ; ) {
              // 获取前驱节点
              final Node p = node.predecessor();

              // 如果前驱节点为 head ，则尝试获取同步状态
              if (p == head) {
                  int r = tryAcquireShared(arg);

                  // 一旦获取共享同步状态成功，通过传播机制唤醒后继节点
                  if (r >= 0) {

                      setHeadAndPropagate(node, r);

                      // 将旧的头节点从同步队列中移除
                      p.next = null; // help GC
                      if (interrupted)
                          selfInterrupt();
                      failed = false;
                      return;
                  }
              }

              // 进入找大哥流程
              if (shouldParkAfterFailedAcquire(p, node) &&
                      // 挂起线程
                      parkAndCheckInterrupt())
                  interrupted = true;
          }
      } finally {
          // 取消节点
          if (failed)
              cancelAcquire(node);
      }
  }
```

**下面对共享模式下获取同步状态失败的流程进行简要总结：**

1. 将当前线程封装成共享模式的 Node 插入到同步队列的尾部。addWaiter 方法的流程见上文。
2. 判断是否有资格（前驱节点是 head）尝试获取同步状态，同样是为了尽最大可能避免挂起线程。
3. 如果获取同步状态成功，则占领头节点并通过传播机制唤醒尝试唤醒后继节点。注意，该过程是和独占模式不同的，根本原因在于共享模式允许同时有多个线程获取同步状态，传播机制是为了解决并发释放同步状态导致后续节点没有唤醒问题。
4. 如果获取失败则进入寻找有效前驱节点流程，和独占模式一致。
5. 对 node.predecessor() 为空 或 tryAcquireShared 方法抛出异常的处理，和独占模式一致。

了解了整个获取共享同步状态流程后，下面仍然进行拆解分析，前文已经分析过的方法就不再重复分析。其实可以看出，共享模式和独占模式唯一的区别在于 `setHeadAndPropagate` 方法。由于独占模式的特点，不需要传播唤醒特点。而共享模式允许多个线程同时持有同步状态，因此当获取后的同步状态仍然大于 0 那么可以继续唤醒后继线程，这就是共享模式下的传播特性。

##### setHeadAndPropagate

再次获取同步状态成功后，会执行该方法。

```java
/**
 * 该方法主要做以下两件事：
 * 1. 在获取共享同步状态后，占领 head 节点
 * 2. 根据情况唤醒后继线程
 *
 * @param node      the node
 * @param propagate the return value from a tryAcquireShared
 */
private void setHeadAndPropagate(Node node, int propagate) {
    // 记录 head
    Node h = head; // Record old head for check below

    // 占领 head
    setHead(node);

    /**
     * 1 propagate 是 tryAcquireShared 的返回值，这是决定是否传播唤醒的依据之一。
     * 2 h.waitStatus 为 SIGNAL 或 PROPAGATE 时，根据 node 的下一个节点类型（共享模式）来决定是否传播唤醒
     */
    if (propagate > 0 || h == null || h.waitStatus < 0 ||
            (h = head) == null || h.waitStatus < 0) {

        Node s = node.next;
        
        // 注意 s == null 不代表 node 就是尾节点，可能它的后继节点取消了排队，这种情况已经继续尝试唤醒有效的后继节点
        if (s == null || s.isShared())
            doReleaseShared();
    }
}
```

通过前文的描述，不难看出上述方法的作用。除了占领头节点，还会根据需要继续唤醒后继节点，也就是传播唤醒。传播唤醒的前置条件 `propagate > 0` 比较好理解，还有同步状态可获取，唤醒后继等待的线程节点即可。但是 `h.waitStatus < 0` 条件就不太好理解了，为什么要多加这个条件呢？下面会详细分析。接下来继续看传播唤醒的方法 `doReleaseShared()` ，其实这个方法是释放同步状态方法公用的方法。我们在释放同步状态方法中再去分析该方法。

至此，共享模式下的获取同步状态流程分析完毕。同样地，下面简单地对另外两个获取同步状态的方法进行介绍，它们是基于 `acquireShared` 方法增强的功能，比较简单。

### 可中断获取同步状态

```java
public final void acquireSharedInterruptibly(int arg)
        throws InterruptedException {
    // 中断处理
    if (Thread.interrupted())
        throw new InterruptedException();
    if (tryAcquireShared(arg) < 0)
        // 线程如果被中断过会抛出中断异常
        doAcquireSharedInterruptibly(arg);
}

private void doAcquireSharedInterruptibly(int arg)
        throws InterruptedException {
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        for (; ; ) {
            final Node p = node.predecessor();
            if (p == head) {
                int r = tryAcquireShared(arg);
                if (r >= 0) {
                    setHeadAndPropagate(node, r);
                    p.next = null; // help GC
                    failed = false;
                    return;
                }
            }
            if (shouldParkAfterFailedAcquire(p, node) &&
                    parkAndCheckInterrupt())
                // 响应中断
                throw new InterruptedException();
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
```

相比较 `acquireShared` 方法，上述方法仅仅对中断进行了抛出异常处理，其他流程同 `acquireShared` 方法。

### 超时获取同步状态

```java
public final boolean tryAcquireSharedNanos(int arg, long nanosTimeout)
        throws InterruptedException {
    // 中断处理
    if (Thread.interrupted())
        throw new InterruptedException();
    return tryAcquireShared(arg) >= 0 ||
            // 获取同步状态失败，进入超时获取同步状态逻辑
            doAcquireSharedNanos(arg, nanosTimeout);
}

private boolean doAcquireSharedNanos(int arg, long nanosTimeout)
        throws InterruptedException {
    if (nanosTimeout <= 0L)
        return false;

    // 记录超时时间
    final long deadline = System.nanoTime() + nanosTimeout;
    final Node node = addWaiter(Node.SHARED);
    boolean failed = true;
    try {
        for (; ; ) {
            final Node p = node.predecessor();
            if (p == head) {
                int r = tryAcquireShared(arg);
                if (r >= 0) {
                    setHeadAndPropagate(node, r);
                    p.next = null; // help GC
                    failed = false;
                    return true;
                }
            }

            // 获取同步状态等待时间
            nanosTimeout = deadline - System.nanoTime();

            // 超时则直接返回 false
            if (nanosTimeout <= 0L)
                return false;

            // 寻找有效的前驱节点，找到后挂起当前线程 nanosTimeout 时间，在这段时间内没有被唤醒也会自动醒来
            if (shouldParkAfterFailedAcquire(p, node) &&
                    nanosTimeout > spinForTimeoutThreshold)
                LockSupport.parkNanos(this, nanosTimeout);
            if (Thread.interrupted())
                throw new InterruptedException();
        }
    } finally {
        if (failed)
            cancelAcquire(node);
    }
}
```

相比较 `acquireShared` 方法，上述方法增加了对中断进行了抛出异常处理和超时等待同步状态逻辑，其他流程同 `acquireShared` 方法。

### 释放同步状态

```java
/**
 * 释放共享同步状态
 * 注意：
 * 共享锁的获取过程（执行传播）和释放都会涉及到 doReleaseShared 方法，也就是后继节点的唤醒
 *
 * @param arg the release argument.  This value is conveyed to
 *            {@link #tryReleaseShared} but is otherwise uninterpreted
 *            and can represent anything you like.
 * @return the value returned from {@link #tryReleaseShared}
 */
public final boolean releaseShared(int arg) {
    // 调用 tryReleaseShared 方法尝试释放同步状态
    if (tryReleaseShared(arg)) {
        // 进入唤醒后继节点逻辑
        doReleaseShared();
        return true;
    }
    return false;
}
```

释放同步状态比较简单，先调用 `tryReleaseShared` 方法尝试释放同步状态，释放成功后调用 `doReleaseShared` 方法进入唤醒后继节点逻辑。

#### tryReleaseShared

```java
protected boolean tryReleaseShared(int arg) {
    throw new UnsupportedOperationException();
}
```

上述方法是 AQS 提供给共享模式的子类组件实现的方法，用于定义释放同步状态的。

#### doReleaseShared

```java
private void doReleaseShared() {

       /**
        * 以下循环做的事情是，在队列存在后继节点时，唤醒后继节点；或者由于并发释放共享同步状态导致读到 head 节点等待状态为 0 ，虽然不能执行 unparkSuccessor ，
        * 但为了保证唤醒能够正确传递下去，设置节点状态为 PROPAGATE。这样的话获取同步状态的线程在执行 setHeadAndPropagate 时可以读到 PROPAGATE，从而由获取
        * 同步状态的线程去释放后继等待节点。
        */
       for (; ; ) {
           Node h = head;
           // 如果队列中存在后继节点
           if (h != null && h != tail) {
               int ws = h.waitStatus;

               // 如果 head 的状态为 SIGNAL ，则尝试将其设置为 0 并唤醒后继节点
               if (ws == Node.SIGNAL) {
                   if (!compareAndSetWaitStatus(h, Node.SIGNAL, 0))
                       continue;            // loop to recheck cases
                   // 唤醒后继节点
                   unparkSuccessor(h);

                   // 如果 head 节点的状态为 0 ,需要设置为 PROPAGATE 用以保证唤醒的传播，即通过 setHeadAndPropagate 方法唤醒此时由于并发导致的未能唤醒的后继节点
               } else if (ws == 0 &&
                       !compareAndSetWaitStatus(h, 0, Node.PROPAGATE))
                   continue;                // loop on failed CAS
           }

           // 检查h是否仍然是head，如果不是的话需要再进行循环。
           // 由 unparkSuccessor 唤醒的节点调用 setHeadAndPropagate 方法可能执行较快，已经占领了 head
           if (h == head)                   // loop if head changed
               break;
       }
   }
```

上述方法是共享模式释放同步状态的核心方法，用来唤醒后继节点或设置设置头节点传播状态 `PROPAGATE`。 该方法可能会承受并发调用，一旦发生并发调用会存在线程设置头节点状态为 `SIGNAL` 失败，接着会自旋将头节点状态设置为 `PROPAGATE` 保证唤醒的传播。

### 共享模式流程图

[![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4l8fp89iwj212i0u00uf.jpg)

### PROPAGATE 状态

AQS 中的 `PROPAGATE` 状态相比其它状态较难理解，它的引入是**为了解决共享模式下并发释放同步状态导致的线程节点无法唤醒问题**。下面从一个 bug 说起引入 `PROPAGATE` 的作用。

#### Bug

```java
import java.util.concurrent.Semaphore;

public class TestSemaphore {
   // 这里设置许可证为 0，意味着在释放许可证之前，所有获取许可证的线程都会挂起在同步队列中
   private static Semaphore sem = new Semaphore(0);

   private static class Thread1 extends Thread {
       @Override
       public void run() {
           // 获取许可证
           sem.acquireUninterruptibly();
       }
   }

   private static class Thread2 extends Thread {
       @Override
       public void run() {
           // 释放许可证
           sem.release();
       }
   }

   public static void main(String[] args) throws InterruptedException {
       for (int i = 0; i < 10000000; i++) {
           Thread t1 = new Thread1();
           Thread t2 = new Thread1();
           Thread t3 = new Thread2();
           Thread t4 = new Thread2();
           t1.start();
           t2.start();
           t3.start();
           t4.start();
           t1.join();
           t2.join();
           t3.join();
           t4.join();
           System.out.println(i);
       }
   }
}
```

上述代码偶现线程挂起无法退出的情况。当然这个代码在新版的 JDK 中是不存在的，下面我们来看当时的版本涉及的相关方法。

#### 相关方法

**获取同步状态**

```java
private void doAcquireShared(int arg) {
	        final Node node = addWaiter(Node.SHARED);
	        boolean failed = true;
	        try {
	            boolean interrupted = false;
	            for (;;) {
	                final Node p = node.predecessor();
	                if (p == head) {
	                    int r = tryAcquireShared(arg);
	                    if (r >= 0) {
	                        setHeadAndPropagate(node, r);
	                        p.next = null; // help GC
	                        if (interrupted)
	                            selfInterrupt();
	                        failed = false;
	                        return;
	                    }
	                }
	                if (shouldParkAfterFailedAcquire(p, node) &&
	                    parkAndCheckInterrupt())
	                    interrupted = true;
	            }
	        } finally {
	            if (failed)
	                cancelAcquire(node);
	        }
	    }
```

**释放同步状态**

```java
   public final boolean releaseShared(int arg) {
           // 并发执行可能读取的 h.waitStatus == 0，导致不能唤醒后继线程节点
        if (tryReleaseShared(arg)) {
            Node h = head;
            if (h != null && h.waitStatus != 0)
                unparkSuccessor(h);
            return true;
        }
        return false;
}
```

**设置头并传播**

```java
private void setHeadAndPropagate(Node node, int propagate) {
     setHead(node);

        // 传播的条件，注意和新版 JDK 中的区别
        // if (propagate > 0 || h == null || h.waitStatus < 0 || (h = head) == null || h.waitStatus < 0) 
     if (propagate > 0 && node.waitStatus != 0) {
         /*
          * Don't bother fully figuring out successor.  If it
          * looks null, call unparkSuccessor anyway to be safe.
          */
         Node s = node.next;
         if (s == null || s.isShared())
             unparkSuccessor(node);
     }
 }
```

#### 复现 Bug

根据上面复现 Bug 的测试程序，走一遍源码，看看问题出现在哪个环节。

程序循环中做的事情就是创建 4 个线程，其中 2 个线程用于获取信号量，另外 2 个用于释放信号量。每次循环主线程会等待所有子线程执行完毕。出现 bug 的问题就在于两个获取信号量的线程有一个会没办法被唤醒，队列就死掉了。通过前文介绍可以知道，在共享模式下，如果一个线程被挂起，在不考虑线程中断和前驱节点取消的情况（持有同步状态的线程节点在释放同步状态后会尝试唤醒其后继节点，如果后继节点取消了那么会跳过取消节点，找到一个最近的有效后继节点并唤醒它），还有两种唤醒挂起线程的情况：一种是持有同步状态的线程释放同步状态后通过调用 `unparkSuccessor` 来唤醒挂起的线程；另一种是其它线程节点再次获取同步状态后通过**传播机制**唤醒后继节点。

某一时刻我们假定同步队列中的节点排队情况如下图所示：
[![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4l8em0u0fj217o0dg0u8.jpg)

**接下来我们根据早期 JDK 中共享模式下释放同步状态源码流程简单走一遍：**

> - **时刻1：**t3 调用 `releaseShared`，释放同步状态（许可证由 0 变为 1）成功，此时 `h != null && h.waitStatus != 0` 条件成立，接着执行 `unparkSuccessor(h)` ，head 的 waitStatus 由 -1 变为 0 。
> - **时刻2：**t1 由于 t3 释放了同步状态被 t3 唤醒，t1 醒来后调用 `Semaphore.NonfairSync的tryAcquireShared` 获取同步状态（许可证），返回值为 0 （许可证由 1 减为 0）。
> - **时刻3：**t4 调用 `releaseShared`，释放同步状态（许可证由 0 变为 1）成功，但此时 t1 还没有占领头节点，头节点仍然是时刻1 的 head ，也就是 t3 占领的。由于 `h.waitStatus == 0` ，不满足条件，因此 t4 不会执行唤醒后继线程的 `unparkSuccessor(h)` 。**理论来说，t4 应该唤醒还挂在队列中的 t2，但是却没有**。
> - **时刻4：**t1 获取同步状态成功后，接着调用 `setHeadAndPropagate` 占领头节点，然后尝试传播唤醒，但由于不满足 propagate > 0（此时 propagate == 0，也就是时间2的结果），因此也不会传播唤醒后继节点。

最终的结果是，线程 t2 无法被唤醒，AQS 的同步队列死掉。

引入 `PROPAGATE` 后有两处地方调整。释放同步状态的 `releaseShared` 方法不再是简单粗暴地直接 `unparkSuccessor` ，而是将整个流程进行调整并抽成一个 `doReleaseShared` 方法，具体该方法见前文。该方法处理了并发释放同步状态的逻辑，虽然不能执行 unparkSuccessor ，但为了保证唤醒能够正确传递下去，设置读取到的 head 节点状态为 PROPAGATE。这样的话获取同步状态的线程在执行 `setHeadAndPropagate` 时可以读到 PROPAGATE，从而由获取同步状态的线程去释放后继等待节点；占领头节点并传播唤醒的 `setHeadAndPropagate` 方法增加了唤醒后继节点的条件，也就是我们的主角 `PROPAGATE` 状态，具体的方法见前文。

**下面我们再看引入 `PROPAGATE` 等待状态是如何规避上述问题的：**

> - **时刻1：**t3 调用 `releaseShared`，释放同步状态（许可证由 0 变为 1）成功，进入自旋逻辑将 head 的 waitStatus 由 -1 变为 0 ，接着执行 `unparkSuccessor(h)` 唤醒后继线程。
> - **时刻2：**t1 由于 t3 释放了同步状态被 t3 唤醒，t1 醒来后调用 `Semaphore.NonfairSync的tryAcquireShared` 获取同步状态（许可证），返回值为 0 （许可证由 1 减为 0）。
> - **时刻3：**t4 调用 `releaseShared`，释放同步状态（许可证由 0 变为 1）成功，进入自旋逻辑，此时 t1 还没有占领头节点，头节点仍然是时刻1 的 head ，也就是 t3 占领的。由于 `h.waitStatus == 0` ，于是 t4 将读取到的头节点 head 的 waitStatus 设置为 `PROPAGATE` (-3) 。
> - **时刻4：**t1 获取同步状态成功后，接着调用 `setHeadAndPropagate` 占领头节点，然后尝试传播唤醒，虽然不满足 propagate > 0（此时 propagate == 0，也就是时间2的结果），但是满足 `h.waitStatus < 0` 条件，因此会传播唤醒后继节点，也就是线程 t2。

#### 总结

上述会产生线程无法唤醒的 Bug 的案例在引入 `PROPAGATE` 等待状态后可以被规避掉。在引入 `PROPAGATE` 之前之所以会出现线程 hang 住的情况，就是在于 `releaseShared` 有竞争的情况。线程 t3 释放同步状态后会唤醒同步队列中等待的线程 t1 ，t1 醒来后获取到了同步状态但还来得及占领头节点 head ，此时线程 t4 又来释放同步状态，但是读到的还是 t3 占领的头节点 head ，由于此时 head 的等待状态为 0 ，因此导致不会执行后续的唤醒后继节点流程。最终后一个挂起的线程既没有被释放同步状态线程（t4）唤醒，也没有被持有同步状态的线程（t1）唤醒。

综上所述，在共享模式下仅仅依靠 `tryAcquireShared` 的返回值来决定是否要将唤醒传递下去是不充分的。

## 独占模式 VS 共享模式

### 获取同步状态

独占模式和共享模式获取同步状态的核心方法如下图所示：
[![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4l8ev0h3gj21ga0u0td5.jpg)

上述流程均按照线程获取同步状态失败入队等候，然后被唤醒。更完整的情况见前文。

### 释放同步状态

独占模式和共享模式释放同步状态的核心方法如下图所示：
[![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4l8f6bzw7j21g00u042d.jpg)

上述流程均按照线程释放同步状态然后唤醒后继线程节点，更完整的情况见前文。

## 公平与非公平

```java
+--- AbstractQueuedSynchronizer
    /**
     * 用于公平模式时判断同步队列中是否存在有效节点
     *
     * @return true - 说明队列中存在有效节点，当前线程必须加入同步队列中等待；false - 说明当前线程可以竞争同步状态
     */
    public final boolean hasQueuedPredecessors() {
        // The correctness of this depends on head being initialized
        // before tail and on head.next being accurate if the current
        // thread is first in queue.
        Node t = tail; // Read fields in reverse initialization order
        Node h = head;
        Node s;
        return h != t &&
                ((s = h.next) == null || s.thread != Thread.currentThread());
    }
```

AQS 支持公平与非公平模式，通过上述方法来判断是否公平。下面我们对判断条件进行说明：

> 1. 同步队列中的第一个节点是一个虚节点，不存储线程信息只是占位，一般对应获取同步状态的线程。真正的第一个有效节点是从第二开始的。
> 2. (s = h.next) == null 说明此时同步队列有线程在进行初始化，此时队列中有元素，因此需要返回 ture 。
> 3. (s = h.next) != null 说明同步队列中至少有一个有效节点，如果此时 s.thread == Thread.currentThread() 说明同步队列中的第一个有效节点（head的直接后继节点）中的线程和当前线程相同，那么当前线程是可以获取同步状态的。如果 s.thread != Thread.currentThread()，说明同步队列的第一个有效节点中的线程与当前线程不同，当前线程必须加入进等待队列。

# 应用场景

AQS 作为并发编程框架，在 JDK 的 JUC 中有很多的应用场景。下面列出 JUC 中几种常见的组件，后续会对这些组件源码进行分析。

| 同步组件               | 描述                                                         |
| ---------------------- | ------------------------------------------------------------ |
| ReentrantLock          | 使用 AQS 同步状态记录锁重复持有的次数。当一个线程获取锁时，会记录当前获得锁的线程标识，用于检测是否是重入，以及异常解锁判断 |
| ReentrantReadWriteLock | 使用 AQS 同步状态中的高 16 位保存写锁持有次数，低 16 位保存读锁持有次数 |
| Semaphore              | 使用 AQS 同步状态作为许可证，获取的时候会减少许可证，释放的时候会增加许可证，许可证 > 0 所有的 acquireShare 操作才可以通过 |
| CountDownLatch         | 使用 AQS 同步状态表示计数，计数为0时，所有的 acquireShare 操作（CountDownLatch的await方法）才可以通过 |
| ThreadPoolExecutor     | Worker 线程利用 AQS 同步状态实现对独占线程变量的设置，表明自己处于工作状态 |

# 自定义同步组件

分析完 AQS 的基本原理后，借助 AQS 框架就能轻松实现目标同步组件。具体套路如下：

- 定义一个继承 AQS 的静态内部类，该内部类对象才是真正发挥 AQS 能力关键
- 根据具体场景选择对应的模式，是独占还是共享，是公平还是非公平，然后选择实现不同的入口方法对
- 将 AQS 实现组合在自定义同步组件的实现中

```java
/**
 * 借助 AQS 实现锁功能，不支持重入
 */
public class Mutex {

    // 1 定义静态内部类 Sync 继承 AQS
    private static class Sync extends AbstractQueuedSynchronizer {

        // 2 实现 tryAcquire-tryRelease
        @Override
        protected boolean tryAcquire(int arg) {
            return compareAndSetState(0, 1);
        }
        @Override
        protected boolean tryRelease(int arg) {
            setState(0);
            return true;
        }

    }

    // 3 将 AQS 实现组合 Mutex 中
    private Sync sync = new Sync();
    public void lock() {
        sync.acquire(1);
    }
    public void unlock() {
        sync.release(1);
    }
}
```

# 小结

本篇文章对 `AbstractQueuedSynchronizer` 进行了详细说明。先从它的实现思路出发，从全局对 AQS 进行介绍。有了实现思路后，接下来从源码层面对 AQS 进行拆解分析，分为两个部分，一个是独占模式，另一个是共享模式。使用 AQS 框架，是有固定模式的，AQS 已经处理好了同步状态的获取与释放以及阻塞与唤醒，自定义组件只需继承 AQS 以及根据同步状态获取方式（独占/共享）实现模版方法即可。如果还想实现公平或非公平组件，只需在模版方法中增加相应的逻辑即可，AQS 也提供了该逻辑。AQS 准备好了一切，只需要条件触发就可以执行对应的任务，而实现的模版方法正是触发条件。