# 04-Kafka Connect API

`Connect API`实现一个连接器（connector），不断地从一些数据源系统拉取数据到kafka，或从kafka推送到宿系统（sink system）。

大多数Connect使用者不需要直接操作这个API，可以使用之前构建的连接器，不需要编写任何代码。有关Connect的其他信息，点击[这里](https://www.orchome.com/343)。