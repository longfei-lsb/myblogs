# 线程池分析（1）｜FutureTask源码解析

[TOC]

## 源码解析

维护了一个`state`状态值，并有如下状态值

```java
private static final int NEW          = 0;// 未开始，新任务
private static final int COMPLETING   = 1;// 正在完成（用户处理已完成，正在进行结果的属性赋值）
private static final int NORMAL       = 2;// 已完成，正常返回结果
private static final int EXCEPTIONAL  = 3;// 已完成，异常返回结果
private static final int CANCELLED    = 4;// 已完成，任务已取消
private static final int INTERRUPTING = 5;// 已完成，任务正在中断
private static final int INTERRUPTED  = 6;// 已完成，任务已中断
```



有如下属性

```java
// 正在执行该Future任务的线程，要知道一个任务可以被多个线程执行，所以执行该任务完毕后，也要清空到任务的初始化阶段
private volatile Thread runner;
// 等待节点（单链表形式，存有调用该任务get()方法后，所有的等待线程）
private volatile WaitNode waiters;
// callable（用户真正允许有返回值的业务逻辑内容）
private Callable<V> callable;
```

有如下方法

> public boolean cancel(boolean mayInterruptIfRunning)

```java
// 参数：是否应该中断的方式取消任务
public boolean cancel(boolean mayInterruptIfRunning) {
  // 如果不是崭新任务状态，或者任务状态值修改为正在中断或取消不可成功，则返回取消失败
        if (!(state == NEW &&
              UNSAFE.compareAndSwapInt(this, stateOffset, NEW,
                  mayInterruptIfRunning ? INTERRUPTING : CANCELLED)))
            return false;
        try {  
          // 如果需要中断任务执行，就直接中断线程，完成后直接修改状态为：已中断
            if (mayInterruptIfRunning) {
                try {
                    Thread t = runner;
                    if (t != null)
                        t.interrupt();
                } finally { // final state
                    UNSAFE.putOrderedInt(this, stateOffset, INTERRUPTED);
                }
            }
        } finally {
          // 最终完成处理
            finishCompletion();
        }
        return true;
    }
```

> private void finishCompletion()

这里你可以学到如何遍历单链表

```java
private void finishCompletion() {
    // assert state > COMPLETING;
  // 任务处理完成后（状态为已取消、异常、中断），唤醒由于get而进入等待的所有线程拿到该任务结果继续执行
    for (WaitNode q; (q = waiters) != null;) {
      // 依次释放等待线程节点
        if (UNSAFE.compareAndSwapObject(this, waitersOffset, q, null)) {
            for (;;) {
              // 释放当前等待节点的线程
                Thread t = q.thread;
                if (t != null) {
                    q.thread = null;
                  // 唤醒这个等待线程
                    LockSupport.unpark(t);
                }
                WaitNode next = q.next;
              // 跳出循环判断
                if (next == null)
                    break;
								// 释放等待节点
                q.next = null; // unlink to help gc
              // 进入下一次循环
                q = next;
            }
            break;
        }
    }
		// 执行子类的done方法（由子类实现），例如：ExecutorCompletionService 利用它来维护了一个‘已完成任务’的队列，实现了边产生已完成任务边处理已完成任务的结果
    done();
// 释放callable
    callable = null;        // to reduce footprint
}
```

> public V get()

```java
public V get() throws InterruptedException, ExecutionException {
        int s = state;
  // 崭新任务，则需要等待完成
        if (s <= COMPLETING)
            s = awaitDone(false, 0L);
  // 报告任务（判断输出结果是正常值还是异常信息）
        return report(s);
    }
```

> private V report(int s)

```java
private V report(int s) throws ExecutionException {
        Object x = outcome;
  // 正常值，直接强转范性返回
        if (s == NORMAL)
            return (V)x;
  // 已经取消的任务，报错
        if (s >= CANCELLED)
            throw new CancellationException();
  // 其他报错
        throw new ExecutionException((Throwable)x);
    }

```

> private int awaitDone(boolean timed, long nanos)

```java
private int awaitDone(boolean timed, long nanos)
    throws InterruptedException {
  // 最长等待期限
    final long deadline = timed ? System.nanoTime() + nanos : 0L;
    WaitNode q = null;
    boolean queued = false;
    for (;;) {
      // 如果等待该任务执行完毕的线程，还在超时时间内，但被中断，则抛出中断异常
        if (Thread.interrupted()) {
            removeWaiter(q);
            throw new InterruptedException();
        }

        int s = state;
        if (s > COMPLETING) {
            // 表示已处理完成（用户内容已经处理完毕，并且已经将结果赋值到属性outcome上）
            if (q != null)
              // 但这个时候，我们却已经创建了一个等待节点（要明白任务执行线程与get()方法执行线程不互不干涉），那么我们就需要重新释放掉！
                q.thread = null;
          // 终止等待
            return s;
        }
        else if (s == COMPLETING) // cannot time out yet
          // 正在完成（用户逻辑内容已经执行完毕，正在进行outcome赋值），我们仅仅需要让出一下cpu，来等待完成
            Thread.yield();
        else if (q == null)
          // 能执行到这里，说明这是个新任务，应该直接创建等待节点
            q = new WaitNode();
        else if (!queued)
          // 能执行到这里，说明这是个新任务并且已经创建等待节点，带没有入等待单链表中，这时应该放入等待节点到等待单链表
            queued = UNSAFE.compareAndSwapObject(this, waitersOffset,
                                                 q.next = waiters, q);
        else if (timed) {
          // 执行到这里，说明这个已经放入等待单链表中的等待节点是有超时时间的，过了超时时间，就不应该存在于等待节点单链表中，应该将这个节点删除掉
            nanos = deadline - System.nanoTime();
            if (nanos <= 0L) {
              // 删除有超时时间的等待节点（过了超时时间，这个线程就不等待了）
                removeWaiter(q);
                return state;
            }
          // 使得当前线程await，等待被unpark唤醒
            LockSupport.parkNanos(this, nanos);
        }
        else
          // 直接阻塞当前线程
            LockSupport.park(this);
    }
}
```

