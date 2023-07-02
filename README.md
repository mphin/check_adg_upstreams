# check_adg_upstreams
自用bash脚本备份，防止openclash崩溃影响全局网络  
openclash作为adguardhome上游，循环监测openclash的DNS是否正常  
  
这是一个Bash脚本，用于监测和切换DNS服务器。它使用AdGuardHome作为DNS服务器，openclash作为上游服务器。当主DNS异常则切换备用DNS，当主DNS恢复正常则切换回来。  

脚本首先定义了一些变量，包括AdGuardHome的配置文件路径、主DNS服务器地址和备用DNS服务器地址等。  

接下来，脚本定义了一些函数，包括创建日志、捕获终止信号、获取当前网络DNS地址、检查DNS服务器状态、修改配置文件为备用DNS、修改配置文件为主DNS、重启AdGuardHome服务等。  

最后，脚本定义了一个主函数，该函数使用一个无限循环来监测DNS服务器状态。如果主DNS服务器连续正常3次，则切换回主DNS服务器；如果主DNS服务器连续异常2次，则切换到备用DNS服务器。在切换DNS服务器后，脚本会重启AdGuardHome服务。
