# BootstrapContext

> 一个简单的对象注册表，在创建环境前，准备好环境后处理事件时传入，直到 ApplicationContext 准备好后关闭

生命周期：

1. BootstrapContext创建
2. listeners.starting(bootstrapContext, this.mainApplicationClass)
3. 环境创建
4. 环境已准备
5. 事件：listeners.environmentPrepared(bootstrapContext, environment)
6. 容器创建
7. 容器已准备
8. bootstrapContext.close(context)

**另外知识：**

SpringBoot启动过程中，会初始化一些用于应用启动时的监听器，来监听应用启动过程中的事件，例如：`ApplicationStartingEvent`，区别于用户自定义监听器的方式是通过`spring.factories`来配置这些监听器，而用`@Compnent`这种注解的方式是监听不到应用启动过程的事件的

**具体原理如下：**

SpringBoot启动之前，先是获取到所有`spring.factories`中的`ApplicationListener`实例并存储在`SpringApplication`的`listeners`变量中

再通过`run()`方法，来获取到`SpringApplicationRunListener`实例，而这个实例中会有一个事件广播器`SimpleApplicationEventMulticaster`，在进行实例构造的函数中，初始化了该事件广播器（即：将已经保存下来的`listeners`传给了该广播器）。

所以在SpringApplication整个启动的过程中，内部通过该广播器来操作判断监听器是否支持本次事件，不支持则监听器不会被过滤出来，也就不会去执行（默认我们只要通过spring.factories自定义的监听器能被广播器扫描到，都会通过一个适配器来支持监听应用启动过程，我们也可以通过实现`SmartApplicationListener`自定义是否支持）

**所以要想自定义的监听器可以监听到应用启动过程，必须满足一个条件：** 在spring.factories中配置该监听器，而不是简单的用`@Component`