> public void run()

```java
// 不是新的 || 不能将 runner 改为当前线程
if (state != NEW ||
    !UNSAFE.compareAndSwapObject(this, runnerOffset,
                                 null, Thread.currentThread()))
    return;
try {
  // 可回调的
    Callable<V> c = callable;
    if (c != null && state == NEW) {
        V result;
      // 是否正常获取到处理结果标识
        boolean ran;
        try {
          // 获取结果（用户真正的内容处理逻辑，与结果返回逻辑）
            result = c.call();
            ran = true;
        } catch (Throwable ex) {
            result = null;
            ran = false;
          // 走异常结果处理（就是将状态改变一下，并将结果赋值给该任务的outcome属性）
            setException(ex);
        }
        if (ran)
          // 走正常结果处理（就是将状态改变一下，并将结果赋值给该任务的outcome属性）
            set(result);
    }
} finally {
// runner 运行必须赋值为null
    runner = null;
// 状态
    int s = state;
  // 如果正在中断，走中断处理
    if (s >= INTERRUPTING)
        handlePossibleCancellationInterrupt(s);
}
```

## 测试流程

```java
/**
 * 测试futureTask#get()
 */
@Test
public void test3() throws Exception {
  // 创建任务
    FutureTask<Integer> futureTask = new FutureTask<>(() -> {
        Thread.sleep(100000);
        return 1;
    });
  // 线程调用处理用户逻辑
    new Thread(futureTask).start();
  // 异步等待获取结果
    Integer integer = futureTask.get();
    System.out.println(integer);
}
```

1. 创建任务
2. 异步执行任务
3. 阻塞等待结果返回

幸运的是，这些操作都在`AbstractExecutorService`里面做了封装，甚至做了一些扩展

```java
java.util.concurrent.AbstractExecutorService#submit(java.lang.Runnable, T)
```

## 底层原理

## `FutureTask`使用执行流程

**`FutureTask`使用执行流程：**

- 定义`FurureTask`实例，会初始化内部的`Callable`，`Callable`是用户自定义的逻辑内容
- 实例定义完成后，我们可以开启一个新的线程将这个`FutureTask`任务传进去，调用线程的`start()`方法实现异步，则会执行`FutureTask`实例中的`run()`
- 另一方面，主要线程调`FutureTask`实例的 `get()`去等待结果
- 所有线程都可多次调用该任务实例的`get()`方法，在改任务中这些线程是**以等待线程单链表的形式存储在内部**

### `get()` 底层原理

- **任务为完成状态：**直接调用`report()`处理调用`run()`后返回原生结果的属性`outcome`，返回结果
- **任务未完成状态：**死循环，等待结果
  - 任务未完成时：创建该线程的`WaitNode`实例，放在``waiters调单链表的头节点，并使用`LockSupport.park(this)`使await该线程
  - 任务正在完成时，直接调用`Thread.yield()`,让出一下cpu资源，重新抢CPU资源（因为这个时候是已经处理完用户内容，进入了一个结果赋值的状态，马上就能获取到结果）
  - 任务完成时，如果已经创建了该线程的`WaitNode`实例就释放该`WaitNode`
  - 若想要获取该任务结果的线程，在等待过程中，线程中断，则会抛出中断异常
  - 若指定了等待时常，底层则直接用：`LockSupport.parkNanos(this, nanos)`-->`UNSAFE.park(false, nanos)`

### `run()`底层原理

- 获取当前线程设置为该新任务runner，无法设置完成则不执行
- 获取内部`Callable`调用并执行
  - **返回结果正常**
    - 设置状态正在完成、设置改任务outcome属性值为返回结果值，设置改任务执行完成一切正常
    - 释放所有调用改任务`get`方法后，等待的线程（底层就是unsafe的unpark操作唤醒线程的）
    - 唤醒之后，释放等待的节点
    - 调用子类的任务完成模板方法
    - 释放`Callable`
  - **返回结果异常**
- 释放`runner`
- **如果状态为中断的话，有处理中断程序**

**总结：**

- 所有调用该任务`get()`的线程,都会依次**头插法的方式进入**一个`WaitNode`**内部线程等待单链表**中，供`run()`完成结果处理后，依次**循环单链表进行线程唤醒继续执行**
- 底层主要**使用`UNSAFE.park()`与`UNSAFE.unpark`方法**进行线程的结果等待
- 该类仅代表一个有返回值的异步任务