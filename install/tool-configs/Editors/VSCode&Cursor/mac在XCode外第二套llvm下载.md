## setting.json

### clang 版本

(下载

```c++
brew install llvm
```

而后在 shell config 文件中加入

```json
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"
```

而后:)

我们在 setting.json 里面加上

```c++
{
  "C_Cpp.default.compilerPath": "/opt/homebrew/opt/llvm/bin/clang++"
}
```

来选择这个版本的 clang. 注意我们不用系统的 clang (版本可能比较低)





## launch.json

### debugger: 选择 Codelldb, 即 `"type": "lldb"`

### initCommands

initCommands 可以在我们 launch 前自动打 command. 相当于加在了 `.lldbinit` 里面.

我的文件中

```c++
["process handle SIGUSR1 -n false -p true -s false"]
```

表示忽略这个信号. (用来实现用户级 thread library)
