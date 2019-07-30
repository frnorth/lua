## 说明
针对用户: `user1`  
每秒请求的次数的次数: `v`  
两个阈值: `threshold1 = 5次/秒`  
&emsp;&emsp;&emsp;&emsp;&ensp;`threshold2 = 10次/秒`  
当 `v < threshold1`  
&emsp;&emsp;&emsp;正常访问  
当 `threshold1 < v < threshold2`  
&emsp;&emsp;&emsp;串行控制  
当 `v > threshold2`  
&emsp;&emsp;&emsp;并行控制

### 串行控制
串行请求时, 因为下次的请求在本次请求的响应之后, 所以, 只要将每一次的请求sleep一些时间, 就可以控制请求的速度  
`sleep_time = (v / threshold1 - 1) / v`  

### 并行控制
当`user1`的多个请求同时到达nginx时(并非完全同步), 如果只是将每个请求sleep一些时间, 那么整体效果只是让这些并发的请求延迟一小会, 并不能真正达到限制速度的目的.  
这时, 可以让`sleep_time = (0 ~ v / threshold2)之间的随机数`, 如, 每秒并发 150 次请求, 而 `threshold2 = 10`, 那么 `sleep_time为(0 ~ 15)之间的随机数`, 这样基本可以保证150此请求均匀分布在15秒内, 而15秒的平均速度为`threshold2`.  
多个用户之间不影响.  
