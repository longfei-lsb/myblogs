# 线程池分析（3）｜AbstractExecutorService源码解析

[TOC]

## 理解

> 任务：代表着用户自定义需要处理的一项逻辑
>
> 例如：FutureTask，允许带有返回值的任务

**我对任务的理解**

- 仅仅代表一块代码程序，不可自动执行、需要外部因素调用
- 里面包括任务的执行状态、FutureTask更是包含任务的返回值

> Executor：执行器，用来执行任务

**我对执行器的理解**

- 执行器并不表示要与任务一对一，也可以一对多的执行任务
- 仅有一个执行任务的行为
- 需要传入一个任务，而刚刚对任务理解中所说的外部因素就是执行器

> ExecutorService：服务于整个任务执行期间，专门为执行器提供服务的接口

**我对执行器服务的理解**

- 为执行器的服务，定义着一些行为：执行任务行为、提交任务行为
- 协调扩展执行器处理任务的方式：比如取消、等待所有任务完成等
- 监控执行器执行任务状态：比如`isTerminated`

> ExecutorCompletionService

**我对`ExecutorCompletionService`的理解**

> AbstractExecutorService：专门完成那些基本的理论行为的落地

**我对`AbstractExecutorService`的理解**

- 仅仅是一个服务于执行器的理论行为的落地实现

> CompletionService<V> 



## 源码解析

**我对`execute()`与`submit`的理解**，先来看`submit()`的内部实现

```java
/**
 * submit
 */
public Future<?> submit(Runnable task) {
    if (task == null) throw new NullPointerException();
  // 创建任务
    RunnableFuture<Void> ftask = newTaskFor(task, null);
  // 执行任务
    execute(ftask);
  // 获取已经正在运行的任务实例
    return ftask;
}

/**
 * newTaskFor
 */
protected <T> RunnableFuture<T> newTaskFor(Runnable runnable, T value) {
  // 创建FutureTask
    return new FutureTask<T>(runnable, value);
 }
```

我们来比较一下：

- `execute()`只是作为催动调用任务的执行的方式，没有其余之外任何意义（任务总是要通过它来达到执行的目的）
- `submit()`封装了创建并执行`FutureTask`实例的逻辑，而`FutureTask`是通过内部维护的等待线程单链表，以及`LockSupport`的`park()`与`unpark()`实现阻塞等待异步结果的
- 因为`submit()`是返回的`Future`所以，一定程度上可以获取任务状态和影响执行器处理过程

### 两个核心方法

### invokeAll()

> invokeAll：

```java
public <T> List<Future<T>> invokeAll(Collection<? extends Callable<T>> tasks,
                                     long timeout, TimeUnit unit)
    throws InterruptedException {
  // 任务为空，抛出异常
    if (tasks == null)
        throw new NullPointerException();
  // 时间戳转换
    long nanos = unit.toNanos(timeout);
  // 封装允许带有返回结果的任务，并填充到Future集合
    ArrayList<Future<T>> futures = new ArrayList<Future<T>>(tasks.size());
  // 所有任务是否执行完毕，初始值为null
    boolean done = false;
    try {
      // 向集合填充带有封装的任务
        for (Callable<T> t : tasks)
            futures.add(newTaskFor(t));

      // 允许所有任务执行的最长时间
        final long deadline = System.nanoTime() + nanos;
      // 任务数
        final int size = futures.size();

        // Interleave time checks and calls to execute in case
        // executor doesn't have any/much parallelism.
          // 依次调用执行任务，一个任务执行完毕，另一个任务才会开始      
        for (int i = 0; i < size; i++) {

            execute((Runnable)futures.get(i));
          // 刷新总任务执行所剩时长
            nanos = deadline - System.nanoTime();
          // 一旦执行总任务时间超过最后期限，就直接返回futures集合，但在返回之前，会先找到finally代码块做响应的任务处理
            if (nanos <= 0L)
                return futures;
        }
      
       // 一次从集合中获取到没有执行完成的future任务，设置剩余最长超时时间限制，进行结果获取，，每获取到一个结果，就更新一次总剩余超时时间
        for (int i = 0; i < size; i++) {
            Future<T> f = futures.get(i);
            if (!f.isDone()) {
                if (nanos <= 0L)
                    return futures;
                try {
                  // 有超时的获取结果
                    f.get(nanos, TimeUnit.NANOSECONDS);
                } catch (CancellationException ignore) {
                } catch (ExecutionException ignore) {
                } catch (TimeoutException toe) {
                    return futures;
                }
              // 刷新总任务所剩余时长
                nanos = deadline - System.nanoTime();
            }
        }
      // 所有future执行完毕，并获取到结果
        done = true;
        return futures;
    } finally {
      // 没有完成的任务将被强制取消（对于FutureTask来说，就是中断任务实例中runner属性所指向的线程，并在整个中断过程中维护中断状态，即：修改正在中断状态-->中断runner-->修改状态为已中断-->唤醒所有get()后阻塞的线程（就是循环唤醒等待线程单链表中的线程）继续执行）
        if (!done)
            for (int i = 0, size = futures.size(); i < size; i++)
                futures.get(i).cancel(true);
    }
}
```

