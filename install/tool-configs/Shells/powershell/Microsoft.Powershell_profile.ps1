Import-Module PSReadLine

# 启用预测补全
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

# Tab → 切换下一个预测
Set-PSReadLineKeyHandler -Key Tab -Function NextSuggestion

# Set-PSReadLineOption -PredictionViewStyle InlineView

# # 上下箭头切换预测项
# Set-PSReadLineKeyHandler -Key DownArrow -Function NextSuggestion
# Set-PSReadLineKeyHandler -Key UpArrow -Function PreviousSuggestion


# # 记录上次 Tab 的时间
# $global:lastTabTime = [datetime]::MinValue

# # 自定义 Tab 行为: 单击 Tab 接受一个词, 快速双击 Tab 接受整句
# Set-PSReadLineKeyHandler -Key Tab `
#     -BriefDescription "Smart Tab Accept" `
#     -ScriptBlock {
#         $now = Get-Date
#         $delta = ($now - $global:lastTabTime).TotalMilliseconds
#         $global:lastTabTime = $now

#         if ($delta -lt 400) {
#             # 400ms 内连续两次 Tab → 接受整句
#             [Microsoft.PowerShell.PSConsoleReadLine]::AcceptSuggestion()
#         } else {
#             # 第一次 Tab → 接受下一个词
#             [Microsoft.PowerShell.PSConsoleReadLine]::AcceptNextSuggestionWord()
#         }
#     }
