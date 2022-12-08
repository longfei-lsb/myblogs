# 线程池分析（5）｜AQS$Condition源码解析

[TOC]

# 概述

在 JUC 之前，Java 实现等待/通知模式是通过定义在 Object 中的一组监视器方法 `wait方法`、`notify()`以及 `notifyAll()` 与 `synchronized` 关键配合完成。在 JUC 中单独提供了一套等待/通知模式的实现方式，具体实现是 `Condition` 接口与 `Lock` 接口配合完成。

`Condition` 接口提供了类似 Object 的监视器方法，但该接口中定义的方法功能上更强大。比如，`Condition` 支持响应/不响应中断以及等待超时等接口。本篇文章是对 [AQS 原理分析](https://gentryhuang.com/posts/5144880e/) 的扩展，它是 AQS 中 ConditionObject 的相关实现。这样一来整个 AQS 就算完整了。

# 场景

生产者-消费者是 Condition 其中的一个经典使用场景，代码如下：

```java
import java.util.concurrent.locks.Condition;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

class BoundedBuffer {
    /**
     * 锁
     */
    final Lock lock = new ReentrantLock();
    /**
     * notFull Condition
     */
    final Condition notFull = lock.newCondition();
    /**
     * notEmpty Condition
     */
    final Condition notEmpty = lock.newCondition();
    /**
     * 数组，大小为 100
     */
    final Object[] items = new Object[100];
    /**
     * 分别为添加的下标、移除的下标和数组当前数量
     */
    int putptr, takeptr, count;
    /**
     * 生产
     * 如果数组满了，则添加线程进入等待状态，直到有空位才能生产
     *
     * @param x item
     * @throws InterruptedException
     */
    public void put(Object x) throws InterruptedException {
        lock.lock();
        try {
            // 元素数量等于数组长度，线程等待
            while (count == items.length)
                notFull.await();

            // 添加元素
            items[putptr] = x;
            // 添加下标 putptr 递增，和移除的下标 takeptr 对应。
            if (++putptr == items.length) putptr = 0;
            // 数组元素个数递增
            ++count;

            // 生产后通知消费
            notEmpty.signal();
        } finally {
            lock.unlock();
        }
    }

    /**
     * 消费
     * 如果数组为空，则消费线程进入等待状态，直到数组中有元素才能继续消费
     *
     * @return item
     * @throws InterruptedException
     */
    public Object take() throws InterruptedException {
        lock.lock();
        try {
            // 数组为空，线程等待
            while (count == 0)
                notEmpty.await();

            // 取出元素
            Object x = items[takeptr];
            // 移除下标递增
            if (++takeptr == items.length) takeptr = 0;
            // 数组元素个数递减
            --count;

            // 消费后通知生产
            notFull.signal();
            return x;
        } finally {
            lock.unlock();
        }
    }
}
```

**上述示例中，BoundedBuffer 实现了生产者-消费者模式，下面进行简单概述：**

1. 使用 Condition 时先获取相应的 Lock 锁，和 Object 类中的方法类似，需要先获取某个对象的监视器锁才能执行等待、通知方法。
2. 生产和消费方法中判断数组状态使用的是 while 自旋而非 if 判断，目的是防止过早或意外的通知，当且仅当条件满足才能从 await() 返回。

# 实现原理

Condition 结合 Lock 实现的等待通知机制包括两部分内容即等待和通知，分别依赖单向链表和双向链表。Condition 接口的实现类是 AQS 内部类 ConditionObject，它内部维护的队列称为条件队列，基于单向链表实现。Lock 是基于 AQS 实现的，它内部维护的队列称为同步队列，基于双向链表实现。Condition 对象是由 Lock 对象创建出来的，并且一个 Lock 对象可以创建多个 Condition 对象，每个 Condition 对象共享 Lock 这个外部资源。

获取到同步状态（锁）的线程调用 `await` 方法进行等待时，会先将自己打包成一个节点并加入到对应的条件队列中，加入成功后会**完全释放同步状态**，释放同步状态成功后会在该条件队列的尾部等待，于此同时该线程在同步队列中的节点也会被移除「释放同步状态成功后，唤醒后置节点，退出占领的头节点」。在某个 Condition 上（条件队列）等待的线程节点被`signal` 或 `signalAll` 后，对应的线程节点会被转到外部类的同步队列中，这意味着该节点有了竞争同步状态的机会，线程需要获取到同步状态才能继续后续的逻辑。需要说明的是，一个锁对象可以同时创建 N 个 Condition 对象（对应 N 个条件队列），这表明获取到同步状态的线程可以有选择地加入条件队列并在该队列中等待，其它获取到同步状态的线程可以有选择地唤醒某个条件队列中的等待的线程。但不管有多少个条件队列，竞争同步状态的线程节点需要统一转到外部类的同步队列中，也就是 Lock 维护的双向链表，此后就是竞争同步状态的逻辑了。

下图简单描述了 Condition 的工作原理：

[![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4l8mujdu5j20w20klwgp.jpg)

以上就是 Condition 实现的等待-通知机制。需要说明的是，上述描述没有涉及过多的细节，如异常流的处理。接下来我们通过对代码层面的解析来全面了解 Condition 的机制。

# 源码解析

## Condition

[![img](https://tva1.sinaimg.cn/large/e6c9d24ely1h4l8mzl3r1j20v809sgm9.jpg)

Condition 接口中定义的方法和 Object 中的监视器方法类似，区别在于前者支持响应中断和超时等待。下面对该接口中定义的方法进行简单说明：

1. void await() throws InterruptedException 方法

   > 响应中断的等待方法，线程进入条件队列挂起，直到被通知或中断。

2. void awaitUninterruptibly() 方法

   > 不响应中断的等待方法，不会抛出中断异常，仅仅复位中断标志，线程进入条件队列挂起，直到被通知或中断。

3. long awaitNanos(long nanosTimeout) throws InterruptedException 方法

   > 在 await() 基础上增加了超时功能，线程进入条件队列挂起直到被通知、中断或超时，如果在 nanosTimeout 内返回，那么返回值就是 nanosTimeout - 实际耗时，如果返回值是 0 或者负数，表示超时了。

4. boolean awaitUntil(Date deadline) throws InterruptedException 方法

   > 在 await() 基础上增加了超时功能，线程进入条件队列挂起直到被通知、中断或者到某个时间。如果没有到指定时间就通知，返回 true，否则表示超时。

5. boolean await(long time, TimeUnit unit) throws InterruptedException 方法

   > 和 awaitUntil(Date deadline) 方法几乎一致，前者是绝对时间，后者是时间粒度。

6. void signal() 方法

   > 将条件队列中的头节点转到同步队列中，以等待竞争同步状态。

7. void signalAll() 方法

   > 将条件队列中的所有节点依次转到同步队列中，以等待竞争同步状态。此时条件队列进入下一个周期。

在 JUC 中 Condition 主要基于 `ReentrantLock` 和 `ReentrantReadWriteLock` 实现的，在语义中就是我们说的锁概念，而锁又是基于 AQS 实现的。总的来说，Condition 依赖 Lock，Lock 实现是基于 AQS 的。下面以 `ReentrantLock` 作为 Condition 的实现进行说明。

## ConditionObject

`ConditionObject`实现了 Condition 接口，同时作为`AbstractQueuedSynchronizer`的内部类，因为 Condition 的操作需要获取到同步状态，因此其实现类作为`AbstractQueuedSynchronizer`的内部类是比较合理的，这意味着`ConditionObject`可以访问外部资源。

```java
+--- AbstractQueuedSynchronizer
   public class ConditionObject implements Condition, java.io.Serializable {
        private static final long serialVersionUID = 1173984872572414699L;
        /**
         * 条件队列 - 头节点
         */
        private transient Node firstWaiter;
        /**
         * 条件队列 - 尾节点
         */
        private transient Node lastWaiter;
        /**
         * Creates a new {@code ConditionObject} instance.
         */
        public ConditionObject() {
        }

     // ${省略其它代码}
}
```

**每个 ConditionObject 对象内部维护了一个基于单向链表的条件队列**，该队列是 Condition 实现等待-通知机制的关键。既然是链表，其中的节点定义是什么呢？ConditionObject 没有重新定义链表节点，而是直接使用外部类 AbstractQueuedSynchronizer 定义的 Node ，这也是合理的。下面我们简单看下该 Node 的定义。

```java
+--- AbstractQueuedSynchronizer
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
         * 等待状态 - 取消（线程已经取消）
         */
        static final int CANCELLED = 1;
        /**
         * 等待状态 - 通知（后继线程需要被唤醒）
         */
        static final int SIGNAL = -1;
        /**
         * 等待状态 - 条件等待（线程在 Condition 上等待）
         */
        static final int CONDITION = -2;
        /**
         * 等待状态 - 传播（无条件向后传播唤醒动作）
         */
        static final int PROPAGATE = -3;
        /**
         * 等待状态，初始值为 0
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
         * 条件队列中使用，后置节点
         */
        Node nextWaiter;
 }
```

同步队列和条件队列共同使用上述的 **Node** 节点构建队列，区别在于前者底层数据结构是双向链表，节点的维护使用 **prev** 和 **next** 属性，后者底层数据结构是单向链表，节点维护使用 **nextWaiter** 属性，两者中的节点等待状态都是使用 **waitStatus** 属性。

`ReentrantLock` 对象和 `ReentrantReadWriteLock` 对象可以创建多个 ConditionObject 对象，代码如下：

```java
final ConditionObject newCondition() {
            return new ConditionObject();
        }
```

**下面对 `ReentrantLock` 和 `ConditionObject` 的关联关系进行说明：**

1. ConditionObject 维护的条件队列和 ReentrantLock 维护的同步队列的节点都是 Node 的实例，条件队列的线程节点需要移动到同步队列中以参与竞争同步状态。
2. ReentrantLock 对象与 ConditionObject 对象的比例关系为： 1 : N ，每个 ConditionObject 都能直接访问 ReentrantLock 这个外部类资源。
3. 一个同步队列对应 N 个条件队列，同步队列中的线程（获取到同步状态）可以选择性地进入不同的条件队列进行等待，而多个条件队列中的线程节点要参与竞争同步状态就需要进入同一个同步队列。

接下来对等待和通知的核心代码进行分析，根据主要流程分别说明。

## 等待

`ConditionObject` 中实现了几种不同功能的等待方法，在介绍 `Condition` 接口时已经详细说明，下面先对 `await()` 的方法实现进行分析。

当获取同步状态的线程调用 `await()` 方法时，相当于同步队列的头节点中的线程（获取了同步状态的节点）进入到 Condition 的条件队列中，完全释放同步状态后同步队列将会移除该线程对应的节点。需要说明的是，下图中的第 2 步中释放同步状态失败的情况是针对没有获取到同步状态就执行 `await` 方法的情况，获取到同步状态的线程在释放状态的时候一般是不会出释放同步状态失败的情况。值得一提的是，同步队列中的头节点就是供持有同步状态的线程占领，进而唤醒后继等待线程。

[![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4l8nm01bhj20ph0dw75g.jpg)

```java
+--- ConditionObject
    public final void await() throws InterruptedException {
        // 响应中断
        if (Thread.interrupted())
            throw new InterruptedException();

        //1. 将当前线程封装到节点中，并将节点加入到条件队列尾部
        Node node = addConditionWaiter();

        //2. 保存并完全释放同步状态，注意是完全释放，因为允许可重入锁。如果没有持锁会抛出异常，也就是释放同步状态失败
        int savedState = fullyRelease(node);
        // 记录中断模式
        int interruptMode = 0;

        /**
         *3. 判断上述加入到条件队列的线程节点是否被移动到了同步队列中，不在则挂起线程（曾经获取到锁的线程）。
         *
         * 循环结束的条件：
         * 1. 其它线程调用 signal/signalAll 方法，将当前线程节点移动到同步队列中，节点对应的线程将会在竞争同步状态的过程被前驱节点唤醒。
         * 2. 其它线程中断了当前线程，当前线程会自行尝试进入同步队列中。
         */
        while (!isOnSyncQueue(node)) {
            // 挂起线程，直到被唤醒或被中断
            LockSupport.park(this);

            /**
             * 检测中断模式：
             * 在线程从 park 中返回时，需要判断是被唤醒返回还是被中断返回。
             * 1). 如果线程没有被中断，则返回 0，此时需要重试循环继续判断当前线程节点是否在同步队列中「有假唤醒的可能性」。
             * 2). 如果线程被中断
             *   - 中断发生在被唤醒之前，当前线程（线程节点）会尝试自行进入同步队列并返回 THROW_IE，后续需要抛出中断异常。todo
             *   - 中断发生在被唤醒之后，即当前线程（线程节点）尝试自行进入同步队列失败（说明其它线程调用过了 signal/signalAll 唤醒线程并尝试将线程节点转到同步队列），
             *     返回 REINTERRUPT ，后续需要重新中断线程，向后传递中断标志。
             */
            if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
                break;
        }

        //4. 醒来后，被移动到同步队列的节点 node 重新尝试获取同步状态成功，且获取同步状态的过程中如果被中断，接着判断中断模式非 THROW_IE 的情况会更新为 REINTERRUPT
        if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
            interruptMode = REINTERRUPT;

        //5. 清理取消节点。正常情况下 signal/signalAll 将节点转到同步队列的同时会将节点的 nextWaiter 置空，这里主要对自行进入到同步队列中的节点进行处理。
        // 1） 中断模式为 THROW_IE 的情况下 nextWaiter 不会被置空，且等待状态为 0 ，这种情况下节点应该从条件队列中移除。
        // 2） fullyRelease 方法出现异常，nextWaiter 不会被置空，且等待状态为 CANCELLED，清理任务会由后继的节点完成。
        if (node.nextWaiter != null) // clean up if cancelled
            // 清理条件队列中取消的节点（重组链表）
            unlinkCancelledWaiters();

        //6. 如果线程发生过中断则根据 THROW_IE 或 REINTERRUPT 分别抛出异常或者重新中断。 todo 最终都要抛出异常还获取个球球的锁
        if (interruptMode != 0)
            reportInterruptAfterWait(interruptMode);
    }
```

**下面对上述整个等待流程进行概述：**

1. 将获取到同步状态的线程封装到节点中并加入到条件队列。
2. 完全释放同步状态，并记录获取到的同步状态，为后面重新竞争同步状态做准备。
3. 在条件队列中等待被唤醒，或者被中断。
4. 再次竞争挂起等待前驱节点的同步状态。
5. 对中断情况的处理，抛出异常或重新中断线程以复位中断标志。

以上对整个等待流程进行了总体描述，需要注意的是，**当线程从`await()`方法返回时，当前线程一定获取了`Condition`相关联的锁**。下面对其中的分支流进行说明。

### addConditionWaiter

将当前线程封装到节点中，然后加入到当前 Condition 对象维护的条件队列的尾部。

```java
+--- ConditionObject
private Node addConditionWaiter() {
    // 条件队列尾节点
    Node t = lastWaiter;

    // 选出条件队列中有效尾节点。这里主要处理 fullyRelease 方法出现异常的情况。
    if (t != null && t.waitStatus != Node.CONDITION) {
        // 如果需要，清理条件队列中取消的节点（重组链表）
        unlinkCancelledWaiters();
        // 重读尾节点，可能为 null
        t = lastWaiter;
    }

    // 创建节点封装当前线程，节点状态为 CONDITION
    Node node = new Node(Thread.currentThread(), Node.CONDITION);

    // 初始化条件队列，firstWaiter 更新为当前节点
    if (t == null)
        firstWaiter = node;

        // 将当前节点加入到条件队列尾
    else
        t.nextWaiter = node;

    // 更新条件队列尾指针指向
    lastWaiter = node;
    // 返回当前线程关联的节点
    return node;
}
```

**特别说明：**

addConditionWaiter() 方法不一定是线程安全的，没有获取到锁就调用 **await** 方法就是不安全操作。虽然没有获取到锁的线程执行 **await** 方法最终会抛出异常，遗留在条件队列的节点也会被后继节点清理，但是如果持锁和不持锁的两个线程同时调用 **await** 方法就可能会产生并发问题，使 ConditionObject 维护的条件队列中节点产生覆盖，这是一种破坏行为，最终会导致有些成功调用 await 方法的线程可能永远没有办法被唤醒(非正常唤醒除外，如中断)，更没有机会再次获取锁，因为条件队列中并没有记录它们，记录的是非法调用的线程节点。

上述过程涉及到清理无效节点的逻辑，该逻辑由 `unlinkCancelledWaiters()` 方法完成，下面我们来分析该方法。

### unlinkCancelledWaiters

```java
+--- ConditionObject
 private void unlinkCancelledWaiters() {
            // 从首节点开始进行节点检测
            Node t = firstWaiter;

            // 记录上一个非取消状态节点，参照节点是当前遍历节点
            Node trail = null;

            // 遍历链表
            while (t != null) {
                // 保存当前节点的下一个节点，在当前节点处于取消状态时进行替换
                Node next = t.nextWaiter;

                // 如果节点的等待状态不是 CONDITION，表明这个节点被取消了。
                if (t.waitStatus != Node.CONDITION) {
                    // 取消状态的节点要断开和链表的关联
                    t.nextWaiter = null;

                    /**
                     * 重组链表，保证链条为空或者所有节点都是非取消状态
                     *
                     * trail == null，表明 next 之前的节点的等待状态均为取消状态，此时更新 firstWaiter 引用指向
                     * trail != null，表明 next 之前有节点的等待状态为 CONDITION ，此时只需 trail.nextWaiter 指向 next 节点
                     * 注意：
                     * 1 firstWaiter 一定指向链表第一个非取消节点，或者为 null
                     * 2 trail 第一次赋值的话一定和 firstWaiter 一样的值
                     * 3 firstWaiter 一旦被赋予非 null 的值后就不会再变动，后续的节点连接就看 trail 的表演：
                     *   - 如果当前节点是取消节点，就 trail.nextWaiter 指向 next 节点
                     *   - 如果当前节点是非取消节点，trail 跟着节点走
                     */
                    if (trail == null)
                        firstWaiter = next;
                    else
                        trail.nextWaiter = next;

                    // 当前节点没有后继则遍历结束，此时当前节点是无效节点，因此将 lastWaiter 回退即更新为上一个非取消节点
                    if (next == null)
                        lastWaiter = trail;

                    // 当前节点处于等待状态
                } else
                    trail = t;

                // 下一个节点
                t = next;
            }
        }
```

unlinkCancelledWaiters() 方法用于清理取消节点，重新构造链表，主要处理因中断自行加入同步队列和释放同步状态异常的情况。**取消节点的定义是线程节点挂起时被中断或释放同步状态失败。针对这两种情况，signal()/signalAll() 无法转移节点。**

线程节点加入到条件队列后就可以执行完全释放同步状态操作，下面我们看具体的逻辑。

### fullyRelease

```java
+--- AbstractQueuedSynchronizer
    final int fullyRelease(Node node) {
        boolean failed = true;
        try {

            // 获取同步状态（拿到同步状态的线程）
            int savedState = getState();

            // 释放指定数量的同步状态
            // java.util.concurrent.locks.ReentrantLock.Sync.tryRelease ，没有持有锁会抛出异常
            if (release(savedState)) {
                failed = false;
                // 返回同步状态，释放之前的值
                return savedState;
            } else {
                throw new IllegalMonitorStateException();
            }
        } finally {
            // 释放同步状态失败，需要将节点状态设置为取消状态，后续会被清理
            if (failed)
                node.waitStatus = Node.CANCELLED;
        }
    }
```

该方法用于完全释放同步状态，属于 `AbstractQueuedSynchronizer` 中定义的方法，上文也提到 `ConditionObject` 是 `AbstractQueuedSynchronizer` 的内部类，因此可以共享外部资源。注意，该方法是完全释放同步状态，一般情况下为了避免死锁的产生，锁的实现上一般支持重入功能。

需要特别说明的是，如果线程没有获取到同步状态就执行 `await()` 方法，该线程关联的节点能进入到条件队列中，但是进入条件队列后需要调用 `fullyRelease` 方法执行同步状态释放逻辑，由于没有获取到同步状态在执行到 `ReentrantLock.tryRelease` 方法时会抛出异常，进而 finally 块中将节点状态进行更新 `node.waitStatus = Node.CANCELLED` ，这个已经入队到条件队列的节点会被**后续节点**清理出去，也即执行 `unlinkCancelledWaiters` 方法。

释放持有的同步状态后会进入自旋等待逻辑，该过程会对通知和中断进行不同的处理。

### 等待转入同步队列

```java
+--- ConditionObject
   while (!isOnSyncQueue(node)) {

        // 挂起线程，直到被唤醒或被中断
        LockSupport.park(this);

        /**
         * 检测中断模式：
         * 在线程从 park 中返回时，需要判断是被唤醒返回还是被中断返回。
         * 1. 如果线程没有被中断，则返回 0，此时需要重试循环继续判断当前线程节点是否在同步队列中。
         * 2. 如果线程被中断
         *   - 中断发生在被唤醒之前，当前线程（线程节点）会尝试自行进入同步队列并返回 THROW_IE，后续需要抛出中断异常。
         *   - 中断发生在被唤醒之后，即当前线程（线程节点）尝试自行进入同步队列失败（说明其它线程调用过了 signal/signalAll 唤醒线程并尝试将线程节点转到同步队列），
         *     返回 REINTERRUPT ，后续需要重新中断线程，向后传递中断标志，由后续代码去处理中断。
         *
         */
          if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
               break;
     }
```

以上自旋等待逻辑主要包括两部分工作，检查节点是否在同步队列中和处理中断。下面我们分别来看这两个逻辑。

### isOnSyncQueue

检查节点是否已经转到同步队列中。

```java
+--- AbstractQueuedSynchronizer
   final boolean isOnSyncQueue(Node node) {

        /**
         * 1 同步队列中的节点状态可能为 0、SIGNAL = -1、PROPAGATE = -3、CANCELLED = 1，但不会是 CONDITION = -2
         * 2 node.prev 仅会在节点获取同步状态后，调用 setHead 方法将自己设为头结点时被设置为 null，所以只要节点在同步队列中，node.prev 一定不会为 null
         */
        if (node.waitStatus == Node.CONDITION || node.prev == null)
            return false;

        /**
         * 1 条件队列中节点是使用 nextWaiter 指向后继节点，next 均为 null 。同步队列中节点是使用 next 指向后继节点。
         * 2 node.next != null 代表当前节点 node 一定在同步队列中。
         */
        if (node.next != null) // If has successor, it must be on queue
            return true;

        /**
         * node.next == null 也不能说明节点 node 一定不在同步队列中，因为同步队列入队方法不是同步的而是自旋方式，
         * 是先设置 node.prev，后设置 node.next，CAS 失败时 node 可能已经在同步队列上了，所以这里还需要进一步查找。
         */
        return findNodeFromTail(node);
    }

    /**
     * 从同步队列尾部开始搜索，查找是否存在 node 节点。
     * 为什么不从头开始搜索？因为节点的 next 可能会为 null
     *
     * @return true if present
     */
    private boolean findNodeFromTail(Node node) {
        Node t = tail;
        for (; ; ) {
            if (t == node)
                return true;
            if (t == null)
                return false;
            t = t.prev;
        }
    }
```

### checkInterruptWhileWaiting

检查在线程挂起期间是否发生中断，若发生中断则需要进行特殊处理，即尝试自行进入同步队列中。

```java
+--- ConditionObject
 private int checkInterruptWhileWaiting(Node node) {
     return Thread.interrupted() ?
                 (transferAfterCancelledWait(node) ? THROW_IE : REINTERRUPT) :
                 0;
        }
```

**方法逻辑如下：**

> 1. 线程未被中断，则返回 0
> 2. 线程被中断且自行入同步队列成功，则返回 THROW_IE，这种情况下后续需要抛出中断异常
> 3. 线程被中断且未能自行入同步队列（其它线程已经执行 signal/signalAll 方法，节点状态已被更改），则返回 REINTERRUPT ，这种情况下后续需要重新中断线程以恢复中断标志

### transferAfterCancelledWait

取消等待（中断）后的转移节点操作，即线程被中断优先尝试自行加入同步队列，如果在中断之前已经执行过加入操作就等待加入同步队列完成。

[![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4l8ofu6qqj20vk0ej0ub.jpg)**注意：**

1. **由于中断尝试自行加入同步队列的线程节点并没有与条件队列断开连接，该节点会在后续的逻辑中进行清除。**
2. **即使发生了中断，节点依然会转到到同步队列中。**

```java
+--- ConditionObject
   final boolean transferAfterCancelledWait(Node node) {
     // 中断如果发生在 节点被转到同步队列前，应该尝试自行将节点转到同步队列中，并返回 true
      if (compareAndSetWaitStatus(node, Node.CONDITION, 0)) {
           // 将节点转到同步队列中
           enq(node);
           return true;
         }
          
        /**
         * 1. 如果上面的CAS失败，则表明已经有线程调用 signal/signalAll 方法更新过节点状态（CONDITION -> 0 ），并调用 enq 方法尝试将节点转到同步队列中。
         * 2. 这里使用 while 进行判断节点是否已经在同步队列上的原因是，signal/signalAll 方法可能仅设置了等待状态，还没有完成将线程节点转到同步队列中，所以这里用自旋的
         * 方式等待线程节点加入到同步队列，否则会影响后续重新获取同步状态（调用 acquireQueued() 方法，该方法需要线程节点入同步队列才能调用，否则会抛出np异常）。这种情况表明了中断发生在节点被转移到同步队列期间。
         */
        while (!isOnSyncQueue(node))
           // 让出 CPU
           Thread.yield();

          // 中断在节点被转到同步队列期间或之后发生，返回 false
          return false;
      }
```

**判断中断发生的时机：**

> 1. 中断在节点被转到同步队列前发生，此时返回 true
> 2. 中断在节点被转到同步队列过程或之后发生，此时返回 false

## 通知

在解析通知源码之前我们先回到线程挂起等待源码处，如下：

```java
+--- ConditionObject
   while (!isOnSyncQueue(node)) {
        // 挂起线程，直到被唤醒或被中断
        LockSupport.park(this);
       
       // 有中断情况，进进行处理
       if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
             break;
     }
```

线程释放同步状态成功后会挂起等待其它线程唤醒自己（同步队列中的线程节点），或者被其它线程中断。关于线程挂起等待时被中断的处理逻辑前文已经解析，主要是确保被中断的线程也能加入到同步队列中。下图对通知流程进行了简单地描述。

[![img](https://tva1.sinaimg.cn/large/e6c9d24egy1h4l8oq6e53j20sb0exdgx.jpg)

**下面对通知流程进行说明：**

1. 将条件队列中头节点转到同步队列中。
2. 根据情况决定是否唤醒对应的线程，不唤醒则在同步队列中等待，唤醒则准备竞争同步状态。

下面我们解析正常通知逻辑。

### 通知单个节点

```java
+--- ConditionObject
    /**
     * 将条件队列中的头节点转到同步队列中
     */
    public final void signal() {
        // 检查线程是否获取了独占锁，未获取独占锁调用 signal 方法是不合法的
         if (!isHeldExclusively())
            throw new IllegalMonitorStateException();

         // 条件队列的头节点
         Node first = firstWaiter;

         // 将条件队列的头节点转到同步队列中
         if (first != null)
            doSignal(first);
     }

    private void doSignal(Node first) {
       do {
           // 因为条件队列的 firstWaiter 要出队转到同步队列中，因此使用 firstWaiter 后继节点占领 firstWaiter。
            if ((firstWaiter = first.nextWaiter) == null)
              // 只有一个节点的话，尾节点指向设置为 null
              lastWaiter = null;

              // 断开 first 与条件队列的连接
              first.nextWaiter = null;

            // 调用 transferForSignal 方法将节点移到同步队列中，如果转到同步队列失败，则对后面的节点进行操作，依次类推
            } while (!transferForSignal(first) && (first = firstWaiter) != null);
        }
```

### 通知所有节点

```java
+--- ConditionObject
 public final void signalAll() {
   // 检查线程是否获取了独占锁，未获取独占锁调用 signalAll 方法是不合法的
   if (!isHeldExclusively())
       throw new IllegalMonitorStateException();

     // 条件队列的头节点
     Node first = firstWaiter;

     if (first != null)
          doSignalAll(first);
   }

 private void doSignalAll(Node first) {
     // 置空条件队列的头、尾指针，因为当前队列元素要全部出队，避免将新入队的节点误唤醒
     lastWaiter = firstWaiter = null;

     // 将条件队列中所有的节点都转到同步队列中。
      do {
         
          Node next = first.nextWaiter;      
          // 将节点从条件队列中移除
          first.nextWaiter = null;
          // 将节点转到同步队列中
          transferForSignal(first);
             
          first = next;
         } while (first != null);
     }
```

### 加入同步队列

```java
 final boolean transferForSignal(Node node) {
    /**
     * 如果更新节点的等待状态由 CONDITION 到 0 失败，则说明该节点已经被取消（如被中断），也就不需要再转到同步队列中了。
     * 由于整个 signal /signalAll 都需要拿到锁才能执行，因此这里不存在线程竞争的问题。
     */
    if (!compareAndSetWaitStatus(node, Node.CONDITION, 0))
        return false;

    // 调用 enq 方法将 node 加入到同步队列中尾，并返回 node 的前驱节点
    Node p = enq(node);

    // 获取前驱节点的等待状态
    int ws = p.waitStatus;

    /**
     * 1 如果前驱节点的等待状态 ws > 0，说明前驱节点已经被取消了，此时应该唤醒 node 对应的线程去尝试获取同步状态，准确的应该是先找大哥，找大哥过程会剔除它的无效前驱节点。
     *    注意，这里只是入队并没有执行剔除取消节点的逻辑，虽然AQS唤醒操作支持从尾节点向前寻找最前的有效节点并唤醒，但还是应该主动唤醒 node 对应的线程，以更新大哥节点。
     * 2 如果前驱节点的等待状态 ws <= 0 ，通过 CAS 操作将 node 的前驱节点 p 的等待状态设置为 SIGNAL，当节点 p 释放同步状态后会唤醒它的后继节点 node。
     *   如果 CAS 设置失败（可能节点 p 在此期间被取消了），则应该立即唤醒 node 节点对应的线程，原因和 1 一致。
     */
    if (ws > 0 || !compareAndSetWaitStatus(p, ws, Node.SIGNAL))
        LockSupport.unpark(node.thread);

    return true;
}
```

**加入同步队列主要逻辑如下：**

1. 由于执行 signal/signalAll 方法需要持有同步状态，因此 transferForSignal 方法是不存在并发问题的。
2. 对条件队列中的非 CONDITION 状态的节点不执行转入同步队列操作。
3. 将符合条件的节点加入到同步队列中，并返回前驱节点。
4. 正常情况下不会执行 `LockSupport.unpark(node.thread)` 唤醒线程，而是节点进入同步队列然后方法返回 true，transferForSignal 方法结束。唤醒的动作发生在释放锁的时，非全部唤醒的情况，可能还会唤醒不到。
5. 同步队列中 node 的前驱节点取消等待，或者 CAS 等待状态失败，需要唤醒线程，这个属于异常流。

注意，执行 `signal` 或 `signalAll` 方法仅仅让线程节点具备竞争同步状态的机会，确切地说是将条件队列的节点移动到同步队列中，仅此而已。至于能不能获取到同步状态需要看具体竞争结果，要知道不仅条件队列中线程节点阻塞等待，同步队列中可能也有大量的线程节点在等待唤醒，况且条件队列中的线程节点需要移动到同步队列中才有资格参与同步状态的竞争。

通过下面的伪代码可以推演出多种可能情况：

```java
// 默认使用的是非公平锁，意味着即使同步队列中有等待唤醒的节点，锁还是有可能被其它线程获取。
ReentrantLock lock = new ReentrantLock();
Condition condition = lock.newCondition();

public void await() throws InterruptedException {
    lock.lock();
    try {
        // business
        condition.await();
    } finally {
        lock.unlock();
    }
}

public void signal() {
    lock.lock();
    try {
        // business
        condition.signal();
    } finally {
        lock.unlock();
    }
}
```

## 从等待中醒来

线程节点移动到同步队列后被唤醒，线程从等待中醒来，继续从 `LockSupport.park(this)` 向后执行。

```java
+--- ConditionObject
   while (!isOnSyncQueue(node)) {
        // 挂起线程，直到被唤醒或被中断
        LockSupport.park(this);
        // 检测中断模式
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
             break;
     }
```

### 检查中断模式

线程从挂起返回后会检查中断状态，检查中断逻辑前文已经说明，这里不再重复介绍。

以下情况会使 `LockSupport.park(this)` 返回：

1. 线程节点被同步队列中其它节点唤醒，不仅仅是它的前驱节点，还可能是头节点（头节点线程进行 signal 时，线程节点的前驱节点取消了或更新前驱节点状态失败）。
2. 线程在挂起时被中断。
3. 虚假唤醒，和 Object.wait() 存在同样的问题，一般使用自旋避免。

### 竞争同步状态

线程节点转入同步队列后，就可以尝试竞争同步状态了，注意预获取同步状态是之前释放锁前的值，代码如下：

```java
//醒来后，被移动到同步队列的节点 node 重新尝试获取同步状态成功，且获取同步状态的过程中如果被中断，接着判断中断模式非 THROW_IE 的情况会更新为 REINTERRUPT
if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
    interruptMode = REINTERRUPT;
```

这里回到了竞争同步状态的逻辑，获取到同步状态则继续向后执行，也意味着可以从 **await** 方法返回，没能获取到同步状态则继续在同步队列中等待。

### 处理中断

```java
private void reportInterruptAfterWait(int interruptMode)throws InterruptedException {
  if (interruptMode == THROW_IE)
     throw new InterruptedException();
   else if (interruptMode == REINTERRUPT)
     // 中断线程，复位中断标志
     selfInterrupt();
  }
```

await() 方法返回之前会对中断进行处理，因为它支持响应中断，关于中断模式前文已经说明，会对被中断的线程进行特殊处理，保证被中断的线程也要转到同步队列中。

## 超时等待

这里以超时时间粒度的等待方法为例简单介绍超时等待。

```java
public final long awaitNanos(long nanosTimeout) throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    // 加入条件队列
    Node node = addConditionWaiter();
    // 完全释放同步状态
    int savedState = fullyRelease(node);
    // 过期时间
    final long deadline = System.nanoTime() + nanosTimeout;
    // 中断模式
    int interruptMode = 0;

    // 超时的话，自行转入到同步队列
    while (!isOnSyncQueue(node)) {
        // 超时时间到，跳出自旋等待
        if (nanosTimeout <= 0L) {
            transferAfterCancelledWait(node);
            break;
        }

        // 自旋还是挂起
        if (nanosTimeout >= spinForTimeoutThreshold)
            LockSupport.parkNanos(this, nanosTimeout);

        // 检查中断模式
        if ((interruptMode = checkInterruptWhileWaiting(node)) != 0)
            break;

        // 计算超时时间
        nanosTimeout = deadline - System.nanoTime();
    }
    
    // 竞争同步状态
    if (acquireQueued(node, savedState) && interruptMode != THROW_IE)
        interruptMode = REINTERRUPT;

    if (node.nextWaiter != null)
        unlinkCancelledWaiters();

    if (interruptMode != 0)
        reportInterruptAfterWait(interruptMode);
    
    return deadline - System.nanoTime();
}
```

超时等待是在 `await()` 方法的基础上增加了等待的超时时间，如果超过超时时间则不再等待其它线程唤醒，自行加入到同步队列中并退出自旋等待，然后尝试竞争同步状态。

## 忽略中断

```java
public final void awaitUninterruptibly() {
    // 加入条件队列
    Node node = addConditionWaiter();
    // 完全释放同步状态
    int savedState = fullyRelease(node);
    // 中断模式
    boolean interrupted = false;

    // 自旋等待
    while (!isOnSyncQueue(node)) {
        LockSupport.park(this);
        if (Thread.interrupted())
            interrupted = true;
    }

    // 竞争同步状态
    if (acquireQueued(node, savedState) || interrupted)
        // 发生中断需要复位中断标志
        selfInterrupt();
}
```

该方法和 `await()` 方法最大的区别是对中断不做特别处理，如果有中断发生复位中断标志即可，不会抛出中断异常。

# 其它

## 和对象监视器的联系

1. Condition 定义的方法和对象监视器方法类似。
2. 对象监视器方法需要和 `synchronized` 关键字一起使用，且必须先拿到锁才能执行监视器方法。Condition 对象需要和 Lock 对象绑定，同样需要先获取到锁才能执行 Condition 的方法。

## 和对象监视器的区别

1. Condition 接口中定义的方法功能更加完善，如忽略中断、等待超时。
2. Condition 是代码层面上的实现，对象监视器是JVM指令层面上的实现。
3. Condition 与 Lock 结合拥有一个同步队列和多个条件队列，而对象监视器模型上有一个同步队列和一个条件队列。
4. Condition 支持唤醒特定线程，对象监视器方法唤醒线程是随机的。

> - **本文链接：** https://gentryhuang.com/posts/40e44c1f/
> - **版权声明：** 本博客所有文章除特别声明外，均采用 [CC BY 4.0 CN协议](http://creativecommons.org/licenses/by/4.0/deed.zh) 许可协议。转载请注明出处！