**这里我存有一个疑问：**

既然第一个futures集合循环已经依次调用了execute，它是异步执行的不？不是的话，那第二次循环为什么好要判断是否执行完毕呢？是不是多余了，因为对于FutureTask来说只要执行完execute就代表已经完成任务了

关于`Future`的`isDone()`用法如下：

```java
FutureTask<Integer> futureTask = new FutureTask<>(() -> {
            Thread.sleep(3000);
            return 1;
        });
        new Thread(futureTask).start();
        new Thread(() -> {
          // 可以判断该任务是否执行完毕
            while (!futureTask.isDone()){
                try {
                    Thread.sleep(1000);
                    System.out.println("is not done");
                } catch (InterruptedException e) {
                    e.printStackTrace();
                }
            }
        }).start();
        Integer integer = futureTask.get();
        System.out.println(integer);
        
        //----
：输出结果
is not done
is not done
1
is not done
```



### doInvokeAny()：重中之重

> doInvokeAny()

```java
private <T> T doInvokeAny(Collection<? extends Callable<T>> tasks,
                          boolean timed, long nanos)
    throws InterruptedException, ExecutionException, TimeoutException {
  // 无任务报空指针
    if (tasks == null)
        throw new NullPointerException();
  // 未执行任务数
    int ntasks = tasks.size();
    if (ntasks == 0)
        throw new IllegalArgumentException();
  // future集合
    ArrayList<Future<T>> futures = new ArrayList<Future<T>>(ntasks);
  // ‘已完成任务’执行器服务
    ExecutorCompletionService<T> ecs =
        new ExecutorCompletionService<T>(this);

    // For efficiency, especially in executors with limited
    // parallelism, check to see if previously submitted tasks are
    // done before submitting more of them. This interleaving
    // plus the exception mechanics account for messiness of main
    // loop.

    try {
        // Record exceptions so that if we fail to obtain any
        // result, we can throw the last exception we got.
        ExecutionException ee = null;
      // 超时期限
        final long deadline = timed ? System.nanoTime() + nanos : 0L;
      // 任务迭代器
        Iterator<? extends Callable<T>> it = tasks.iterator();

        // 开始执行第一个任务，并将正在执行的任务（Future）放入集合中
        futures.add(ecs.submit(it.next()));
      // 未执行任务数-1
        --ntasks;
      // 记录正在活跃的任务数（就是正在处理用户逻辑，并且还没有获取到任务结果）
        int active = 1;
			//循环
        for (;;) {
          // 弹出并获取到‘已完成任务’队列顶部元素
            Future<T> f = ecs.poll();
            if (f == null) {// 这说明目前没有任务已处理完成

                if (ntasks > 0) {// 如果任务数不为空
                    // 初始时，所有任务都走这里，站在同一起跑线上，保证所有任务都能得到执行（异步的）
                    --ntasks;// 未任务数-1
                    futures.add(ecs.submit(it.next()));// 再执行下一个任务，并放入集合
                    ++active;// 活跃的任务数+1
                }
                else if (active == 0)
                  // 执行到这里，说明未执行任务数为空，且活跃（未处理完成的）任务已清空完毕
                    break;
                else if (timed) {
                  // 执行到这里，说明任务全部得到执行（即：ntasks为0），但并非所有任务未处理完毕（即：active不为0），又是设置了超时时间，所以需要对这些所有未完成的任务做一个超时时间上的处理
                    f = ecs.poll(nanos, TimeUnit.NANOSECONDS);
                    if (f == null)
                      // 如果执行到这里，说明到了超时时间，但‘已完成任务’队列仍然为空，换句话说，就是这些任务还没有处理完毕，那么我们就需要报超时异常
                        throw new TimeoutException();
                  // 到这里，说明已经有任务在超时时间内放入‘已完成任务’队列，我们需要刷新一下超时时间
                    nanos = deadline - System.nanoTime();
                }
                else
                  // 到这里，说明任务全部得到执行，我们只需要一直等任务完成后，获取到‘已完成任务’队列中的任务即可
                    f = ecs.take();
            }
            if (f != null) {
              // 只要到这里，不为null，就说明我们已经获取到了一个已完成任务
                --active;// 活跃的任务-1
                try {
                  // 直接获取到任务的结果（也可能结果是个异常），只要能获取到一个预先已完成的任务结果，就返回
                    return f.get();
                } catch (ExecutionException eex) {
                  // 执行到这里，说明，该已完成任务执行结果是个异常，需要捕获
                    ee = eex;
                } catch (RuntimeException rex) {
                    ee = new ExecutionException(rex);
                }
            }
        }
// 执行的任务没有完成，抛出异常
        if (ee == null)
            ee = new ExecutionException();
        throw ee;

    } finally {
      // 不管怎样，强制取消掉所有任务
        for (int i = 0, size = futures.size(); i < size; i++)
            futures.get(i).cancel(true);
    }
}
```

## 总结

- invokeAny中，底层利用`CompletionService`实现了对已完成任务的逻辑处理操作
- 我们如果要扩展`Executor`，更应该基于该累进行扩展