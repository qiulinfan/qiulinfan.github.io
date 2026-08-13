#Persistent
SetTimer, LaunchGameBar, 1000  ; 等待5秒后执行（确保系统加载完）
Return

LaunchGameBar:
SetTimer, LaunchGameBar, Off
Send, #{g} ; 发送 Win+G
ExitApp   ; 退出脚本
Return