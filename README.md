# ipsec-vpn-shell
Ubuntu的VPN连接shell脚本

vpn服务器的搭建参照hwdsl2/setup-ipsec-vpn

使用方式：  
<pre><code>
  初始化vpn
    vpn.sh init
  连接网络
    vpn.sh start
  断开网络
    vpn.sh stop
  关闭vpn
    vpn.sh close
</pre></code>

PS: 一般电脑开机后在本地网络不断的情况下，只需要初始化一次，后续切换网络，只需要用start和stop命令。
