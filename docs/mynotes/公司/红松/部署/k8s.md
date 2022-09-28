**本地查看k8s测试环境日志：**

```shell
lishanbiao@lishanbiaodeMacBook-Pro ~ % kubectx
cls-330ed7ud-100027097619-context-default
cls-7m2efkd9-100027097619-context-default
lishanbiao@lishanbiaodeMacBook-Pro ~ % kubectx cls-330ed7ud-100027097619-context-default
Switched to context "cls-330ed7ud-100027097619-context-default".
lishanbiao@lishanbiaodeMacBook-Pro ~ % kubectl get pods -n class | grep "fjkt-hs-fengjin-market-deployment-green"
fjkt-hs-fengjin-market-deployment-green-668784854-ss5t2           3/3     Running            0          19h
lishanbiao@lishanbiaodeMacBook-Pro ~ % kubectl exec -it fjkt-hs-fengjin-market-deployment-green-668784854-ss5t2 -n class -- ash
Defaulted container "fjkt-hs-fengjin-market" out of: fjkt-hs-fengjin-market, jaeger-agent, istio-proxy, istio-init (init)
/ # cd /data/logs
/data/logs # ls -l
total 41864
-rw-r--r-- 1 root root  839010 Sep 22 16:39 business_log
-rw-r--r-- 1 root root     729 Sep 18 01:00 business_log.2022-09-18-01.gz
-rw-r--r-- 1 root root     721 Sep 18 07:10 business_log.2022-09-18-07.gz
-rw-r--r-- 1 root root    2475 Sep 18 08:04 business_log.2022-09-18-08.gz
-rw-r--r-- 1 root root    3988 Sep 18 09:51 business_log.2022-09-18-09.gz
-rw-r--r-- 1 root root    7475 Sep 18 10:53 business_log.2022-09-18-10.gz
-rw-r--r-- 1 root root  405828 Sep 20 20:59 business_log.2022-09-20-20.gz
-rw-r--r-- 1 root root 2589394 Sep 20 21:47 business_log.2022-09-20-21.gz
-rw-r--r-- 1 root root    3499 Sep 20 22:13 business_log.2022-09-20-22.gz
-rw-r--r-- 1 root root   20815 Sep 21 00:35 business_log.2022-09-21-00.gz
-rw-r--r-- 1 root root 4384400 Sep 21 21:54 business_log.2022-09-21-21.gz
-rw-r--r-- 1 root root  139742 Sep 22 10:59 business_log.2022-09-22-10.gz
-rw-r--r-- 1 root root 7806085 Sep 22 11:59 business_log.2022-09-22-11.gz
-rw-r--r-- 1 root root  868141 Sep 22 12:50 business_log.2022-09-22-12.gz
-rw-r--r-- 1 root root    1398 Sep 22 13:50 business_log.2022-09-22-13.gz
-rw-r--r-- 1 root root 9493608 Sep 22 14:59 business_log.2022-09-22-14.gz
-rw-r--r-- 1 root root   61806 Sep 22 15:59 business_log.2022-09-22-15.gz
drwxr-xr-x 2 root root    4096 May 18 20:57 gluesource
-rw-r--r-- 1 root root  282850 Sep 22 16:41 system_log
-rw-r--r-- 1 root root     168 Sep 18 01:00 system_log-2022-09-18-01.gz
-rw-r--r-- 1 root root     168 Sep 18 07:10 system_log-2022-09-18-07.gz
-rw-r--r-- 1 root root     285 Sep 18 08:04 system_log-2022-09-18-08.gz
-rw-r--r-- 1 root root     293 Sep 18 09:51 system_log-2022-09-18-09.gz
-rw-r--r-- 1 root root    2179 Sep 18 10:53 system_log-2022-09-18-10.gz
-rw-r--r-- 1 root root   29671 Sep 18 11:12 system_log-2022-09-18-11.gz
-rw-r--r-- 1 root root  270082 Sep 20 20:59 system_log-2022-09-20-20.gz
-rw-r--r-- 1 root root 1865273 Sep 20 21:47 system_log-2022-09-20-21.gz
-rw-r--r-- 1 root root   32267 Sep 20 22:20 system_log-2022-09-20-22.gz
-rw-r--r-- 1 root root   51620 Sep 21 00:50 system_log-2022-09-21-00.gz
-rw-r--r-- 1 root root 2463477 Sep 21 21:54 system_log-2022-09-21-21.gz
-rw-r--r-- 1 root root     479 Sep 22 08:56 system_log-2022-09-22-08.gz
-rw-r--r-- 1 root root     432 Sep 22 09:20 system_log-2022-09-22-09.gz
-rw-r--r-- 1 root root   18879 Sep 22 10:59 system_log-2022-09-22-10.gz
-rw-r--r-- 1 root root 5113501 Sep 22 11:59 system_log-2022-09-22-11.gz
-rw-r--r-- 1 root root  348791 Sep 22 12:50 system_log-2022-09-22-12.gz
-rw-r--r-- 1 root root     320 Sep 22 13:50 system_log-2022-09-22-13.gz
-rw-r--r-- 1 root root 5633634 Sep 22 14:59 system_log-2022-09-22-14.gz
-rw-r--r-- 1 root root   23904 Sep 22 15:59 system_log-2022-09-22-15.gz
/data/logs # tail -f business_log
```

**本地查看线上环境日志：**

```shell
lishanbiao@lishanbiaodeMacBook-Pro ~ % kubectx                                                                                 
cls-330ed7ud-100027097619-context-default
cls-7m2efkd9-100027097619-context-default
lishanbiao@lishanbiaodeMacBook-Pro ~ % kubectx cls-7m2efkd9-100027097619-context-default
Switched to context "cls-7m2efkd9-100027097619-context-default".
lishanbiao@lishanbiaodeMacBook-Pro ~ % kubectl get pods -n class | grep "fjkt-hs-fengjin-market-deployment"                    
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-8jchj           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-9pmvb           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-9w2v7           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-b9wb8           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-bszhb           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-cbdzk           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-dfvjh           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-fp9pn           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-fv95g           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-fx2wn           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-j725p           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-p9hvr           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-pkfpc           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-pzwvj           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-sg4qh           2/2     Running   0          17h
fjkt-hs-fengjin-market-deployment-blue-7c78b4859b-wwx5t           2/2     Running   0          17h
lishanbiao@lishanbiaodeMacBook-Pro ~ % 
```

