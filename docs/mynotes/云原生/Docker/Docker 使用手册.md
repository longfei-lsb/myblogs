# <font face="STCAIYUN">Docker 使用手册</font>

[TOC]

>学前准备

1、Linux基础

>Docker学习

- Docker概述
- Docker安装
- Docker命令
  - 镜像命令
  - 容器命令
  - 操作命令
  - ……
- Docker镜像！
- Docker数据卷
- DockerFile
- Docker网络原理
- IDEA 整合Docker
- Docker Compose
- Docker Swarm
- CI/CD jenkins

## 一、Docker 概述

-------

### 1、Docker 为什么会出现？

一款产品 开发-上线 两套环境。应用环境，应用配置

开发出来的东西交给运维，需要部署环境、配置，会十分麻烦！

我们能不能用一套东西（环境+项目）一起打包，避免不必要的麻烦？

<img src="https://gimg2.baidu.com/image_search/src=http%3A%2F%2Fpic1.zhimg.com%2Fv2-a62710d971c47422f25eca254b2add8a_1440w.jpg%3Fsource%3D172ae18b&refer=http%3A%2F%2Fpic1.zhimg.com&app=2002&size=f9999,10000&q=a80&n=0&g=0n&fmt=jpeg?sec=1639328826&t=184fc4aa42eefed096f8754e9d23b149" alt="Docker" style="zoom:80%;" />

Docker 给以上问题提出了解决方案！

Docker思想来自于集装箱

JRE --> 多个应用（端口冲突）--> 东西都是交叉的

隔离：Docker核心思想！打包装箱，每个箱子都是隔离的

### 2、Docker 的历史

2010年，几个搞IT的年轻人 做一些LXC有关的容器化技术，他们将自己的技术成为容器化技术，命名：**Docker**

刚刚诞生之时，没有人注意，公司活不下去，就选择**`开源`**

2013年，Docker开源

Docker火了之后，每个月都会更新一个版本

2014年4月9日，Docker1.0正式发布

<font color="pink"> Docker为什么会火呢？</font>

> 十分的轻巧

### 3、Docker 能干嘛？

