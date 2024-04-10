01-SpringBoot启动流程

1. 记录配置主要源，以及mainApplicationClass
2. 设置spring.factorys中配置的ApplicationContextInitializer以及ApplicationListener
3. 配置跟随系统的headless变量
4. 获取所有的SpringApplicationRunListener（用于监听SpringApplication的整个启动过程阶段，通过广播器的方式发布阶段事件）
5. 发布starting事件
6. 解析main函数中的参数
7. 配置环境
   1. 获取一个标准的环境
   2. 为属性解析器配置转换器
   3. 为环境配置可变属性源
   4. 为环境配置要读取的文件前缀
   5. 将环境中的可变属性源包装成可配置属性源，并添加到属性源头节点
   6. 发布environmentPrepared事件
   7. 环境与spring应用绑定

