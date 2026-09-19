## 解决方案
>本工具通过读取 Steam 快捷方式中的 ID 和图标 Hash，从 Steam 官方 CDN 自动恢复丢失的 `.ico` 缓存文件，从而修复桌面游戏快捷方式白图标问题。

使用方法：
1.保存SteamIconFix.ps1到本地
2.右击该文件
3.选择“使用powershell运行”
![[Pasted image 20260919083835.png]]
4.运行后关闭，刷新后图标恢复

## 工作原理
Steam 桌面快捷方式使用 `.url` 文件保存游戏启动信息，其中通过 `IconFile` 字段指定对应的游戏图标文件：

```
IconFile=Steam\steam\games\<icon_hash>.ico
```

该 `.ico` 文件由 Steam 从官方 CDN 下载并缓存到本地：

```
Steam\steam\games\
```

当该缓存图标文件因某种原因丢失或未下载时，快捷方式仍可正常启动游戏，但 Windows 无法加载图标，因此显示为空白图标。

本工具通过以下流程自动修复：

1. 扫描 Steam 游戏快捷方式（`.url`）
2. 读取快捷方式中的：
    - 游戏 ID
    - 图标 Hash
    - 图标保存路径
3. 检测本地 `.ico` 文件是否缺失
4. 根据 Steam 官方图标资源规则：

```
https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/{appid}/{hash}.ico
```

自动重新下载对应图标  
5. 保存到 Steam 图标缓存目录  
6. 刷新系统图标缓存，使桌面快捷方式恢复正常显示# SteamIconFixer