![比较Docker与虚拟机的不同](https://gimg2.baidu.com/image_search/src=http%3A%2F%2Fwww.processon.com%2Fchart_image%2Fid%2F5e491359e4b00aefb7e26a16.png&refer=http%3A%2F%2Fwww.processon.com&app=2002&size=f9999,10000&q=a80&n=0&g=0n&fmt=jpeg?sec=1639330027&t=e3cb70df518c657bd8a2ac24bf5cb522)

`Docker` VS `虚拟机`

- 传统虚拟机会虚拟出硬件，运行一个完整的操作系统，然后在系统之上安装运行软件
- 容器内应用直接运行在宿主机内核中，容器没有内核，没有虚拟硬件，所以就比较轻便
- 每个容器有属于自己的文件系统，互相隔离，互不影响。

> Docker 开发、运维

**应用更快速的交付和部署**

传统：一堆帮助文档、安装程序

Docker：打包镜像、发布测试，一键运行！

**更便捷的升级或扩缩容**

使用了Docker之后，升级环境像搭积木一样！

例如：项目打包为一个应用，服务器A出现问题，性能出现瓶颈，我要做水平扩展，做负载均衡，我们可直接在服务器上直接一键运行，服务器B就被扩展起来啦

**更简单的系统运维**

开发、测试、线上环境高度一致

**更高效的系统利用**

Docker是内核级别的虚拟化，可以在一个物理机上运行多个容器实例，将物理机性能压榨到极致

## 二、Docker安装

### 1、Docker的基本组成

![组成](https://img2.baidu.com/it/u=1293437859,864068487&fm=26&fmt=auto)

**镜像（image）**

Docker镜像相当于一个模板，通过一个镜像可以创建多个容器，最终项目的运行是在容器中的。类似于：类与实例的关系

**容器（container）**

Docker利用容器技术，独立运行一个或者一组应用，这些容器都是用镜像来创建的

`基本命令:`启动、停止、重启、删除

目前可以把这个容器理解为一个简易的操作系统

**仓库（Repository）**

存放镜像的地方

仓库分为：公有仓库、私有仓库

公有仓库（Docker Hub），默认国外

阿里云都有容器服务器，（配置镜像加速）

### 2、Docker 安装

> 环境准备

- 需要会一点Linux命令

- Centos7

- 使用命令行工具（Xshell，或者Termius），我这里是Termius

  > 环境查看

略

> 安装

[Docker 安装教程帮助文档](https://docs.docker.com/engine/install/)

```shell
# 1、卸载旧版本
sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
# 2、需要的安装包
sudo yum install -y yum-utils

# 3、设置镜像库 （这里记得替换为国内的阿里云镜像安装）
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
    # 建议安装这个
    http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo

# 4、更新yum软件包索引
yum makecache dast

# 5、安装docker有关内容， ce-社区版本
sudo yum install docker-ce docker-ce-cli containerd.io

# 6、启动docker服务
systemctl start docker

# 7、docker -version
查看是否安装成功！
```

> 测试是否安装成功

```shell
# 8、hello-world
docker run hello-world
# 9、查看镜像
docker images
```

> 卸载Docker

卸载依赖，删除docker运行环境

```shell
sudo yum remove docker-ce docker-ce-cli containerd.io

sudo rm -rf /var/lib/docker # 默认工作路径
sudo rm -rf /var/lib/containerd
```

> 配置使用

```shell
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://ix1b7gpx.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 3、回顾hello-world流程

![组成](https://gimg2.baidu.com/image_search/src=http%3A%2F%2Fimage.mamicode.com%2Finfo%2F201912%2F20191207193105983470.jpg&refer=http%3A%2F%2Fimage.mamicode.com&app=2002&size=f9999,10000&q=a80&n=0&g=0n&fmt=jpeg?sec=1639333455&t=0d78b9e7aea145ab324bbc446bd21cb4)

### 4、Docker 是怎么工作的？

Docker是一个C/S服务，Docker守护进程运行在主机上，通过Socket从客户端访问，

Docker-Server 接收到Docker-Client指令，就会执行这个命令

## 三、Docker的常用基本命令

### 1、帮助命令

```shell
runoob@runoob:~$ docker -version 		# 显示docker的版本信息
runoob@runoob:~$ docker info    		  # 显示docker的更加详细信息
runoob@runoob:~$ docker [命令] --help # 所有｜指定命令的帮助文档
```

### 2、镜像命令

```shell
runoob@runoob:~$ docker images 
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
nginx               latest              6f8d099c3adc        12 days ago         182.7 MB
mysql               5.6                 f2e8d6c772c0        3 weeks ago         324.6 MB
httpd               latest              02ef73cf1bc0        3 weeks ago         194.4 MB
ubuntu              15.10               4e3b13c8a266        4 weeks ago         136.3 MB
hello-world         latest              690ed74de00f        6 months ago        960 B

# 解释
REPOSITORY：表示镜像的仓库源
TAG：镜像的标签
IMAGE ID：镜像ID
CREATED：镜像创建时间
SIZE：镜像大小

# 可选项
-a 显示所有镜像
-q 显示所有ImageId

# 可组合命令 
-- 批量删除镜像
runoob@runoob:~$ docker rmi $(docker images -aq)
```

**搜索镜像**

```shell
runoob@runoob:~$ docker search mysql

# 可选项
--filter 过滤搜索
```

**下载镜像**

```shell
# 默认下载最新版镜像
runoob@runoob:~$ docker pull mysql
Using default tag: latest
8b87079b7a06: Pulling fs layer 
a3ed95caeb02: Download complete # 分层下载
0d62ec9c6a76: Download complete 
a329d50397b9: Download complete 
# 默认下载指定版本镜像
runoob@runoob:~$ docker pull mysql:5.7

```

**删除镜像**

```shell
# 指定删除
runoob@runoob:~$ docker rmi -f 容器id
# 删除多个
runoob@runoob:~$ docker rmi -f 容器id 容器id 容器id 容器id 
# 批量删除
runoob@runoob:~$ docker rmi -f $(docker images -aq)
```

### 3、容器命令

**说明：我们需要有一个镜像才可以运行容器，linux，这里我们使用centos**

```shell
runoob@runoob:~$ docker pull centos
```

**新建并启动容器**

```shell
runoob@runoob:~$ docker run [可选参数] centos

# 可选参数
-i：交互式
-t：打开终端
-d：后台启动
--name：指定容器名称
-it：交互式打开
-p：指定端口
		-p 主机ip:port:容器port
		-p port:容器port
		-p 容器port
-P：随机指定端口

# 测试 启动并进入容器
runoob@runoob:~$ docker run -it centos /bin/bash
root@d3274819:/# 

# 退出容器
root@d3274819:/# exit
```

**列出所有运行的容器**

```shell
# 列出正在运行的容器
docker ps 
# 列出曾经｜正在运行的容器
docker ps -a
# 显示所有运行容器的编号
docker ps -aq
# 显示最近的容器
docker ps -n=?
# 批量删除容器
docker rm -f $(docker ps -aq)
```

**列出所有运行的容器**

```shell
# 退出容器（停止容器）
root@d3274819: exit 
ctrl + p + q # 容器不停止退出
```

**操作容器**

```shell
docker start 容器id
docker kill 容器id
docker stop 容器id
docker restart 容器id
```

### 4、其他常用命令

**后台启动容器**

```shell
# 后台启动
docker run -d centos
# 启动之后，docker ps发现容器停止了，原因是容器要使用后台运行，就必须要有一个前台进程，docker发现没有前台进程，就停止了
# nginx，容器启动后会发现没有服务了，就立刻停止，就是停止服务了
```

**查看日志**

```shell
docker logs -tf --tail 10 容器id

# 可选参数
-f：
-t：加上时间
--tail number：尾部n条

# 执行shell脚本
docker run -d centos -c "while true;do echo hello;sleep 1;done"
```

**查看容器的进程**

```shell
docker top 容器id
```

**查看镜像元数据**

```shell
docker inspect 容器id
```

**进入当前正在运行的容器**

```shell
# 方式一，打开一个新的终端
docker exec -it 容器id /bin/bash
# 方式二，进入正在运行的命令行，不会启动新的进程！
docker attach 容器id
```

**从容器内拷贝文件到主机**

```shell
docker cp 容器id：容器路径 本地主机路径
```

### 小结

### 可视化

- portainer（先用这个）

```shell
docker run -d -p 8088:9000 \
--restart=always -v /var/run/docker.sock:/var/run/docker.sock --privileged=true portainer/portainer
```

- Rancher 持续集成时（CI/CD时再用）

<font color="pink"> 什么是portainer？</font>

Docker图形化管理工具，提供给我们操作！

**访问测试：**http://ip:8088/

<!--(简单了解一下即可)-->

## 四、Docker镜像讲解

### 1、镜像是什么？

镜像是一种轻量级、可执行的独立软件包。用来打包软件运行环境和基于环境开发的软件。它包括运行某个软件所需的所有内容包括代码，运行时库、环境变量和配置文件所有的应用直接打包Docker镜像，就可以直接跑起来。

如何得到镜像？

- 朋友给你
- 自己提交上传
- 镜像仓库下载

### 2、镜像的加载原理

> UnionFS(联合文件系统)

联合文件系统是一种分层、轻量级并且高性能的文件系统。它支持对文件系统的修改作为一次提交来一层层的叠加，同时可以将不同的目录挂载到同一个虚拟文件系统下。联合文件系统是Docker镜像的基础，镜像可以通过分层来进行，继承基于基础镜像可以制作各种具体应用的镜像。

**特性：**一次同时加载多个文件系统，但从外面看起来只能看到一个文件系统，联合加载会把各种文件系统叠加起来，这样最终文件系统会包含所有底层的文件和目录。

> Docker 镜像底层加载原理



![镜像的分层叠加](https://gimg2.baidu.com/image_search/src=http%3A%2F%2Fimg.it610.com%2Fimage%2Finfo8%2Fe98b1280f7664543a61db9516979bb1d.jpg&refer=http%3A%2F%2Fimg.it610.com&app=2002&size=f9999,10000&q=a80&n=0&g=0n&fmt=jpeg?sec=1639367030&t=a5d692266663d6f101434c8ceb1af223)



docker的镜像实际上由一层一层的文件系统组成买这种层级的文件系统UnionFS。
bootfs（boot file system）主要包含bootloader的kernel，bootloader主要是引导加载kernel，Linux刚启动时会加载bootfs文件系统，在Docker镜像的最底层是bootfs。这一层与我们典型的Linux/Unix系统是一样的，包含boot加载器和内核。当boot加载完成之后，整个内核就都在内存中了，此时内存的使用权已由bootfs转交给内核，此时系统也会卸载bootfs。

rootfs（root file system），在bootfs之上。包含的就是典型Linux系统中的/dev, /proc, /bin, /etc等标准目录和文件。rootfs就是各种不同的操作系统发行版，比如Ubuntu，Centos等等

<font color="pink">平时我们安装虚拟机的CentOS都是好几个G，为什么docker这里才200M？</font>

对于一个精简的OS，rootfs可以很小，只需要包含最基本的命令，工具和程序库就可以了，因为底层直接用Host的kernel，自己只需要提供rootfs就可以了。由此可见对于不同的Linux发行版，bootfs会有差别，因此不同发行版可以用bootfs

### 3、分层理解

>  分层的镜像

我们可以去下载一个镜像，注意观察下载的日志输出，可以看到是一层一层的在下载

```shell
ubuntu@VM-0-13-ubuntu:/home$ sudo docker pull redis
Using default tag: latest
latest: Pulling from library/redis
6ec7b7d162b2: Already exists  # 已经存在的就不在下载了
1f81a70aa4c8: Pull complete 
968aa38ff012: Pull complete 
884c313d5b0b: Pull complete 
6e858785fea5: Pull complete 
78bcc34f027b: Pull complete 
Digest: sha256:0f724af268d0d3f5fb1d6b33fc22127ba5cbca2d58523b286ed3122db0dc5381
Status: Downloaded newer image for redis:latest
docker.io/library/redis:latest
```

<font color="pink">为什么Docker镜像要采用这种分层的结构？</font>

最大的好处,我觉得莫过于是资源共享了!比如有多个镜像都从相同的Base镜像构建而来,那么宿主机只需在磁盘上保留一份base镜像,同时内存中也只需要加载一份base镜像,这样就可以为所有的容器服务了,而且镜像的每一层都可以被共享

```shell
ubuntu@VM-0-13-ubuntu:/home$ sudo docker image inspect redis
[
    {
        #.....

        "RootFS": {
            "Type": "layers",
            "Layers": [
                "sha256:87c8a1d8f54f3aa4e05569e8919397b65056aa71cdf48b7f061432c98475eee9",
                "sha256:25075874ce886bd3adb3b75298622e6297c3f893e169f18703019e4abc8f13f0",
                "sha256:caafc8119413c94f1e4b888128e2f337505fb57e217931a9b3a2cd7968340a9e",
                "sha256:e5d940a579ec4a80b6ec8571cb0fecf640dba14ccfd6de352977fd379a254053",
                "sha256:2a1c28c532d20c3b8af8634d72a4d276a67ce5acb6d186ac937c13bd6493c972",
                "sha256:1540b8226044ed5ce19cc0fec7fbfb36a00bb15f4e882d6affbd147a48249574"
            ]
        },
        "Metadata": {
            "LastTagTime": "0001-01-01T00:00:00Z"
        }
    }
]
```

**理解：** 

所有的Docker镜像都起始于一个基础镜像层，当进行修改或增加新的内容时，就会在当前镜像层之上，创建新的镜像层。
举一个简单的例子，假如基于Ubuntu Linux 16.04 创建一个新的镜像，这就是新镜像的第一层；如果在该镜像中添加Python包，就会在基础镜像层之上创建第二个镜像层；如果继续添加一个安全补丁，就会创建第三个镜像层。
该镜像当前已经包含了3个镜像，如下图所示（这知识一个用于演示的很简单的例子）

![](https://cdn.jsdelivr.net/gh/luoxinglin/cdn/img/docker/QQ%E6%88%AA%E5%9B%BE20210108092451.png)

在添加 额外的镜像层的同时，镜像始终保持是当前所有镜像的组合，理解这一点非常重要。下图中举一个简单的例子，每个镜像层包含3个文件，而镜像包含了来自两个镜像层的6个文件

![QQ截图20210108092645](https://cdn.jsdelivr.net/gh/luoxinglin/cdn/img/docker/QQ%E6%88%AA%E5%9B%BE20210108092645.png)

上图中的镜像层个之前图中的略有区别，主要目的是便于展示文件。
下图中展示了一个稍微复杂的三层镜像，在外部看来整个镜像只有6个文件，这是因为最上层中的文件7是文件5的一个版本更新版本

![QQ截图20210108093339](https://cdn.jsdelivr.net/gh/luoxinglin/cdn/img/docker/QQ%E6%88%AA%E5%9B%BE20210108093339.png)

这种情况下，上层镜像中的文件覆盖了底层镜像层中的文件。这样就使得文件的更新版本作为一个新镜像层到镜像当中。Docker通过存储引擎（新版本采用快照机制）的方式来实现镜像层堆栈，并保证多镜像层对外展示为同意的文件系统。
Linux上可用的存储引擎有AUFS、Overlay2、Device Mapper、Btrfs以及ZFS。顾名思义，每种存储引擎都基于Linux中对应的文件系统或者块设备技术，并且每种存储引擎都有其独有的性能特点。
Docker在Windows上仅支持Windowsfilter一种存储引擎，该引擎基于NTFS文件系统之上实现了分层和CoW。
下图展示了与系统显示相同三层镜像。所有镜像层堆叠并合并，对外提供统一的视图

![QQ截图20210108093942](https://cdn.jsdelivr.net/gh/luoxinglin/cdn/img/docker/QQ%E6%88%AA%E5%9B%BE20210108093942.png)

> 特点

Docker镜像都是只读的，当容器启动时，一个新的可写层被加载到镜像的顶部！这一层就是我们通常说的容器层，容器之下都叫镜像层

### 4、commit 镜像

```shell
# 基于一个容器，来创建自己的一个镜像
docker commit -m="commit desc message" -a="image author name" <基于哪个容器id> 自定义镜像名称:[tags]
```

>  实战测试

```shell
# 拉取一个tomcat镜像
docker pull tomcat
# 发现这个tomcat默认是没有webapps的应用的（镜像的原因，官方默认webapps目录下是没有文件的）
[root@xiaoyequ ~] docker exec -it tomcat /bin/bash
oot@6ba1137fc95f:/usr/local/tomcat# ls
BUILDING.txt	 LICENSE  README.md	 RUNNING.txt  conf  logs	    temp     webapps.dist
CONTRIBUTING.md  NOTICE   RELEASE-NOTES  bin	      lib   native-jni-lib  webapps  work
root@6ba1137fc95f:/usr/local/tomcat# cp -r webapps.dist/* webapps    # 复制文件到 webapps
root@6ba1137fc95f:/usr/local/tomcat# cd webapps
root@6ba1137fc95f:/usr/local/tomcat/webapps# ls

# 我自己拷贝进去了基本的文件
cp webapps.dist ./webapps

# 将我们操作过的容器commit为一个镜像，我们之后就使用修改过的
docker commmit -m "add webapps app" -a="lishanbiao" 7a23843156 tomcat01:1.0

# 测试
docker run -it -p 3344:8080 tomcat02:1.0
```

**理解**

如果你想要保存当前容器的状态，就可以通过commit命令来提交，<font color= "pink">**相当于VM的快照**</font>

## 五、容器数据卷

### 1、什么是容器数据卷

**问题1：** 如果数据在容器中，那么我们容器删除之后，数据就会丢失；
**需求1：** 数据可以持久化；

**问题2：** 例如MySQL数据库容器化，当容器删除了，删库跑路，数据也就丢失了；
**需求2：** MySQL数据可以存储在本地；

宿主机和容器之间有一个数据共享的技术！Docker容器中产生的数据，同步到本地宿主机。
这就是卷技术，目录的挂载，将我们容器内的目录，挂载到Linux宿主机上面。

![b45f500c61b2ab6af6ccceb0152a6f7a](https://www.freesion.com/images/802/b45f500c61b2ab6af6ccceb0152a6f7a.png)

**总结：容器的持久化和同步操作，容器间也是可以数据共享的。**

### 2、使用数据卷

> 方式一：使用命令来挂载 -v

```shell
docker run -it -v 主机目录：容器目录

# 测试
docker run -it -v /home/ceshi:/home centos /bin/bash

# 启动后，我们通过 docker inspect 容器id 查看容器详细信息
docker inspect 824508c3232e
```

![49216b573ebad98c3277419e9acb7e18](https://www.freesion.com/images/64/49216b573ebad98c3277419e9acb7e18.png)

测试文件同步

![f3e32b66621f44053b59d050660ab89a](https://www.freesion.com/images/418/f3e32b66621f44053b59d050660ab89a.png)



![6376448f46576e305cbd14c33a951bbd](https://www.freesion.com/images/677/6376448f46576e305cbd14c33a951bbd.png)

**总结**：挂载后，主机与容器文件文件可以互相同步！

**好处**：我们以后修改文件信息，只需要在本地修改即可，文件内容会自动同步

### 3、实战：安装MySQL

```shell
docker pull mysql:5.7

docker run -d -p 3310:3306 -v /home/mysql/conf:/etc/mysql/conf.d -v /home/mysql/data:/var/lib/data -e MYSQL_ROOT_PASSWORD=123456 --name mysql01 mysql:5.7

# 参数解析
-d：后台启动
-p：映射端口号
-v：挂载卷
--name：容器名字
```

我们创建完数据库后，假设我们把容器删除，我们的数据也不会有丢失，这就实现了数据的持久化功能！

### 4、具名挂载和匿名挂载

> 匿名挂载

```shell
# 匿名挂载 (-v 容器路径)
docker run -d -P --name nginx01 -v /etc/nginx nginx

# docker volumes ls
```

![20200603153240468](https://img-blog.csdnimg.cn/20200603153240468.png)

这里会发现这种没有指定主机路径的名字，成为匿名挂载。

> 具名挂载

```shell
# 匿名挂载 (-v 容器路径), ps:-v 后面不指定“/”的代表卷名
docker run -d -P --name nginx01 -v juming-nginx:/etc/nginx nginx

# docker volumes ls
DRIVER                         VOLUME NAME
local                          juming-nginx

# 查看一下这个卷在哪个位置
docker volumes inspect juming-nginx
```

![]( https://img-blog.csdnimg.cn/20200603153726318.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzQxOTU3MjU3,size_16,color_FFFFFF,t_70 )

这便是默认的挂载卷目录：

> var/lib/docker/volumes/juming-nginx/_data

有时候我们会看到以下命令：docker run -d -:P --name=nginx02 -v juming-nginx:/etc/nginx:<font color="red">**ro**</font> nginx

或 docker run -d -:P --name=nginx02 -v juming-nginx:/etc/nginx:<font color="red">**rw**</font> nginx,这里的ro和rw代表读写权限，ro表示只读，rw表示读和写，对挂载出来的内容就进行了限制，ro表示只能通过宿主机进行改变，容器内无法操作。

**总结：**

- -v /宿主机路径：容器内路径  **指定路径挂载**
- -v 数据卷名：容器内路径 **具名挂载**
- -v 容器内路径 **指定匿名挂载**

### 5、数据卷容器

```shell
--volumes-from 
```

![]( https://img-blog.csdnimg.cn/2021042714012294.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzQxODM0NzI5,size_16,color_FFFFFF,t_70#pic_center )

![](https://img-blog.csdnimg.cn/20210427140132356.png?x-oss-process=image/watermark,type_ZmFuZ3poZW5naGVpdGk,shadow_10,text_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3FxXzQxODM0NzI5,size_16,color_FFFFFF,t_70#pic_center ) 

**结论：**容器之间配置信息是同步互相双向自动传递的，数据卷容器的生命周期一直持续到没有容器使用为止。

### 6、初识Dockerfile

Dockerfile就是用来构建docker镜像的构建文件！命令脚本

通过下面这个脚本可以生成镜像，镜像是一层一层的，每个命令都是一层！

```shell
# 创建一个dockerfile文件，名字随机，建议Dockerfile
# 文件中的内容指令（大写） 参数
FORM centos

VOLUME ["volume01","volume02"]

CMD echo "---end---"
CMD /bin/bash
# 这里的每个命令，就是镜像的一层
```

> 测试使用Dockerfile

```shell
# 用dockerfile来构建镜像 docker build -f filePath -t 自定义镜像名:[tags] .
docker build -f /home/lishanbiao/test/dockerfile1 -t lishanbiao/centos:1.0 .
```

ps：最后有一个“.”，不能忘



## 六、DockerFile

构建步骤：

1、 编写一个dockerfile文件

2、 docker build 构建称为一个镜像

3、 docker run运行镜像

4、 docker push发布镜像（DockerHub 、阿里云仓库)

![](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2NoZW5nY29kZXgvY2xvdWRpbWcvbWFzdGVyL2ltZy9pbWFnZS0yMDIwMDUxNjEzMTQwMDQ1Ni5wbmc?x-oss-process=image/format,png )

点击后跳到一个Dockerfile

![]( https://imgconvert.csdnimg.cn/aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2NoZW5nY29kZXgvY2xvdWRpbWcvbWFzdGVyL2ltZy9pbWFnZS0yMDIwMDUxNjEzMTQ0MTc1MC5wbmc?x-oss-process=image/format,png )

很多官方镜像都是基础包，很多功能没有，我们通常会自己搭建自己的镜像

### 1、DockerFile构建过程

> DockerFile基础知识

- 每个保留关键字（指令）都必须是大写字母。
- 执行顺序：从上到下顺序执行。
- \# 表示注释
- 每一个指令都会创建提交一个新的镜像层，并提交。

> DockerFile指令说明

- FROM  基础镜像，一切从这里开始构建
- MAINTAINER  镜像是谁写的，姓名+邮箱
- RUN    镜像构建的时候需要运行的命令
- ADD    
- WORKDIR  镜像的工作目录
- VOLUME   挂载的目录
- EXPOSE   暴露端口配置
- CMD     指定这个容器启动的时候要运行的命令，只有最后一个会生效，可被替代。
- ENTRYPOINT  指定这个容器启动的时候要运行的命令，可以追加命令。
- ONBUILD  当构建一个被继承DockerFile，这个时候就会运行ONBUILD的指令，触发指令。
- COPY    类似ADD，将我们文件拷贝到镜像中。
- ENV    构建的时候设置环境变量。

### 2、centos测试

> 创建一个自己的centos

**目标：**docker官方提供的原生centos镜像是一个压缩版本的，里面甚至没有vim相关命令、ifconfig等net命令。因此我们要通过DockerFile来构建出自己的镜像。

```shell
vim mydockerfile-cntos

# 以下是mydockerfile-cntos内容：
FROM centos # 已原生镜像为基础
MAINTAINER lishanbiao<1336503209@qq.com> # 作者信息
ENV MYPATH /usr/local # 配置环境变量
WORKDIR $MYPATH # 指定工作目录
RUN yum -y install vim # 安装vim
RUN yum -y install net-tools # 安装net-tools

EXPOSE 80 # 暴露80端口
CMD echo $MYPATH
CMD echo "------end------"
CMD /bin/bash

# 编辑内容完毕，shift + ：+ wq 退出后，构建自己的镜像
docker build -f mydockerfile-centos -t mycentos:0.1 .
```

![](https://imgconvert.csdnimg.cn/aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2NoZW5nY29kZXgvY2xvdWRpbWcvbWFzdGVyL2ltZy9pbWFnZS0yMDIwMDUxNjE0MDgzMTQ2NC5wbmc?x-oss-process=image/format,png ) 

**测试运行**

```shell
docker run -it mycentos /bin/bash
```

我们可以列出本地进行的变更历史

![]( https://imgconvert.csdnimg.cn/aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL2NoZW5nY29kZXgvY2xvdWRpbWcvbWFzdGVyL2ltZy9pbWFnZS0yMDIwMDUxNjE0MTg0MDcwNi5wbmc?x-oss-process=image/format,png )

> CMD 和 ENTRYPOINT区别

```shell
CMD	       # 指定这个容器启动的时候要运行的命令，只有最后一个会生效，可被替代。
ENTRYPOINT # 指定这个容器启动的时候要运行的命令，可以追加命令
```

**测试cmd**

```shell
# 编写dockerfile文件
$ vim dockerfile-test-cmd
FROM centos
CMD ["ls","-a"]
# 构建镜像
$ docker build  -f dockerfile-test-cmd -t cmd-test:0.1 .
# 运行镜像
$ docker run cmd-test:0.1
.
..
.dockerenv
bin
dev

# 想追加一个命令  -l 成为ls -al
$ docker run cmd-test:0.1 -l
docker: Error response from daemon: OCI runtime create failed: container_linux.go:349: starting container process caused "exec: \"-l\":
 executable file not found in $PATH": unknown.
ERRO[0000] error waiting for container: context canceled 
# cmd的情况下 -l 替换了CMD["ls","-l"]。 -l  不是命令所有报错
```

**测试ENTRYPOINT**

```shell
# 编写dockerfile文件
$ vim dockerfile-test-entrypoint
FROM centos
ENTRYPOINT ["ls","-a"]
$ docker run entrypoint-test:0.1
.
..
.dockerenv
bin
dev
etc
home
lib
lib64
lost+found ...
# 我们的命令，是直接拼接在我们得ENTRYPOINT命令后面的
$ docker run entrypoint-test:0.1 -l
total 56
drwxr-xr-x   1 root root 4096 May 16 06:32 .
drwxr-xr-x   1 root root 4096 May 16 06:32 ..
-rwxr-xr-x   1 root root    0 May 16 06:32 .dockerenv
lrwxrwxrwx   1 root root    7 May 11  2019 bin -> usr/bin
drwxr-xr-x   5 root root  340 May 16 06:32 dev
drwxr-xr-x   1 root root 4096 May 16 06:32 etc
drwxr-xr-x   2 root root 4096 May 11  2019 home
lrwxrwxrwx   1 root root    7 May 11  2019 lib -> usr/lib
lrwxrwxrwx   1 root root    9 May 11  2019 lib64 -> usr/lib64 ....

```

Dockerfile中很多命令都十分的相似，我们需要了解它们的区别，我们最好的学习就是对比他们然后测试效果！

### 3、实战：Tomcat镜像

**准备**

```shell
tomcat 下载 
wget -P ./ https://mirrors.cnnic.cn/apache/tomcat/tomcat-8/v8.5.64/bin/apache-tomcat-8.5.64.tar.gz 
jdk 下载地址
wget -P ./ https://mirrors.cnnic.cn/AdoptOpenJDK/8/jdk/x64/linux/OpenJDK8U-jdk_x64_linux_hotspot_8u282b08.tar.gz
# 以上两个地址与我使用的版本不一样，勿抄 

root@aliyunleo tomcat8source]# ll
total 191952
-rw-r--r-- 1 root root  11027411 Oct 15 11:44 apache-tomcat-9.0.33.tar.gz
-rw-r--r-- 1 root root 185516505 Oct 15 11:44 jdk-8u141-linux-x64.tar.gz

# 我们可以在当前目录下创建一个文件readme.txt
```

```shell
# 编辑后，查看自己的Dockerfile
[root@aliyunleo tomcat8source]# cat Dockerfile 
FROM centos # 基础镜像
MAINTAINER leo<wei1986@126.com> # 作者信息

COPY readme.txt /usr/local/readme.txt # copy当前目录下的文件到容器

ADD jdk-8u141-linux-x64.tar.gz /usr/local/ # 加入文件，会自动解压
ADD apache-tomcat-9.0.33.tar.gz /usr/local/ # 加入文件，会自动解压

RUN yum -y install vim # 安装vim

ENV MYPATH /usr/local # 配置环境变量
WORKDIR $MYPATH # 指定工作目录

ENV JAVA_HOME /usr/local/jdk1.8.0_141 # 指定环境变量
ENV CLASSPATH $JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar # 指定环境变量

ENV CATALINA_HOME /usr/local/apache-tomcat-9.0.33 # 指定环境变量
ENV CATALINA_BASH /usr/local/apache-tomcat-9.0.33 # 指定环境变量

ENV PATH $PATH:$JAVA_HOME/bin:$CATALINA_HOME/lib:$CATALINA_HOME/bin # 指定环境变量

EXPOSE 8080 # 暴露端口

CMD /usr/local/apache-tomcat-9.0.33/bin/startup.sh && tail -F /usr/local/apache-tomcat-9.0.33/bin/logs/catalina.out # 执行命令（这里是启动tomcat，并查看日志）
```

执行build命令，构建镜像

```shell
# 这里不指定文件，回去当前目录下找到默认的DockerFile文件
docker build -t diytomcat:1.1 .
```

启动镜像

```shell
docker run -d -p 9090:8080 --name leotomcat -v /wwwroot/tomcat9/test:/usr/local/apache-tomcat-9.0.33/webapps/test -v  /wwwroot/tomcat9/logs:/usr/local/apache-tomcat-9.0.33/logs diytomcat:1.1

# 命令行解析
# 后台启动
-d 
# 主机9090映射docker的8080端口
-p 9090:8080          
# 容器名
--name leotomcat      
 # 本地路径  /wwwroot/tomcat9/test   挂载到容器的   /usr/local/apache-tomcat-9.0.33/webapps/test
-v /wwwroot/tomcat9/test:/usr/local/apache-tomcat-9.0.33/webapps/test   
# 镜像名
diytomcat             

# 看到已经有容器启动了
[root@aliyunleo ~] docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                    NAMES
12d332ce5431        diytomcat           "/bin/sh -c '/usr/lo…"   2 minutes ago       Up 2 minutes        0.0.0.0:9090->8080/tcp   leotomcat
```

进入镜像

```shell
docker exec -it 12d332ce5431 /bin/bash
[root@12d332ce5431 local]# 
```

验证

```shell
curl localhost:9090
47.105.***.247:9090
```

由于做了卷挂载，在本地发布项目就可以了，不用到容器发布了

```shell
# 本地文件目录
[root@aliyunleo wwwroot]# tree
.
└── tomcat9
    ├── logs
    │   ├── catalina.2021-03-11.log
    └── test
        ├── index.jsp
        └── WEB-INF
            └── web.xml
[root@aliyunleo wwwroot]# pwd
/wwwroot
```

编写web.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://java.sun.com/xml/ns/javaee" xsi:schemaLocation="http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/web-app_3_0.xsd" id="WebApp_ID" version="3.0">
  <display-name>FirstWebFontEnd</display-name>
  <welcome-file-list>
    <welcome-file>index.html</welcome-file>
    <welcome-file>index.htm</welcome-file>
    <welcome-file>index.jsp</welcome-file>
    <welcome-file>default.html</welcome-file>
    <welcome-file>default.htm</welcome-file>
    <welcome-file>default.jsp</welcome-file>
  </welcome-file-list>
</web-app>

```

编写index.jsp

```jsp
<html>
    <head>
           <title>第一个 JSP 程序</title>
    </head>
    <body>
           <%
                  out.println("Hello World！");
           %>
    </body>
</html>
```

访问测试成功！

```wiki
http://host:9090/test
```

### 4、发布自己的镜像

> Docker Hub

1. **地址：**https://hub.docker.com/ 注册自己的账号
2. 确定可以登陆
3. 在我们的服务器上提交自己的镜像

![2312675-20210711140549896-659425041](https://img2020.cnblogs.com/blog/2312675/202107/2312675-20210711140549896-659425041.png)

```shell
docker push 自己的账户名/diytomcat:1.0 # 带上版本号，不然有可能被拒绝
```

为镜像打标签：

> docker tag 镜像id 镜像名:[tags]

### 5、发布镜像到阿里云服务

> 参考官方文档，无脑又详细！

## 小结

![](https://img2.baidu.com/it/u=3561942135,571465668&fm=26&fmt=auto)



## 七、Docker网络

### 1、
