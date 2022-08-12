# 线程池分析（2）｜CompletionService源码解析

[TOC]

## 理解

> CompletionService：服务内部维护一个已完成任务的队列，以异步的方式一边生产新的任务，一边处理已完成任务的结果
>
> 总结：将**执行任务与处理任务**分离开
>
> 大概流程：任务通过此服务类进行提交，则内部为该任务**封装成一个`FutureTask<Void>`的子类`QueueingFuture`**，该子类实现了`Future#done()`方法，将**状态已经处理完成的任务添加进队列**，实现已完成任务的生成，同时该服务类也提供了poll、take方法进行对已完成任务的处理。
>
> poll与take的区别
>
> poll：检索并删除队列头部元素，队列为空就返回null
>
> take：检索并删除队列头部元素，队列为空就等待

**我对CompletionService的理解**

- **对已完成的任务的处理**，已完成的状态包括：已取消、已完成、任务执行结果异常
- **本质是维护了一个已完成任务的队列**，已完成的任务添加到队列尾部，若要消费已完成任务，则在对列头部弹出

## 源码解析

### CompletionService

> 1、定义了提交生产任务的方法。2、操作已完成队列的行为

```java
// 提交任务，其重写方法会将Callable封装为带有 FutureTask#done()处理逻辑的FutureTask子类
// 这个done()处理逻辑就是，FutureTask执行完毕后，无论正常执行、取消还是异常完成，都将其放入队列中
Future<V> submit(Callable<V> task);
// 带有默认值的提交
Future<V> submit(Runnable task, V result)
// 获取并删除已完成任务队列的头部元素，空队列则阻塞任务进来
Future<V> take() throws InterruptedException;
// 获取并删除已完成任务队列的头部元素，空队列则返回null
Future<V> poll();
// 带有超时时间的poll返回
Future<V> poll(long timeout, TimeUnit unit) throws InterruptedException;

```

### ExecutorCompletionService

> CompletionService的子类实现，内部维护一个`已完成的任务`队列

**QueueingFuture**

```java
/**
 * FutureTask的扩展类让该任务完成后入队
 */
private class QueueingFuture extends FutureTask<Void> {
    QueueingFuture(RunnableFuture<V> task) {
        super(task, null);
        this.task = task;
    }
  // FutureTask提供给子类实现的方法，这里指任务完成后，让任务加入到队列中
    protected void done() { completionQueue.add(task); }
  // 具体任务
    private final Future<V> task;
}
```

> ExecutorCompletionService

**属性：**

```java
// 专门执行任务的：若构造函数传的执行器是 AbstractExecutorService 的子类，则该执行器与下面aes存储实例一致
private final Executor executor;
// 执行器服务
private final AbstractExecutorService aes;
// 阻塞队列
private final BlockingQueue<Future<V>> completionQueue;
```

**构造函数：**

```java
public ExecutorCompletionService(Executor executor,
                                 BlockingQueue<Future<V>> completionQueue) {
    if (executor == null || completionQueue == null)
        throw new NullPointerException();
    this.executor = executor;
    this.aes = (executor instanceof AbstractExecutorService) ?
        (AbstractExecutorService) executor : null;
    this.completionQueue = completionQueue;
}

public ExecutorCompletionService(Executor executor) {
        if (executor == null)
            throw new NullPointerException();
        this.executor = executor;
        this.aes = (executor instanceof AbstractExecutorService) ?
            (AbstractExecutorService) executor : null;
        this.completionQueue = new LinkedBlockingQueue<Future<V>>();
}
```

**重写的方法：**

```java
public Future<V> submit(Runnable task, V result) {
  // 无任务报错
    if (task == null) throw new NullPointerException();
  // 常规流程，创建任务-->执行任务-->返回正在执行的任务
    RunnableFuture<V> f = newTaskFor(task, result);
  // 比 AbstractExecutorService#submit()多出一步，就是要封装Callable为FutureTask的子类
  // 这也是最为关键的一步
    executor.execute(new QueueingFuture(f));
    return f;
}

public Future<V> take() throws InterruptedException {
  // 队列中获取，获取不到就等待
  return completionQueue.take();
}
public Future<V> poll() {
  // 队列中获取，获取不到，不等待直接返回null
  return completionQueue.poll();
}

public Future<V> poll(long timeout, TimeUnit unit)
  throws InterruptedException {
    // 队列中获取，获取不到，等待到超时时间，返回null
  return completionQueue.poll(timeout, unit);
}
```

## 使用流程

```java
/**
 * CompletionService 的使用方式
 *
 * @throws Exception
 */
@Test
public void test4() throws Exception {
    // 创建用户内容逻辑
    List<Callable<Integer>> callables = getCallable();
    // 创建'已完成任务'服务
    CompletionService<Integer> service = new ExecutorCompletionService<>(new CustomExecutorService());
    // 开启线程并利用服务，提交所有任务
    for (int i = 0; i < callables.size(); i++) {
        Callable<Integer> callable = callables.get(i);
        new Thread(() -> service.submit(callable)).start();
    }
    // 查看：超时不等待情况
    System.out.println(service.poll());
    // 查看：超时时间为1秒的输出情况
    System.out.println(service.poll(3, TimeUnit.MILLISECONDS));
    // 查看：等待直到队列中有已完成任务出现的情况
    System.out.println(service.take());

}

/**
 * 自己创造多个小任务
 *
 * @return
 */
static List<Callable<Integer>> getCallable() {
    List<Callable<Integer>> list = new ArrayList<>();
    for (int i = 0; i < 6; i++) {
        int sleepTime = 3 + new Random().nextInt(10);
        Callable<Integer> futureTask = () -> {
            Thread.sleep(sleepTime * 1000);
            return sleepTime;
        };
        list.add(futureTask);
    }
    return list;
}

/**
 * 自定义执行器
 */
static class CustomExecutorService implements Executor {
    /**
     * 简单的执行
     *
     * @param command
     */
    @Override
    public void execute(Runnable command) {
        command.run();
    }
}
// :输出
null
null
java.util.concurrent.FutureTask@277c0f21
```

疑问点：为什么第二个poll没有等待，直接返回的null

## 总结

- 底层维护一个`已完成任务`队列，任务完成就放进队列（通过`FutureTask`提供给子类实现的`done()`方法）
- 提供了获取已完成任务的方法，实现了边创建任务，边使用已完成任务的模式