### Quick Start

1.生成实验列表

```shell
./build_benchmark.sh
```

2.运行实验

```shell
numactl -m 0 taskset -c 11 bash ./launch_reps.sh 1 1
```

运行过程会报错，在data/目录下会生成{EXPERIMENT_NAME}.ipc/ips/reporter_counter这3个文件。

3.刻画reporter的敏感曲线

```shell
./create_reporter_curve.sh
```

生成bubble_size.ipc\ipc.medians\ipc.median.normalized\ipc.normalized

4.运行实验

```shell
numactl -m 0 taskset -c 11 bash ./launch_reps.sh 1 1
```





